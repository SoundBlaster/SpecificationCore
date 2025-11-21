# ``SpecificationCore/Specification``

A protocol that evaluates whether a context satisfies certain conditions.

## Overview

The `Specification` protocol is the foundation of SpecificationCore, implementing the Specification Pattern to encapsulate business rules and conditions in a composable, testable manner. Specifications allow you to define complex business logic through small, focused components that can be combined using logical operators.

### Key Benefits

- **Composability**: Combine specifications using `.and()`, `.or()`, and `.not()` operators
- **Reusability**: Define specifications once, use them throughout your application
- **Testability**: Small, focused specifications are easy to unit test
- **Maintainability**: Business rules are explicit and self-documenting
- **Type Safety**: Generic associated type ensures compile-time correctness

### When to Use Specifications

Use the Specification pattern when you need to:
- Define reusable business rules that can be combined
- Separate business logic from domain objects
- Create flexible validation and filtering criteria
- Build complex eligibility or authorization checks
- Implement feature flags or A/B testing logic

## Quick Example

```swift
import SpecificationCore

struct User {
    let age: Int
    let isActive: Bool
    let subscriptionTier: String
}

// Define a simple specification
struct AdultUserSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.age >= 18
    }
}

// Use the specification
let spec = AdultUserSpec()
let user = User(age: 25, isActive: true, subscriptionTier: "premium")

if spec.isSatisfiedBy(user) {
    print("User is an adult")
}
```

## Composing Specifications

The real power of specifications comes from composition. Combine simple specifications to create complex business rules:

```swift
struct ActiveUserSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.isActive
    }
}

struct PremiumUserSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.subscriptionTier == "premium"
    }
}

// Combine specifications
let eligibleSpec = AdultUserSpec()
    .and(ActiveUserSpec())
    .and(PremiumUserSpec())

if eligibleSpec.isSatisfiedBy(user) {
    print("User is eligible for premium features")
}
```

## Using Logical Operators

SpecificationCore provides three logical operators for composition:

### AND Operator

Creates a specification satisfied when both specifications are satisfied:

```swift
let adultAndActive = AdultUserSpec().and(ActiveUserSpec())
// Satisfied only when user is BOTH adult AND active
```

### OR Operator

Creates a specification satisfied when either specification is satisfied:

```swift
struct TrialUserSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.subscriptionTier == "trial"
    }
}

let hasAccessSpec = PremiumUserSpec().or(TrialUserSpec())
// Satisfied when user is premium OR trial
```

### NOT Operator

Creates a specification that inverts the result:

```swift
let inactiveUserSpec = ActiveUserSpec().not()
// Satisfied when user is NOT active
```

## Operator Syntax

For more concise composition, use the operator overloads:

```swift
// Using method syntax
let spec1 = AdultUserSpec().and(ActiveUserSpec()).or(PremiumUserSpec())

// Using operator syntax
let spec2 = AdultUserSpec() && ActiveUserSpec() || PremiumUserSpec()

// Using NOT operator
let notAdult = !AdultUserSpec()
```

## Creating Custom Specifications

Implement the `Specification` protocol with a single method:

```swift
struct MinimumBalanceSpec: Specification {
    let minimumAmount: Decimal

    func isSatisfiedBy(_ account: BankAccount) -> Bool {
        account.balance >= minimumAmount
    }
}

// Use with different minimum values
let standardSpec = MinimumBalanceSpec(minimumAmount: 100)
let premiumSpec = MinimumBalanceSpec(minimumAmount: 1000)
```

## Using with Property Wrappers

Combine specifications with property wrappers for declarative evaluation:

```swift
import SpecificationCore

struct UserViewModel {
    let user: User

    @Satisfies(using: AdultUserSpec().and(ActiveUserSpec()))
    var canAccessContent: Bool

    init(user: User) {
        self.user = user
        _canAccessContent = Satisfies(
            using: AdultUserSpec().and(ActiveUserSpec()),
            with: user
        )
    }
}

let viewModel = UserViewModel(user: user)
if viewModel.canAccessContent {
    // Show restricted content
}
```

## Best Practices

### Keep Specifications Focused

Each specification should test one business rule:

```swift
// ✅ Good - focused specifications
struct IsAdultSpec: Specification { /* ... */ }
struct HasActiveSubscriptionSpec: Specification { /* ... */ }
let eligibleSpec = IsAdultSpec().and(HasActiveSubscriptionSpec())

// ❌ Avoid - mixed concerns
struct IsEligibleSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.age >= 18 && user.subscription.isActive && user.emailVerified
    }
}
```

### Make Specifications Stateless

Specifications should be pure functions without side effects:

```swift
// ✅ Good - stateless
struct AgeSpec: Specification {
    let minimumAge: Int

    func isSatisfiedBy(_ user: User) -> Bool {
        user.age >= minimumAge
    }
}

// ❌ Avoid - stateful with side effects
struct CountingSpec: Specification {
    var callCount = 0  // Mutable state

    mutating func isSatisfiedBy(_ user: User) -> Bool {
        callCount += 1  // Side effect
        return user.isActive
    }
}
```

### Use Type-Safe Contexts

Leverage Swift's type system for compile-time safety:

```swift
// Define specific context types
struct OrderContext {
    let totalAmount: Decimal
    let itemCount: Int
    let customerId: String
}

struct MinimumOrderSpec: Specification {
    let minimumAmount: Decimal

    func isSatisfiedBy(_ order: OrderContext) -> Bool {
        order.totalAmount >= minimumAmount
    }
}
```

## Performance Considerations

- **Lightweight Evaluation**: Keep `isSatisfiedBy(_:)` implementations fast, as they may be called frequently
- **Short-Circuit Evaluation**: AND and OR operations short-circuit for efficiency
- **Thread Safety**: Ensure specifications are thread-safe when used in concurrent contexts
- **Avoid Heavy Computation**: For expensive operations, consider caching or using ``AsyncSpecification``

## Topics

### Essential Protocol

- ``isSatisfiedBy(_:)``

### Logical Composition

- ``and(_:)``
- ``or(_:)``
- ``not()``

### Composite Types

- ``AndSpecification``
- ``OrSpecification``
- ``NotSpecification``

### Type Erasure

- ``AnySpecification``

### Related Protocols

- ``DecisionSpec``
- ``AsyncSpecification``

### Built-in Specifications

- ``PredicateSpec``
- ``MaxCountSpec``
- ``CooldownIntervalSpec``
- ``TimeSinceEventSpec``
- ``DateRangeSpec``
- ``DateComparisonSpec``

### Property Wrappers

- ``Satisfies``
- ``Decides``
- ``Maybe``

## See Also

- <doc:DecisionSpec>
- <doc:AsyncSpecification>
- <doc:SpecificationOperators>
- ``PredicateSpec``
