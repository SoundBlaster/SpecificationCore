# ``SpecificationCore/AnySpecification``

A type-erased wrapper for specifications with performance optimizations.

## Overview

`AnySpecification` is a type-erased wrapper that allows you to store specifications of different concrete types in the same collection or use them in contexts where the specific type isn't known at compile time. It's optimized for performance with specialized storage strategies and compiler optimizations.

### Key Benefits

- **Type Erasure**: Store different specification types together
- **Performance Optimized**: Specialized storage and inlinable methods
- **Flexible Creation**: Create from specifications or closures
- **Constant Optimization**: Special handling for always-true/always-false specs
- **Collection Utilities**: Combine multiple specifications easily

### When to Use AnySpecification

Use `AnySpecification` when you need to:
- Store specifications in collections or arrays
- Return specifications from functions with different concrete types
- Create specifications dynamically at runtime
- Build flexible specification factories
- Work with specifications through protocols

## Quick Example

```swift
import SpecificationCore

struct User {
    let age: Int
    let isActive: Bool
}

// Create from a concrete specification
struct AdultSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.age >= 18
    }
}

let anySpec = AnySpecification(AdultSpec())
let isAdult = anySpec.isSatisfiedBy(user)

// Create from a closure
let activeSpec = AnySpecification<User> { user in
    user.isActive
}

let isActive = activeSpec.isSatisfiedBy(user)
```

## Storing Specifications in Collections

Type erasure allows heterogeneous specification collections:

```swift
struct AdultSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.age >= 18
    }
}

struct ActiveSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.isActive
    }
}

// Store different specification types together
let rules: [AnySpecification<User>] = [
    AnySpecification(AdultSpec()),
    AnySpecification(ActiveSpec()),
    AnySpecification { user in user.age < 65 },
    AnySpecification { user in user.email.contains("@") }
]

// Evaluate all rules
let passesAll = rules.allSatisfy { spec in
    spec.isSatisfiedBy(user)
}
```

## Creating from Closures

Create specifications directly from predicates:

```swift
// Simple closure-based specification
let emailValid = AnySpecification<User> { user in
    user.email.contains("@") && user.email.contains(".")
}

// Complex closure with multiple conditions
let eligibleUser = AnySpecification<User> { user in
    user.age >= 18 &&
    user.isActive &&
    user.emailVerified &&
    !user.isBanned
}

// Use like any other specification
if eligibleUser.isSatisfiedBy(user) {
    print("User is eligible")
}
```

## Constant Specifications

Use optimized constant specifications for always-true or always-false cases:

```swift
// Always-true specification
let alwaysTrue = AnySpecification<User>.always

// Always-false specification
let alwaysFalse = AnySpecification<User>.never

// Optimized constant functions
let trueSpec = AnySpecification<User>.constantTrue()
let falseSpec = AnySpecification<User>.constantFalse()

// Use in conditional logic
let spec = featureEnabled
    ? AnySpecification(FeatureSpec())
    : AnySpecification<User>.never
```

## Collection Extensions

Combine multiple specifications from collections:

### All Satisfied (AND)

Create a specification that requires all specs to be satisfied:

```swift
let validationRules = [
    AnySpecification(EmailValidSpec()),
    AnySpecification(PasswordStrongSpec()),
    AnySpecification(AgeRequirementSpec())
]

// All validations must pass
let allValid = validationRules.allSatisfied()

if allValid.isSatisfiedBy(user) {
    print("All validations passed")
}
```

### Any Satisfied (OR)

Create a specification satisfied when any spec matches:

```swift
let discountEligibility = [
    AnySpecification(PremiumMemberSpec()),
    AnySpecification(FirstTimeBuyerSpec()),
    AnySpecification(HolidayPromoSpec())
]

// Any condition grants discount
let getsDiscount = discountEligibility.anySatisfied()

if getsDiscount.isSatisfiedBy(user) {
    print("Discount applied")
}
```

## Dynamic Specification Factory

Build specifications dynamically based on configuration:

```swift
struct SpecificationFactory {
    static func create(for rules: [String: Any]) -> AnySpecification<User> {
        var specs: [AnySpecification<User>] = []

        if let minAge = rules["minAge"] as? Int {
            specs.append(AnySpecification { user in user.age >= minAge })
        }

        if let requiredRole = rules["role"] as? String {
            specs.append(AnySpecification { user in user.role == requiredRole })
        }

        if let mustBeActive = rules["active"] as? Bool, mustBeActive {
            specs.append(AnySpecification { user in user.isActive })
        }

        // Combine all specs with AND logic
        return specs.isEmpty
            ? .always
            : specs.allSatisfied()
    }
}

// Use factory
let config = ["minAge": 18, "active": true, "role": "member"]
let spec = SpecificationFactory.create(for: config)
let passes = spec.isSatisfiedBy(user)
```

## Wrapping Complex Specifications

Simplify complex specification hierarchies:

```swift
// Complex nested specification
let complexSpec = AdultSpec()
    .and(ActiveSpec())
    .or(PremiumSpec())
    .and(VerifiedSpec().not())

// Wrap in AnySpecification for simpler type
let wrapped = AnySpecification(complexSpec)

// Can now be stored, returned, or passed around easily
func getEligibilitySpec() -> AnySpecification<User> {
    wrapped  // Simpler return type
}
```

## Helper Specification Types

`AnySpecification` provides helper types for constants:

### AlwaysTrueSpec

