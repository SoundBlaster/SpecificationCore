#!/usr/bin/env python3
"""Disposable actual-source H6/H20 annotation matrix; never edits production files."""
import argparse
import hashlib
import json
import math
from pathlib import Path
import platform
import random
import re
import shutil
import statistics
import subprocess
import time

from compare_policy_performance import parse_sample

FILES = ["Core/Specification.swift", "Core/DecisionSpec.swift",
         "Core/StaticFirstMatch.swift", "Core/AnySpecification.swift",
         "Specs/PredicateSpec.swift", "Specs/FirstMatchSpec.swift"]
FROZEN = ["AndSpecification", "OrSpecification", "NotSpecification",
          "BooleanDecisionAdapter", "PredicateDecisionSpec", "BinaryFirstMatch",
          "StaticFirstMatch", "AnySpecification", "PredicateSpec", "FirstMatchSpec"]
VARIANTS = ["baseline", "inline", "inline_frozen"]
WORKLOADS = {"static": "StaticFirstMatch", "policy": "CrossModulePolicy"}
TARGET_STRATEGY = "nested_growing_leaves_chain"


def performance_qualified(cells):
    if not cells or any(c["status"] != "MEASURED" for c in cells.values()):
        return False
    target = cells.get("static", {}).get("strategies", {}).get(TARGET_STRATEGY)
    return bool(target and target["target_gain"] and all(
        c["cost_gate"] and not any(s["significant_regression"]
                                  for s in c["strategies"].values())
        for c in cells.values()))


def paired_summary(ratios):
    if not ratios or any(not math.isfinite(value) or value <= 0 for value in ratios):
        raise ValueError("Positive paired ratios required")
    rng = random.Random(25)
    medians = sorted(statistics.median(rng.choices(ratios, k=len(ratios)))
                     for _ in range(10000))
    return {"ratios": ratios, "median": statistics.median(ratios),
            "ci95": [medians[250], medians[9749]],
            "target_gain": statistics.median(ratios) <= .90 and medians[9749] < 1,
            "significant_regression": medians[250] > 1.05}


def transform(text, variant):
    if variant == "baseline":
        return text
    text = re.sub(r"(@inlinable)(\s*(?:#endif\s*)?(?:public\s+)?func\s+"
                  r"(?:isSatisfiedBy|decide|decideWithMetadata)\b)",
                  # The additional attribute is guarded even when the existing
                  # @inlinable declaration is unconditional (e.g. AnySpecification).
                  r"\1\n#if !Tracing\n@inline(__always)\n#endif\2", text)
    if variant == "inline_frozen":
        for name in FROZEN:
            text = re.sub(r"(?m)^public struct " + name + r"\b",
                          "@frozen\npublic struct " + name, text)
    return text


def run_logged(command, log):
    start = time.perf_counter()
    with log.open("w") as stream:
        result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
    return result.returncode, time.perf_counter() - start


