#!/usr/bin/env python3
"""Compare the same separate-module Release consumer against two library revisions."""
import argparse
import csv
import hashlib
import io
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import tarfile
import tempfile


def run(command, **kwargs):
    return subprocess.run(command, check=True, **kwargs)


def parse_sample(output):
    reader = csv.DictReader(io.StringIO(output))
    if reader.fieldnames != ["round", "strategy", "elapsed_ns", "ns_per_candidate", "checksum"]:
        raise ValueError("Unexpected benchmark CSV schema")
    groups, seen = {}, set()
    for row in reader:
        key = (int(row["round"]), row["strategy"])
        elapsed, rate, checksum = int(row["elapsed_ns"]), float(row["ns_per_candidate"]), int(row["checksum"])
        if key in seen or key[0] < 0 or not key[1] or elapsed <= 0 or not math.isfinite(rate) or rate <= 0:
            raise ValueError("Invalid or duplicate benchmark sample")
        seen.add(key)
        groups.setdefault(key[1], []).append((key[0], rate, checksum))
    if not groups:
        raise ValueError("Empty benchmark output")
    rounds = {sample[0] for sample in next(iter(groups.values()))}
    if len(rounds) < 5 or rounds != set(range(len(rounds))):
        raise ValueError("Expected at least five complete benchmark rounds")
    result = {}
    for strategy, samples in groups.items():
        checksums = {sample[2] for sample in samples}
        if {sample[0] for sample in samples} != rounds or len(checksums) != 1:
            raise ValueError("Incomplete rounds or unstable result checksum")
        result[strategy] = {"median": statistics.median(sample[1] for sample in samples),
                            "checksum": checksums.pop()}
    return result


def summarize(values):
    median = statistics.median(values)
    return {"samples": values, "median": median,
            "mad": statistics.median(abs(value - median) for value in values)}


def compare(baseline, candidate):
    # Coarse noise-aware regression protection, not a portable speedup requirement.
    limit = baseline["median"] * 1.5 + 5 + 6 * (baseline["mad"] + candidate["mad"])
    return {"baseline_ns": baseline["median"], "candidate_ns": candidate["median"],
            "limit_ns": limit, "regression": candidate["median"] > limit}


def compile_consumer(repo, library, scratch, log):
    env = dict(os.environ, SPECIFICATIONCORE_PACKAGE=str(library))
    command = ["swift", "build", "-c", "release", "--package-path",
               str(repo / "Benchmarks/CrossModulePolicy"), "--scratch-path", str(scratch)]
    with log.open("w") as stream:
        run(command, env=env, stdout=stream, stderr=subprocess.STDOUT)
    directory = run(command + ["--show-bin-path"], env=env, capture_output=True,
                    text=True).stdout.strip()
    return Path(directory) / "CrossModulePolicyBenchmark"


def main():
    if sys.version_info < (3, 12):
        raise SystemExit("Python 3.12+ is required for safe baseline archive extraction")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline-ref", required=True)
    parser.add_argument("--output-dir", type=Path, default=Path(".build/policy-performance"))
    parser.add_argument("--samples", type=int, default=5)
    args = parser.parse_args()
    if args.samples < 5:
        parser.error("At least five interleaved process samples are required")
    repo = Path(__file__).resolve().parents[1]
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    baseline_sha = run(["git", "rev-parse", args.baseline_ref], cwd=repo,
                       capture_output=True, text=True).stdout.strip()
    candidate_sha = run(["git", "rev-parse", "HEAD"], cwd=repo,
                        capture_output=True, text=True).stdout.strip()
    with tempfile.TemporaryDirectory(prefix="specificationcore-baseline-") as temporary:
        baseline_source = Path(temporary) / "baseline"
        baseline_source.mkdir()
        archive = run(["git", "archive", baseline_sha], cwd=repo, capture_output=True).stdout
        with tarfile.open(fileobj=io.BytesIO(archive)) as files:
            files.extractall(baseline_source, filter="data")
        binaries = {
            "baseline": compile_consumer(repo, baseline_source, output / "baseline-build", output / "baseline-build.log"),
            "candidate": compile_consumer(repo, repo, output / "candidate-build", output / "candidate-build.log"),
        }
        collected = {variant: [] for variant in binaries}
        for binary in binaries.values():
            parse_sample(run([str(binary)], capture_output=True, text=True).stdout)
        for index in range(args.samples):
            order = ["baseline", "candidate"] if index % 2 == 0 else ["candidate", "baseline"]
            for variant in order:
                raw = run([str(binaries[variant])], capture_output=True, text=True).stdout
                (output / f"{variant}-{index}.csv").write_text(raw)
                collected[variant].append(parse_sample(raw))
    strategies = set(collected["baseline"][0])
    for samples in collected.values():
        for sample in samples:
            if set(sample) != strategies:
                raise ValueError("Strategies differ between revisions or runs")
            for strategy in strategies:
                if sample[strategy]["checksum"] != collected["baseline"][0][strategy]["checksum"]:
                    raise ValueError(f"Semantic checksum mismatch: {strategy}")
    summaries = {variant: {strategy: summarize([sample[strategy]["median"] for sample in samples])
                           for strategy in sorted(strategies)} for variant, samples in collected.items()}
    comparisons = {strategy: compare(summaries["baseline"][strategy], summaries["candidate"][strategy])
                   for strategy in sorted(strategies)}
    harness_files = sorted((repo / "Benchmarks/CrossModulePolicy").glob("Sources/**/*.swift"))
    harness_files.append(repo / "Benchmarks/CrossModulePolicy/Package.swift")
    report = {"baseline_sha": baseline_sha, "candidate_sha": candidate_sha,
              "candidate_dirty": bool(run(["git", "status", "--porcelain"], cwd=repo,
                                           capture_output=True, text=True).stdout),
              "host": platform.platform(),
              "swift": run(["swift", "--version"], capture_output=True, text=True).stdout.strip(),
              "harness_sha256": hashlib.sha256(b"".join(p.read_bytes() for p in harness_files)).hexdigest(),
              "profile": "Release, separate SwiftPM consumer module, tracing disabled",
              "threshold": "baseline * 1.5 + 5 ns + 6 * combined MAD",
              "summaries": summaries, "comparisons": comparisons}
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    lines = ["| Strategy | Baseline ns/candidate | Candidate ns/candidate | Gate |",
             "|---|---:|---:|---|"]
    for strategy, value in comparisons.items():
        state = "REGRESSION" if value["regression"] else "PASS"
        lines.append(f"| {strategy} | {value['baseline_ns']:.2f} | {value['candidate_ns']:.2f} | {state} |")
    markdown = "\n".join(lines) + "\n"
    (output / "report.md").write_text(markdown)
    print(markdown)
    if any(value["regression"] for value in comparisons.values()):
        raise SystemExit("Policy performance regression; inspect report.json and raw CSV")


if __name__ == "__main__":
    main()
