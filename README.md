# SpecificationCore

Platform-independent foundation for the Specification Pattern in Swift.

[![Swift Version](https://img.shields.io/badge/Swift-5.10+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20%7C%20macOS%20%7C%20tvOS%20%7C%20watchOS%20%7C%20Linux-blue.svg)](https://swift.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Overview

**SpecificationCore** is a lightweight, platform-independent Swift package that provides the foundational components for building specification-based systems. It contains core protocols, type erasure wrappers, context providers, basic specifications, property wrappers, and macros necessary for implementing the Specification Pattern across all Swift platforms.

This package is extracted from [SpecificationKit](https://github.com/yourusername/SpecificationKit) to provide a minimal, dependency-free core that can be used independently or as a foundation for platform-specific extensions.

## Features

### Core Protocols
- **Specification** - Base protocol for boolean specifications with composition operators
- **DecisionSpec** - Protocol for specifications that return typed results
- **AsyncSpecification** - Async/await support for asynchronous specifications
- **ContextProviding** - Protocol for providing evaluation context

### Type Erasure
- **AnySpecification** - Type-erased specification wrapper
- **AnyAsyncSpecification** - Type-erased async specification wrapper
- **AnyDecisionSpec** - Type-erased decision specification wrapper
- **AnyContextProvider** - Type-erased context provider wrapper

### Context Infrastructure
- **EvaluationContext** - Immutable context struct containing counters, events, flags, and user data
- **DefaultContextProvider** - Thread-safe singleton provider with mutable state
- **MockContextProvider** - Testing utility for controlled context scenarios

### Basic Specifications
- **PredicateSpec** - Closure-based specification
- **FirstMatchSpec** - Priority-based decision specification
- **MaxCountSpec** - Counter limit checking
- **CooldownIntervalSpec** - Time-based cooldown
- **TimeSinceEventSpec** - Event timing validation
- **DateRangeSpec** - Date range checking
- **DateComparisonSpec** - Date comparison operators

### Property Wrappers
- **@Satisfies** - Boolean specification evaluation
- **@Decides** - Non-optional decision with fallback
- **@Maybe** - Optional decision without fallback
- **@AsyncSatisfies** - Async specification evaluation

### Macros
- **@specs** - Composite specification synthesis
- **@AutoContext** - Automatic context provider injection

## Requirements

- Swift 5.10+
- iOS 13.0+ / macOS 10.15+ / tvOS 13.0+ / watchOS 6.0+
- Linux (Ubuntu 20.04+)

## Installation

### Swift Package Manager

Add SpecificationCore to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/SpecificationCore.git", from: "0.1.0")
]
```

Then add it to your target dependencies:

```swift
targets: [
    .target(
        name: "YourTarget",
        dependencies: ["SpecificationCore"]
    )
]
```

## Quick Start

### Basic Specification

```swift
import SpecificationCore

// Create a simple predicate specification
let isAdult = PredicateSpec<Int> { age in age >= 18 }

// Evaluate
let age = 25
print(isAdult.isSatisfiedBy(age)) // true
```

### Composition

```swift
let isTeenager = PredicateSpec<Int> { age in age >= 13 && age < 20 }
let isMinor = PredicateSpec<Int> { age in age < 18 }

// Compose specifications
let isYoungAdult = isAdult.and(!isMinor)
let canVote = isAdult.or(isTeenager)
```

### Property Wrappers

```swift
struct User {
    let age: Int

    @Satisfies(using: PredicateSpec<Int> { $0 >= 18 })
    var isAdult: Bool
}

// Usage
let user = User(age: 25)
print(user.isAdult) // Evaluates specification automatically
```

### Context-Based Specifications

```swift
// Setup context
DefaultContextProvider.shared.setCounter("loginAttempts", to: 3)

// Create specification using context
let loginAllowed = MaxCountSpec(counterKey: "loginAttempts", maximumCount: 5)

// Evaluate with context
let context = DefaultContextProvider.shared.currentContext()
print(loginAllowed.isSatisfiedBy(context)) // true (3 <= 5)
```

### Decision Specifications

```swift
enum DiscountTier { case none, basic, premium }

let discountDecision = FirstMatchSpec<EvaluationContext, DiscountTier>(
    decisions: [
        (MaxCountSpec(counterKey: "purchases", maximumCount: 10).not(), .premium),
        (MaxCountSpec(counterKey: "purchases", maximumCount: 5).not(), .basic)
    ]
)

DefaultContextProvider.shared.setCounter("purchases", to: 7)
let context = DefaultContextProvider.shared.currentContext()
print(discountDecision.decide(context)) // Optional(.basic)
```

### Macros

```swift
import SpecificationCore

@specs
struct PaymentEligibility {
    let hasValidPaymentMethod: PredicateSpec<User>
    let hasActiveSubscription: PredicateSpec<User>
    let isNotBlacklisted: PredicateSpec<User>
}

// Macro generates:
// - allSpecs: Specification
// - anySpec: Specification
```

## Architecture

SpecificationCore follows a layered architecture:

1. **Foundation Layer** - Core protocols and type erasure
2. **Context Layer** - Evaluation context and providers
3. **Specifications Layer** - Basic specification implementations
4. **Wrappers Layer** - Property wrappers for declarative syntax
5. **Macros Layer** - Compile-time code generation

All components are platform-independent and have zero dependencies on UI frameworks (SwiftUI, UIKit, AppKit).

## Platform Independence

SpecificationCore is designed to work on **all Swift platforms**:

- **Apple Platforms**: iOS, macOS, tvOS, watchOS
- **Linux**: Ubuntu 20.04+
- **Windows**: Windows 10+ (Swift 5.9+)

The package uses `#if canImport(Combine)` for optional Combine support, ensuring it compiles even on platforms without Combine.

## Relationship to SpecificationKit

**SpecificationCore** provides the platform-independent foundation.

**SpecificationKit** builds on SpecificationCore with:
- SwiftUI integrations (@ObservedSatisfies, @ObservedDecides, @ObservedMaybe)
- Platform-specific context providers (iOS, macOS, watchOS, tvOS)
- Advanced domain specifications (FeatureFlagSpec, SubscriptionStatusSpec)
- Performance profiling tools (PerformanceProfiler, SpecificationTracer)
- Example code and tutorials

If you only need core functionality without platform-specific features, use **SpecificationCore** alone for faster builds and minimal dependencies.

## Documentation

- [API Documentation](https://yourusername.github.io/SpecificationCore/documentation/specificationcore/)
- [Migration Guide](MIGRATION.md)
- [Contributing Guidelines](CONTRIBUTING.md)

## Performance

SpecificationCore is designed for high performance:

- **Specification Evaluation**: <1μs for simple predicates
- **Context Creation**: <1μs
- **Type Erasure Overhead**: <50ns
- **Thread-Safe**: All public APIs are concurrency-safe

## Testing

SpecificationCore maintains >90% test coverage with comprehensive unit tests, integration tests, and performance benchmarks.

Run tests:

```bash
swift test
```

Run tests with thread sanitizer:

```bash
swift test --sanitize=thread
```

## Contributing

Contributions are welcome! Please read our [Contributing Guidelines](CONTRIBUTING.md) first.

## License

SpecificationCore is released under the MIT License. See [LICENSE](LICENSE) for details.

## Acknowledgments

SpecificationCore is extracted from [SpecificationKit](https://github.com/yourusername/SpecificationKit) to provide a platform-independent foundation for specification-based systems in Swift.