def text_bytes(binary):
    raw = subprocess.check_output(["size", "-m", str(binary)], text=True)
    match = re.search(r"Segment __TEXT:\s*(\d+)", raw)
    if not match:
        raise ValueError("Mach-O __TEXT size unavailable")
    return int(match[1])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", required=True, type=Path)
    parser.add_argument("--pairs", type=int, default=10)
    parser.add_argument("--build-pairs", type=int, default=3)
    args = parser.parse_args()
    if args.pairs < 10 or args.build_pairs < 3:
        parser.error("Acceptance requires >=10 runtime and >=3 build pairs")
    repo = Path(__file__).resolve().parents[1]
    output = args.output_dir.resolve()
    if output.exists():
        parser.error("Use a fresh output directory; prior evidence is never overwritten")
    output.mkdir(parents=True)
    sources = repo / "Sources/SpecificationCore"
    originals = sorted(p for p in sources.rglob("*.swift")
                       if "Documentation.docc" not in p.parts)
    compiler = shutil.which("swiftc")
    if compiler is None or platform.machine() != "arm64":
        parser.error("This bounded probe requires an Apple Silicon Mac with swiftc")
    report = {"revision": subprocess.check_output(["git", "rev-parse", "HEAD"],
                                                  cwd=repo, text=True).strip(),
              "swift": subprocess.check_output([compiler, "--version"], text=True),
              "host": platform.platform(), "machine": platform.machine(),
              "dirty": bool(subprocess.check_output(["git", "status", "--porcelain"],
                                                     cwd=repo, text=True).strip()),
              "frozen_types": FROZEN, "cells": {}, "runtime": {}}
    harness = Path(__file__).read_bytes()
    (output / "harness.py").write_bytes(harness)
    report["harness_sha256"] = hashlib.sha256(harness).hexdigest()
    report["consumer_sha256"] = {
        name: hashlib.sha256((repo / f"Benchmarks/{folder}/Sources/{folder}Benchmark/main.swift")
                             .read_bytes()).hexdigest() for name, folder in WORKLOADS.items()}
    flags = ["-O", "-whole-module-optimization", "-target", "arm64-apple-macosx14.0"]
    report["flags"] = flags
    report["language_modes"] = {"library": "5 (Package.swift)", "consumer": "6 (benchmark package)"}

    def checkpoint():
        (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")

    copies = {}
    for variant in VARIANTS:
        root = output / variant / "source"
        copies[variant] = []
        for original in originals:
            relative = original.relative_to(sources)
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            text = original.read_text()
            target.write_text(transform(text, variant) if str(relative) in FILES else text)
            copies[variant].append(target)
        report.setdefault("source_sha256", {})[variant] = hashlib.sha256(
            b"".join(p.read_bytes() for p in copies[variant])).hexdigest()

    for evolution in [False, True]:
        mode = "evolution" if evolution else "source"
        for round_number in range(args.build_pairs):
            order = VARIANTS if round_number % 2 == 0 else list(reversed(VARIANTS))
            for variant in order:
                key = f"{mode}/{variant}"
                cell = report["cells"].setdefault(key, {"builds": []})
                directory = output / key / str(round_number)
                directory.mkdir(parents=True)
                library = directory / "libSpecificationCore.dylib"
                command = [compiler, *flags, "-swift-version", "5", "-module-name", "SpecificationCore",
                           "-emit-library", "-emit-module", "-emit-module-path",
                           str(directory / "SpecificationCore.swiftmodule"),
                           "-o", str(library), *map(str, copies[variant])]
                if evolution:
                    command.insert(1, "-enable-library-evolution")
                code, duration = run_logged(command, directory / "library.log")
                build = {"library_exit": code, "library_seconds": duration,
                         "library_command": command, "consumers": {}}
                cell["builds"].append(build)
                if code == 0:
                    build["library_text_bytes"] = text_bytes(library)
                    for workload, folder in WORKLOADS.items():
                        consumer = repo / f"Benchmarks/{folder}/Sources/{folder}Benchmark/main.swift"
                        executable = directory / workload
                        client_command = [compiler, *flags, "-swift-version", "6", "-I", str(directory),
                                          "-L", str(directory), "-lSpecificationCore",
                                          "-Xlinker", "-rpath", "-Xlinker", str(directory),
                                          str(consumer), "-o", str(executable)]
                        result, elapsed = run_logged(client_command, directory / f"{workload}.log")
                        build["consumers"][workload] = {"exit": result, "seconds": elapsed,
                                                       "command": client_command}
                        if result == 0:
                            build["consumers"][workload]["text_bytes"] = text_bytes(executable)
                            if round_number == 0:
                                raw = subprocess.check_output([str(executable)], text=True)
                                (directory / f"{workload}-semantic-smoke.csv").write_text(raw)
                                build["consumers"][workload]["semantic_smoke"] = parse_sample(raw)
                                sil_command = [compiler, *flags, "-swift-version", "6", "-I", str(directory),
                                               "-emit-sil", "-Rpass-missed=sil-generic-specializer",
                                               str(consumer), "-o", str(directory / f"{workload}.sil")]
                                sil_exit, _ = run_logged(sil_command,
                                                        directory / f"{workload}-specialization.log")
                                build["consumers"][workload]["sil_exit"] = sil_exit
                checkpoint()
                print(key, round_number, "library exit", code, flush=True)

        for variant in VARIANTS[1:]:
            comparisons = {}
            for workload in WORKLOADS:
                baseline_builds = report["cells"][f"{mode}/baseline"]["builds"]
                candidate_builds = report["cells"][f"{mode}/{variant}"]["builds"]
                if not all(b["library_exit"] == 0 and
                           b["consumers"].get(workload, {}).get("exit") == 0
                           for b in baseline_builds + candidate_builds):
                    comparisons[workload] = {"status": "BUILD_FAILED_OR_UNAVAILABLE"}
                    continue
                processes = {v: [] for v in ["baseline", variant]}
                checksums = {}
                for pair in range(args.pairs):
                    for v in (["baseline", variant] if pair % 2 == 0 else [variant, "baseline"]):
                        binary = output / mode / v / "0" / workload
                        raw = subprocess.check_output([str(binary)], text=True)
                        (output / f"{mode}-{variant}-{workload}-{pair}-{v}.csv").write_text(raw)
                        sample = parse_sample(raw)
                        for strategy, stats in sample.items():
                            old = checksums.setdefault(strategy, stats["checksum"])
                            if old != stats["checksum"]:
                                raise ValueError("Cross-variant checksum mismatch")
                        processes[v].append(sample)
                strategies = set(processes["baseline"][0])
                if any(set(sample) != strategies for v in processes for sample in processes[v]):
                    raise ValueError("Strategy mismatch")
                summaries = {strategy: paired_summary([
                    processes[variant][i][strategy]["median"] /
                    processes["baseline"][i][strategy]["median"]
                    for i in range(args.pairs)]) for strategy in sorted(strategies)}
                build_ratios, size_ratios = [], []
                for a, b in zip(baseline_builds, candidate_builds):
                    build_ratios.append((b["library_seconds"] + b["consumers"][workload]["seconds"]) /
                                        (a["library_seconds"] + a["consumers"][workload]["seconds"]))
                    size_ratios.append((b["library_text_bytes"] + b["consumers"][workload]["text_bytes"]) /
                                       (a["library_text_bytes"] + a["consumers"][workload]["text_bytes"]))
                comparisons[workload] = {"status": "MEASURED", "strategies": summaries,
                                         "build_ratios": build_ratios, "text_ratios": size_ratios,
                                         "cost_gate": statistics.median(build_ratios) <= 1.15 and
                                                      max(size_ratios) <= 1.10}
            report["runtime"][f"{mode}/{variant}"] = comparisons
            checkpoint()
    report["source_eligibility"] = {}
    for variant in VARIANTS[1:]:
        cells = report["runtime"][f"source/{variant}"]
        qualified = performance_qualified(cells)
        report["source_eligibility"][variant] = (
            "PERFORMANCE_QUALIFIED_PENDING_SEMANTICS_AND_CI" if qualified else
            "NOT_QUALIFIED_OR_INCOMPLETE")
    report["decision"] = "Experiment only: default/Tracing tests and CI required before adoption; freezing requires ABI review"
    checkpoint()
    if any(comparison["status"] != "MEASURED"
           for key, workloads in report["runtime"].items() if key.startswith("source/")
           for comparison in workloads.values()):
        raise SystemExit("Source-mode experiment incomplete; inspect build logs")


if __name__ == "__main__":
    main()
