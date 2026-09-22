# Changelog

All notable changes to SpecificationCore will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.0.0] - 2026-09-23

### Added
- Opt-in `Tracing` SwiftPM trait with structured specification evaluation events, a thread-safe recorder, default recording, custom tracing macros, and named sync/async wrappers.
- Async named modifiers `tracedAsync(_:)` and `withoutTracingAsync()` for specifications and decisions.

### Changed
- Raise the minimum Swift tools version from 5.10 to 6.1 to support SwiftPM traits. The package remains in Swift 5 language mode.
- Preserve typed errors in macro-instrumented async Boolean and decision evaluations, and preserve short-circuit behavior for lazy collections when tracing is enabled.

## [1.1.0] - 2026-09-21

### Added
- Asynchronous typed decision specifications, first-match evaluation, and short-circuit composition through `andAsync`, `orAsync`, `notAsync`, and `returningAsync`.

## [1.0.1] - 2026-09-19

### Changed
- `FirstMatchSpec.Builder.build()` now explicitly constructs `SpecificationPair` values without changing the public API.
- CI validates changed Swift files and tests against maintained macOS and Linux toolchains.

### Fixed
- Resolve an ambiguous initializer call in `FirstMatchSpec.Builder.build()` on Swift 6.4 and newer.
- Correct macOS CI Xcode selection for current GitHub-hosted runners.

## [1.0.0] - 2025-11-19

### Added
- Initial extraction of platform-independent core from SpecificationKit
- Core protocols: Specification, DecisionSpec, AsyncSpecification, ContextProviding
- Type erasure: AnySpecification, AnyAsyncSpecification, AnyDecisionSpec, AnyContextProvider
- Context infrastructure: EvaluationContext, DefaultContextProvider, MockContextProvider
- Basic specifications: PredicateSpec, FirstMatchSpec, MaxCountSpec, CooldownIntervalSpec, TimeSinceEventSpec, DateRangeSpec, DateComparisonSpec
- Property wrappers: @Satisfies, @Decides, @Maybe, @AsyncSatisfies (platform-independent)
- Macros: @specs, @AutoContext
- Definitions: AutoContextSpecification, CompositeSpec
- Comprehensive test suite with >90% coverage
- Complete API documentation
- CI/CD pipeline for macOS and Linux

### Changed
- N/A (initial release)

### Deprecated
- N/A (initial release)

### Removed
- N/A (initial release)

### Fixed
- N/A (initial release)

### Security
- N/A (initial release)
