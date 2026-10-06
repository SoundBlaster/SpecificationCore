# H6/H20 annotation experiment acceptance

Baseline: SpecificationCore main `3cfe27bd9bb260ca57b00f9202e077c7f1122a4e`.
This experiment changes neither the Swift compiler nor BuildHunter dependencies.
Variants are disposable source copies: baseline, additional non-Tracing evaluation
`@inline(__always)`, and the same annotations plus explicitly enumerated `@frozen`
structs. Production annotations are adopted only in a subsequent reviewed change.

## Acceptance fixed before measurements

1. Semantic gate: existing default and Tracing tests pass for an adopted patch;
   exhaustive benchmark parity/checksums, first-match priority, short-circuit and
   no-match behavior are unchanged. No API removal or deployment/toolchain bump.
2. Runtime gate: at least 10 alternating independent process pairs per workload,
   warm-up excluded; paired median candidate/baseline <= 0.90 on the targeted
   growing-leaf workload, and paired bootstrap 95% upper bound < 1.0. Other
   workloads have no significant >5% regression (lower bound >1.05 rejects).
   An inconclusive non-regression result does not prove equivalence.
3. Cost gate: at least three alternating clean module+consumer compilation pairs;
   median total build-time ratio <=1.15 and total library+consumer Mach-O __TEXT
   growth <=1.10. Capture flags, Swift/OS/CPU, source digests, logs and raw samples.
4. Representation gate: normal source builds and library-evolution builds are
   separate cells. A failed cell records diagnostics, not a successful timing.
   Full production module (not a replica or trimmed protocol subset) must build
   in library-evolution mode before claiming binary-distribution support.
5. ABI gate: enumerate frozen types and stored fields. Do not freeze every public
   type merely to make a probe compile. A freezing-only change needs an explicit
   binary-distribution requirement; speed alone does not justify its ABI promise.
6. Compiler evidence: emit client SIL/specialization remarks separately from timed
   builds; inspect remaining library calls. Disappearing warnings alone is not
   performance acceptance. Static/LTO/CMO changes are outside this patch.

## Decision

PASS requires semantic, runtime, cost and relevant representation gates. If no
variant passes, publish a negative/inconclusive result and keep production source
unchanged. Do not claim whole-scan improvement from consumer benchmarks. Repeat
accepted results on CI before merge; released versions remain a separate stage.

## Reproduce

```sh
python3 scripts/experiment_annotations.py --output-dir /path/with/space
```

The script builds full non-Tracing production sources directly with swiftc as a
separate dynamic module, including macro declarations (macros are not invoked by
these consumers). This isolates annotations without rebuilding SwiftSyntax. The library explicitly
uses Swift 5 language mode, matching its Package.swift; consumers use Swift 6,
matching the benchmark packages. This is not a language-mode migration.
It does not replace SwiftPM default/Tracing tests or Xcode integration acceptance.
A public macro-plugin warning in this direct compiler probe is retained in logs;
macro functionality must still be verified through the ordinary package tests.

## Local result: review-fixed rerun (2026-10-05)
Swift compiler: `Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)
Target: arm64-apple-macosx27.0.0`. Full production source module uses
Swift 5 language mode; consumers use Swift 6. Arm64 macOS 14 deployment target,
`-O -whole-module-optimization`; actual host: macOS-27.0-arm64-arm-64bit.
Ten alternating process pairs and three alternating clean compilation pairs per
cell. Ratios below are candidate/baseline; intervals are paired bootstrap 95%.

| Variant | Workload | Median ratio | 95% interval | Cost gate |
|---|---|---:|---|---|
| inline | nested_growing_leaves_chain | 0.0154 | 0.0150–0.0159 | fail |
| inline | static_balanced | 0.3210 | 0.3140–0.3328 | fail |
| inline | first_match | 1.0024 | 0.9875–1.0223 | pass |
| inline | composition | 1.0105 | 1.0057–1.0226 | pass |

inline: `NOT_QUALIFIED_OR_INCOMPLETE`.
| inline_frozen | nested_growing_leaves_chain | 0.0158 | 0.0156–0.0167 | pass |
| inline_frozen | static_balanced | 0.3379 | 0.3317–0.3428 | pass |
| inline_frozen | first_match | 1.0064 | 0.9935–1.0131 | pass |
| inline_frozen | composition | 1.0076 | 1.0019–1.0176 | pass |

inline_frozen: `PERFORMANCE_QUALIFIED_PENDING_SEMANTICS_AND_CI`.

This rerun supersedes the initial local table. Forced inlining is now explicitly
non-Tracing even for unconditional @inlinable methods. The gain requirement
applies only to `nested_growing_leaves_chain`; all other strategies retain the
regression gate. Production source files remain unchanged.

- inline/static: median build-time ratio 1.1884; maximum total __TEXT ratio 1.0000.
- inline/policy: median build-time ratio 0.9652; maximum total __TEXT ratio 1.0000.
- inline_frozen/static: median build-time ratio 1.1363; maximum total __TEXT ratio 1.0000.
- inline_frozen/policy: median build-time ratio 1.0582; maximum total __TEXT ratio 1.0000.

Library-evolution baseline and inline-only module builds failed; all three
inline+frozen builds succeeded and both consumers passed their independent
reference/parity smoke checks. Since no evolution baseline executable exists,
**no evolution-mode speedup comparison is claimed**. The frozen list is
experimental, not an accepted ABI change.

Raw CSV, commands, compiler logs, source snapshots, client SIL and report.json
are retained in the local experiment output and the CI artifact. Source and
benchmark changes now trigger the experiment workflow. CI repeats the revised
matrix and candidate default/Tracing suites on the new commit; results for the
previous commit do not establish acceptance of this revision.