```swift
let alwaysTrue = AlwaysTrueSpec<User>()
alwaysTrue.isSatisfiedBy(anyUser)  // Always returns true

// Wrapped automatically
let wrapped = AnySpecification(AlwaysTrueSpec<User>())
// Uses optimized .constantTrue storage
```

### AlwaysFalseSpec

```swift
let alwaysFalse = AlwaysFalseSpec<User>()
alwaysFalse.isSatisfiedBy(anyUser)  // Always returns false

// Wrapped automatically
let wrapped = AnySpecification(AlwaysFalseSpec<User>())
// Uses optimized .constantFalse storage
```

## Composition with Type Erasure

Combine type-erased specifications using composition operators:

```swift
let spec1 = AnySpecification<User> { $0.age >= 18 }
let spec2 = AnySpecification<User> { $0.isActive }

// Compose with operators
let combined = spec1.and(spec2)  // Returns AndSpecification

// Wrap result back in AnySpecification
let erased = AnySpecification(combined)

// Or chain directly
let chained = AnySpecification<User> { $0.age >= 18 }
    .and(AnySpecification { $0.isActive })
    .or(AnySpecification { $0.isPremium })
```

## Convenience Function

Use the global `spec()` function for concise creation:

```swift
// Instead of:
let verbose = AnySpecification<User> { user in user.isActive }

// Use:
let concise = spec<User> { $0.isActive }

// Compose easily
let combined = spec<User> { $0.age >= 18 }
    .and(spec { $0.isActive })
```

## Performance Optimizations

`AnySpecification` includes several performance optimizations:

### Inlinable Methods

All critical methods are marked `@inlinable` for cross-module optimization:

```swift
// These methods can be inlined by the compiler
public func isSatisfiedBy(_ candidate: T) -> Bool { ... }
public init<S: Specification>(_ specification: S) where S.T == T { ... }
```

### Specialized Storage

Different storage strategies based on specification type:

- `.constantTrue` - Optimized for always-true specs
- `.constantFalse` - Optimized for always-false specs
- `.predicate` - Direct closure storage
- `.specification` - Wrapped specification

### Optimized Collection Methods

Collection extensions optimize for common cases:

```swift
let specs = [spec1, spec2, spec3]

// Optimizes for empty collections and single elements
let all = specs.allSatisfied()

// Returns .constantTrue() for empty
// Returns wrapped first element for single item
// Returns combined spec for multiple items
```

## Best Practices

### Use for Heterogeneous Collections

```swift
// ✅ Good - store different spec types
let rules: [AnySpecification<User>] = [
    AnySpecification(ConcreteSpec1()),
    AnySpecification(ConcreteSpec2()),
    AnySpecification { /* closure */ }
]

// ❌ Avoid - lose type information unnecessarily
let spec: AnySpecification<User> = AnySpecification(ConcreteSpec())
// Better to keep ConcreteSpec type if not storing in collection
```

### Prefer Concrete Types When Possible

```swift
// ✅ Good - use concrete type
func createSpec() -> AdultSpec {
    AdultSpec(minimumAge: 18)
}

// ❌ Avoid - unnecessary type erasure
func createSpec() -> AnySpecification<User> {
    AnySpecification(AdultSpec(minimumAge: 18))
}
```

### Use Constant Specs Appropriately

```swift
// ✅ Good - use constants for always-true/false
let spec = isFeatureEnabled
    ? AnySpecification(FeatureSpec())
    : .never

// ❌ Avoid - creating unnecessary closures
let spec = isFeatureEnabled
    ? AnySpecification(FeatureSpec())
    : AnySpecification { _ in false }
```

## Common Patterns

### Guard Pattern

```swift
func validateUser(_ user: User) -> Bool {
    let validations: [AnySpecification<User>] = [
        spec { $0.email.contains("@") },
        spec { $0.age >= 18 },
        spec { $0.isActive }
    ]

    return validations.allSatisfied().isSatisfiedBy(user)
}
```

### Factory Pattern

```swift
enum UserType {
    case admin, moderator, user

    var spec: AnySpecification<User> {
        switch self {
        case .admin:
            return spec { $0.role == "admin" }
        case .moderator:
            return spec { $0.role == "moderator" || $0.role == "admin" }
        case .user:
            return .always
        }
    }
}
```

### Builder Pattern

```swift
struct SpecBuilder<T> {
    private var specs: [AnySpecification<T>] = []

    mutating func add(_ spec: AnySpecification<T>) {
        specs.append(spec)
    }

    func build() -> AnySpecification<T> {
        specs.allSatisfied()
    }
}

var builder = SpecBuilder<User>()
builder.add(spec { $0.age >= 18 })
builder.add(spec { $0.isActive })
let combined = builder.build()
```

## Topics

### Creating Type-Erased Specs

- ``init(_:)-swift.init`` (from Specification)
- ``init(_:)-swift.init.1`` (from closure)

### Constant Specifications

- ``always``
- ``never``
- ``constantTrue()``
- ``constantFalse()``

### Collection Extensions

- ``allSatisfied()``
- ``anySatisfied()``

### Helper Types

- ``AlwaysTrueSpec``
- ``AlwaysFalseSpec``

### Global Functions

- ``spec(_:)``
- ``alwaysTrue()``
- ``alwaysFalse()``

### Related Types

- ``Specification``
- ``AnyAsyncSpecification``
- ``AnyDecisionSpec``

## See Also

- <doc:Specification>
- ``AnyAsyncSpecification``
- ``AnyDecisionSpec``
