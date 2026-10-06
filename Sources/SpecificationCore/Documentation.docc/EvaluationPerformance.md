# Choosing Evaluation Performance

Choose whether synchronous rule evaluation favors runtime speed or compilation turnaround.

## Overview

SpecificationCore enables the `AggressiveInlining` SwiftPM trait by default.
It adds `@inline(__always)` to synchronous evaluation methods that already use
`@inlinable`, allowing the compiler to specialize composed generic rules across
module boundaries. Results, first-match priority and short-circuiting stay the same.
The setting is selected when building the package, not while the application runs.
It does not introduce new `@frozen` types or promise binary library-evolution support.

Use the default for rules evaluated repeatedly in a hot path. Consider disabling
it when compilation turnaround is more important or profiling shows rule
evaluation is a negligible part of your workload. It does not accelerate filesystem
I/O, expensive work inside a predicate, or all dynamic rule collections.

## Configure a Dependency

This feature is currently on the `codex/default-performance-inlining` branch,
not a published version. The examples use that branch so they do not imply an
older release contains the trait. After release, replace `branch:` with the version
requirement for a release containing the feature. Package traits require SwiftPM 6.1 or later.

Keep the performance default by omitting the traits argument:

```swift
.package(
    url: "https://github.com/SoundBlaster/SpecificationCore.git",
    branch: "codex/default-performance-inlining"
)
```

Disable default traits to favor compilation turnaround:

```swift
.package(
    url: "https://github.com/SoundBlaster/SpecificationCore.git",
    branch: "codex/default-performance-inlining",
    traits: []
)
```

Explicitly select performance with `traits: ["AggressiveInlining"]`, or select
tracing with `traits: ["Tracing"]`. Even when both are selected, Tracing disables
forced inlining so diagnostic builds retain their tracing behavior.

Traits are additive across a dependency graph. An empty list opts out of defaults
for your declaration; it cannot prevent another dependency from enabling the trait.
See [SwiftPM package traits (SE-0450)](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md).

## Build the Root Package

These commands apply when SpecificationCore itself is the root package:

```sh
swift test                                      # Performance default
swift test --disable-default-traits              # Without forced inlining
swift test --traits Tracing                      # Tracing only
swift test --traits AggressiveInlining,Tracing   # Tracing still disables forced inlining
```

The same trait arguments can be used with `swift build -c release`. Benchmark
Release builds: Debug behavior is not evidence of the optimized runtime benefit.

## Measured Benefit and Cost

On Apple Silicon with Swift 6.4, repeated separate-module Release benchmarks
using ten alternating process pairs produced these results:

| Workload | Observed evaluation speedup |
| --- | --- |
| Nested growing-leaf chain | About 57–65x |
| Balanced static chain | About 3x |
| Dynamic `FirstMatchSpec` | No material improvement |

The library and consumer were compiled separately using their package language
modes. These numbers describe the benchmark workloads, not full BuildHunter scans
or arbitrary consumer applications. The measured combined library/consumer
`__TEXT` size did not grow. No measured strategy had a statistically confirmed
runtime regression exceeding 5%.

Clean compilation-time medians across runs were +18.8%, +3.3% and +1.6%, with
substantial variation between compilation pairs. Treat compile time as a measured
tradeoff, not a fixed surcharge or a guaranteed saving when disabling the trait.
The performance default was chosen because the runtime gains justified the observed
cost; the opt-out preserves the alternative for consumers with different priorities.

Measure your application's hot path and clean builds with the trait on and off
before attributing an application-level improvement to it. Source-package results
do not establish an equivalent benefit for an XCFramework or a library-evolution build.

## See Also

- <doc:StaticFirstMatch>
- <doc:Tracing>
- ``FirstMatchSpec``
