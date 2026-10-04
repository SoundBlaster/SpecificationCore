#!/usr/bin/env python3
"""Run and gate the separate-module StaticFirstMatch Release benchmark."""

import argparse
import csv
import hashlib
import io
import json
import os
import math
from pathlib import Path
import platform
import statistics
import subprocess
import sys


STRATEGIES = {"nested_growing_leaves_chain", "static_balanced"}
CSV_HEADER = ["round", "strategy", "elapsed_ns", "ns_per_candidate", "checksum"]
EXPECTED_ROUNDS = 32


def run(command, **kwargs):
    return subprocess.run(command, check=True, **kwargs)


def parse_sample(output):
    reader = csv.DictReader(io.StringIO(output))
    if reader.fieldnames != CSV_HEADER:
        raise ValueError("Unexpected benchmark CSV schema")
    groups, seen = {}, set()
    for row in reader:
        round_number = int(row["round"])
        strategy = row["strategy"]
        elapsed = int(row["elapsed_ns"])
        rate = float(row["ns_per_candidate"])
        checksum = int(row["checksum"])
        key = (round_number, strategy)
        if (key in seen or round_number < 0 or strategy not in STRATEGIES or elapsed <= 0
                or not math.isfinite(rate) or rate <= 0):
            raise ValueError("Invalid or duplicate benchmark sample")
        seen.add(key)
        groups.setdefault(strategy, []).append((round_number, rate, checksum))
    if set(groups) != STRATEGIES:
        raise ValueError("Expected both benchmark strategies")
    rounds = {sample[0] for sample in groups[next(iter(STRATEGIES))]}
    if rounds != set(range(EXPECTED_ROUNDS)):
        raise ValueError(f"Expected {EXPECTED_ROUNDS} complete benchmark rounds")
    result = {}
    for strategy, samples in groups.items():
        if ({sample[0] for sample in samples} != rounds
                or len({sample[2] for sample in samples}) != 1):
            raise ValueError("Incomplete rounds or unstable result checksum")
        result[strategy] = {
            "median": statistics.median(sample[1] for sample in samples),
            "checksum": samples[0][2],
        }
    if len({summary["checksum"] for summary in result.values()}) != 1:
        raise ValueError("Benchmark strategies produced different semantic checksums")
    return result


def summarize(values):
    median = statistics.median(values)
    return {"samples": values, "median": median,
            "mad": statistics.median(abs(value - median) for value in values)}


def compare(nested, balanced):
    # Coarse, noise-aware protection. This deliberately makes no universal speedup claim.
    limit = nested["median"] * 1.5 + 5 + 6 * (nested["mad"] + balanced["mad"])
    return {"nested_ns_per_candidate": nested["median"],
            "balanced_ns_per_candidate": balanced["median"],
            "limit_ns_per_candidate": limit,
            "regression": balanced["median"] > limit}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path,
                        default=Path(".build/static-first-match-performance"))
    parser.add_argument("--samples", type=int, default=5)
    args = parser.parse_args()
    if args.samples < 5:
        parser.error("At least five process samples are required")

    repo = Path(__file__).resolve().parents[1]
    benchmark = repo / "Benchmarks/StaticFirstMatch"
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    scratch = output / "swift-build"
    command = ["swift", "build", "-c", "release", "--package-path", str(benchmark),
               "--scratch-path", str(scratch)]
    environment = dict(os.environ, SPECIFICATIONCORE_PACKAGE=str(repo))
    with (output / "build.log").open("w") as log:
        run(command, cwd=repo, env=environment, stdout=log, stderr=subprocess.STDOUT)
    binary_dir = run(command + ["--show-bin-path"], cwd=repo, env=environment, capture_output=True,
                     text=True).stdout.strip()
    binary = Path(binary_dir) / "StaticFirstMatchBenchmark"

    collected = {name: [] for name in STRATEGIES}
    for index in range(args.samples):
        raw = run([str(binary)], cwd=repo, capture_output=True, text=True).stdout
        (output / f"sample-{index}.csv").write_text(raw)
        sample = parse_sample(raw)
        for strategy in STRATEGIES:
            collected[strategy].append(sample[strategy])

    checksums = {strategy: {sample["checksum"] for sample in samples}
                 for strategy, samples in collected.items()}
    if any(len(values) != 1 for values in checksums.values()):
        raise ValueError("Unstable benchmark checksum across process samples")
    if checksums["nested_growing_leaves_chain"] != checksums["static_balanced"]:
        raise ValueError("Benchmark strategies produced different semantic checksums")

    summaries = {strategy: summarize([sample["median"] for sample in samples])
                 for strategy, samples in collected.items()}
    comparison = compare(summaries["nested_growing_leaves_chain"],
                         summaries["static_balanced"])
    harness_files = [benchmark / "Package.swift", *sorted((benchmark / "Sources").rglob("*.swift"))]
    status = run(["git", "status", "--porcelain"], cwd=repo, capture_output=True,
                 text=True).stdout
    report = {
        "revision": run(["git", "rev-parse", "HEAD"], cwd=repo, capture_output=True,
                         text=True).stdout.strip(),
        "dirty_worktree": bool(status),
        "host": platform.platform(),
        "swift": run(["swift", "--version"], capture_output=True, text=True).stdout.strip(),
        "harness_sha256": hashlib.sha256(b"".join(path.read_bytes() for path in harness_files)).hexdigest(),
        "settings": {"configuration": "Release", "consumer_module": "separate SwiftPM package",
                     "process_samples": args.samples, "rounds_per_process": 32,
                     "threshold": "nested median * 1.5 + 5 ns + 6 * combined MAD"},
        "summaries": summaries,
        "comparison": comparison,
    }
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    state = "REGRESSION" if comparison["regression"] else "PASS"
    markdown = ("| Nested ns/candidate | Balanced ns/candidate | Gate |\n"
                "|---:|---:|---|\n"
                f"| {comparison['nested_ns_per_candidate']:.2f} | "
                f"{comparison['balanced_ns_per_candidate']:.2f} | {state} |\n")
    (output / "report.md").write_text(markdown)
    print(markdown, end="")
    if comparison["regression"]:
        raise SystemExit("StaticFirstMatch performance regression; inspect report and raw CSV")


if __name__ == "__main__":
    main()
