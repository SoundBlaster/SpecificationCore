# Evaluation performance and build-time choice

SpecificationCore enables the `AggressiveInlining` SwiftPM trait by default.
It adds `@inline(__always)` to synchronous Boolean/decision evaluation methods
that already expose their bodies with `@inlinable`. It does not change results,
first-match priority, short-circuiting, public APIs or deployment requirements.
Forced inlining is disabled whenever `Tracing` is enabled, including when both
traits are selected. No types are newly `@frozen`; no binary ABI commitment is made.

## Choose at build time

Ordinary dependency declarations keep the performance default. A direct consumer
can opt out of default traits in its dependency declaration:

```swift
.package(
    url: "https://github.com/SoundBlaster/SpecificationCore.git",
    branch: "codex/default-performance-inlining",
    traits: []
)
```

This feature is not yet released. After release, replace the branch requirement
with a version requirement for a release containing the trait. For the full
configuration guide, see [Choosing Evaluation Performance](../Sources/SpecificationCore/Documentation.docc/EvaluationPerformance.md).
To opt out while using traces, select `traits: ["Tracing"]`.
For a local root-package build use `swift test --disable-default-traits`.

Traits are additive across the dependency graph: another dependency that enables
AggressiveInlining can still activate it. This option is a compilation choice,
not a runtime setting, and does not promise an exact compile-time saving.

Reference: [SwiftPM package traits (SE-0450)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md).

## Acceptance decision (2026-10-05)

The initial experiment's 15% build-time gate remains recorded unchanged. In its
review-fixed local run inline-only missed that gate at 1.188x build time, while
the nested growing-leaf and balanced workloads ran at about 0.015x and 0.321x
baseline time. These are separate-module benchmark results, not whole-scan gains.
Dynamic FirstMatchSpec did not materially improve.

The product owner explicitly chose evaluation performance over this measured
compile-time increase. Adoption therefore treats measured build time as a
reported tradeoff requiring review, rather than using the original 15% threshold
as an automatic veto. Semantic, runtime-gain and binary-size requirements remain;
higher or inconsistent costs must be reported rather than hidden or reclassified.

The trait provides the alternative for consumers that value build time more.
Default/off/Tracing/both semantic suites and a fresh actual-source on/off matrix
must pass or be reviewed on this production head before merge. The experiment's
eligibility still uses its original cost gate and may report inline-only as not
qualified; that is not retroactively changed into an experimental PASS.

## Production trait on/off repeat

The 2026-10-05 local repeat compiles the same shipping source with and without
`-D AggressiveInlining`, then benchmarks a separately compiled consumer in ten
alternating process pairs. The nested-chain median time ratio was 0.01615
(about 62x faster; paired bootstrap 95% interval 0.01576–0.01623). The balanced
ratio was 0.32008 (about 3.1x faster; interval 0.31650–0.33256). Dynamic
FirstMatchSpec remained effectively unchanged at 0.99353.

The three static-workload clean compilation ratios were 0.693, 1.033 and 1.383:
their median is +3.3%, but the variation is large. This does not invalidate the
earlier +18.8% median or establish a reliable fixed compilation cost. Combined
library/consumer `__TEXT` size ratios were 1.0. No measured strategy had a
statistically confirmed regression exceeding 5%.

Raw report and command logs are in
`/private/tmp/SpecificationCore-performance-trait-20261005` on the measurement
host; CI uploads independent reports. Source builds passed reference-parity
checks. Library-evolution comparison remains unavailable because the baseline
does not compile in that mode; this PR does not adopt frozen layouts.

A second independent local repeat (`SpecificationCore-performance-trait-repeat-20261005-1111`)
measured ratios 0.01753 for the nested chain (about 57x) and 0.33180 for the balanced
chain (about 3x), again with unchanged `__TEXT` size and no confirmed >5% regression.
Its clean compilation ratios were 0.808, 1.071 and 1.016 (median +1.6%). Together
the repeats establish a stable runtime benefit for these workloads, while compile
cost remains variable. All four trait semantic suites passed CI on production
head `9ed6a7c`; documentation updates require their own DocC build validation.
