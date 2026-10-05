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

## Local result (2026-10-05, source-package language modes)
Swift compiler: `Apple Swift version 6.4 (swiftlang-6.4.0.34.1 clang-2100.3.34.1)
Target: arm64-apple-macosx27.0.0`. Full production source module uses
Swift 5 language mode; consumers use Swift 6. Arm64 macOS 14 deployment target,
`-O -whole-module-optimization`; actual host: macOS-27.0-arm64-arm-64bit.
Ten alternating process pairs and three alternating clean compilation pairs per
cell. Ratios below are candidate/baseline; intervals are paired bootstrap 95%.
| Variant | Workload | Median ratio | 95% interval | Cost gate |
|---|---|---:|---|---|
| inline | nested_growing_leaves_chain | 0.0159 | 0.0157–0.0161 | pass |
| inline | static_balanced | 0.3249 | 0.3225–0.3392 | pass |
| inline | first_match | 1.0078 | 0.9973–1.0124 | pass |
| inline | composition | 1.0008 | 0.9944–1.0108 | pass |
| inline_frozen | nested_growing_leaves_chain | 0.0170 | 0.0170–0.0174 | pass |
| inline_frozen | static_balanced | 0.3267 | 0.3167–0.3317 | pass |
| inline_frozen | first_match | 1.0025 | 0.9911–1.0090 | pass |
| inline_frozen | composition | 0.9995 | 0.9886–1.0141 | pass |

Both source-mode candidates meet the targeted benchmark improvement and cost
gates in this local run; no significant >5% regression was observed in the other
consumer strategies. This does not establish full semantic or distribution
acceptance. Production sources remain unchanged.

- inline/static: median build-time ratio 1.0299; maximum total __TEXT ratio 1.0000.
- inline/policy: median build-time ratio 0.9930; maximum total __TEXT ratio 1.0000.
- inline_frozen/static: median build-time ratio 1.0231; maximum total __TEXT ratio 1.0000.
- inline_frozen/policy: median build-time ratio 0.9762; maximum total __TEXT ratio 1.0000.

Library-evolution baseline and inline-only module builds failed; all three
inline+frozen builds succeeded and both consumers passed their independent
reference/parity smoke checks. Since no evolution baseline executable exists,
**no evolution-mode speedup comparison is claimed**. The frozen list is
experimental, not an accepted ABI change.

Raw CSV, commands, compiler logs, source snapshots, client SIL and report.json
are retained in the local experiment output and the CI artifact. CI runs the
candidate default and Tracing suites separately; those results remain pending.
