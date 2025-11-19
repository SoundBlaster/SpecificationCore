# Changelog

All notable changes to SpecificationCore will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

## [0.1.0] - TBD

Initial release of SpecificationCore - platform-independent foundation for the Specification Pattern in Swift.
