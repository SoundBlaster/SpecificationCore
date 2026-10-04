# Cross-module policy benchmark

This executable imports the SwiftPM `SpecificationCore` product into a separate client module. It measures library `PredicateSpec`, Boolean composition, ordered `FirstMatchSpec`, `Specification.returning`, and `PredicateDecisionSpec` APIs. Before timing, it checks every result from every strategy against an independent decision function. Timed rounds rotate strategy order and emit raw CSV rows; compare distributions across multiple runs instead of using an absolute nanosecond threshold.

Run the candidate from the repository root:

```sh
rtk swift run -c release --package-path Benchmarks/CrossModulePolicy
```

To measure the base revision, export that revision into a separate directory and point the consumer package at it. The export should contain the complete package, including `Package.swift` and `Sources/`:

```sh
rtk proxy git archive 9a791d1c90c70293f9f4dd30de604e39dc191639 | rtk proxy tar -x -C /Volumes/FlashCard/SpecificationCore-baseline
rtk proxy env SPECIFICATIONCORE_PACKAGE=/Volumes/FlashCard/SpecificationCore-baseline rtk swift run -c release --package-path Benchmarks/CrossModulePolicy
```

Use a fresh scratch path for each build if comparing in the same checkout. Repeat each executable several times and retain the full CSV output. Building each variant with `-c release` keeps the consumer and dependency in optimized mode while preserving the module boundary.

## Same-host revision comparison

Use Python 3.12+ and run from the repository root:

```sh
python3 scripts/test_policy_performance_report.py
python3 scripts/compare_policy_performance.py --baseline-ref origin/main
```

The script exports the baseline, compiles this same consumer against each library in separate scratch directories, warms both executables and alternates five process pairs. It verifies complete round sets and stable matching checksums before comparing process medians. Raw CSV, compiler logs, SHAs, harness digest and median/MAD JSON are in `.build/policy-performance/`. CI uploads those artifacts and applies a coarse regression budget (`baseline × 1.5 + 5 ns + 6 × combined MAD`). These synthetic figures do not measure BuildHunter scans or guarantee speedups for every API.
