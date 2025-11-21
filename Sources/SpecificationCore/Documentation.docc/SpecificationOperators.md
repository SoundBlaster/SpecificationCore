# Specification Operators and Builders

Operators, functions, and builders for composing specifications with elegant syntax.

## Overview

SpecificationCore provides a rich set of operators, convenience functions, and builder patterns that make composing specifications more expressive and readable. These utilities complement the core ``Specification`` protocol with Swift-native operators and fluent interfaces.

### What's Included

- **Logical Operators**: `&&`, `||`, `!` for boolean composition
- **Convenience Functions**: `spec()`, `alwaysTrue()`, `alwaysFalse()` for quick creation
- **Builder Pattern**: ``SpecificationBuilder`` for fluent composition
- **Global Functions**: `build()` for starting builder chains

### When to Use These Utilities

Use specification operators and builders when you want to:
- Write more concise and readable composition code
- Use familiar Swift operators for logical operations
- Build specifications fluently with method chaining
- Create specifications from closures quickly
- Construct complex specifications step-by-step

## Quick Example

```swift
import SpecificationCore

struct User {
    let age: Int
    let isActive: Bool
    let isPremium: Bool
}

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

// Using operators
let eligibleSpec = AdultSpec() && ActiveSpec() || PremiumSpec()

// Using convenience functions
let customSpec = spec<User> { $0.age >= 21 }

// Using builder pattern
let builtSpec = build(AdultSpec())
    .and(ActiveSpec())
    .or(PremiumSpec())
    .build()
```

## Logical Operators

### AND Operator (&&)

Combines two specifications with AND logic:

```swift
let adultSpec = AdultSpec()
let activeSpec = ActiveSpec()

// Using method syntax
let combined1 = adultSpec.and(activeSpec)

// Using operator syntax (more concise)
let combined2 = adultSpec && activeSpec

// Both are equivalent
let user = User(age: 25, isActive: true, isPremium: false)
combined1.isSatisfiedBy(user)  // true
combined2.isSatisfiedBy(user)  // true
```

### OR Operator (||)

Combines two specifications with OR logic:

```swift
let premiumSpec = PremiumSpec()
let trialSpec = TrialSpec()

// Using method syntax
let hasAccess1 = premiumSpec.or(trialSpec)

// Using operator syntax
let hasAccess2 = premiumSpec || trialSpec

// Satisfied if user is premium OR trial
hasAccess2.isSatisfiedBy(user)
```

### NOT Operator (!)

Negates a specification:

```swift
let activeSpec = ActiveSpec()

// Using method syntax
let inactive1 = activeSpec.not()

// Using operator syntax (prefix)
let inactive2 = !activeSpec

// Satisfied when user is NOT active
inactive2.isSatisfiedBy(user)
```

### Operator Precedence

Operators follow standard Swift precedence rules:

```swift
// AND has higher precedence than OR
let spec1 = adultSpec && activeSpec || premiumSpec
// Equivalent to:
let spec2 = (adultSpec && activeSpec) || premiumSpec

// Use parentheses for clarity
let spec3 = adultSpec && (activeSpec || premiumSpec)

// NOT has highest precedence
let spec4 = !adultSpec && activeSpec
// Equivalent to:
let spec5 = (!adultSpec) && activeSpec
```

## Complex Composition

Combine operators for complex logic:

```swift
struct VerifiedSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.emailVerified
    }
}

struct BannedSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.isBanned
    }
}

// Complex eligibility: (adult AND active) OR premium, AND NOT banned
let eligibilitySpec =
    (AdultSpec() && ActiveSpec() || PremiumSpec()) &&
    !BannedSpec() &&
    VerifiedSpec()

if eligibilitySpec.isSatisfiedBy(user) {
    print("User is eligible")
}
```

## Convenience Functions

### spec() Function

Create specifications quickly from closures:

```swift
// Instead of creating a struct
struct EmailValidSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.email.contains("@")
    }
}

// Use spec() for inline creation
let emailValid = spec<User> { user in
    user.email.contains("@")
}

// Even more concise with shorthand
let emailValid2 = spec<User> { $0.email.contains("@") }

// Compose with other specs
let verifiedUser = spec<User> { $0.emailVerified } &&
                   spec<User> { $0.age >= 18 }
```

### alwaysTrue() Function

Create a specification that always returns true:

```swift
let always = alwaysTrue<User>()

always.isSatisfiedBy(anyUser)  // Always true

// Useful for conditional logic
let spec = isFeatureEnabled
    ? ActualSpec()
    : alwaysTrue<User>()
```

### alwaysFalse() Function

Create a specification that always returns false:

```swift
let never = alwaysFalse<User>()

never.isSatisfiedBy(anyUser)  // Always false

// Useful for disabling features
let spec = isMaintenanceMode
    ? alwaysFalse<User>()
    : NormalSpec()
```

## Builder Pattern

``SpecificationBuilder`` provides a fluent interface for step-by-step composition:

### Basic Builder Usage

```swift
let spec = build(AdultSpec())
    .and(ActiveSpec())
    .and(VerifiedSpec())
    .build()

let isEligible = spec.isSatisfiedBy(user)
```

### Starting with a Predicate

```swift
let spec = build<User> { $0.age >= 18 }
    .and(spec { $0.isActive })
    .and(spec { $0.emailVerified })
    .build()
```

### Complex Builder Chains

```swift
let eligibilitySpec = build(BaseEligibilitySpec())
    .and(AgeRequirementSpec())
    .and(LocationSpec())
    .or(PremiumOverrideSpec())  // Premium users bypass requirements
    .and(NotBannedSpec())       // But still can't be banned
    .build()
```

### Conditional Building

```swift
var builder = build(BaseSpec())

if requireAdult {
    builder = builder.and(AdultSpec())
}

if requireActive {
    builder = builder.and(ActiveSpec())
}

if premiumOnly {
    builder = builder.and(PremiumSpec())
}

let finalSpec = builder.build()
```

### Negation in Builder

```swift
let spec = build(ActiveSpec())
    .and(VerifiedSpec())
    .not()  // Negate the entire chain
    .build()

// Equivalent to: !(ActiveSpec() && VerifiedSpec())
```

## Combining Operators and Builders

Mix operators and builders for maximum flexibility:

```swift
// Start with operator composition
let baseSpec = AdultSpec() && ActiveSpec()

// Continue with builder
let fullSpec = build(baseSpec)
    .or(PremiumSpec())
    .and(VerifiedSpec())
    .build()

// Or use operators on built specs
let built = build(Spec1()).and(Spec2()).build()
let final = built && Spec3() || Spec4()
```

## Real-World Examples

### User Access Control

```swift
// Readable access control logic
let canAccessPremiumContent =
    (spec<User> { $0.subscriptionTier == "premium" } &&
     spec<User> { $0.subscriptionExpiry > Date() }) ||
    (spec<User> { $0.isAdmin }) &&
    !spec<User> { $0.isBanned }

if canAccessPremiumContent.isSatisfiedBy(user) {
    // Show premium content
}
```

### Feature Flag Evaluation

```swift
// Complex feature flag logic
let showNewUI = build<EvaluationContext> { ctx in
    ctx.flag(for: "new_ui_enabled") == true
}
.and(spec { ctx in
    ctx.counter(for: "login_count") ?? 0 >= 5
})
.or(spec { ctx in
    ctx.flag(for: "force_new_ui") == true
})
.build()

if showNewUI.isSatisfiedBy(context) {
    // Render new UI
}
```

### Form Validation

```swift
let isValidRegistration =
    spec<RegistrationForm> { $0.email.contains("@") } &&
    spec { $0.password.count >= 8 } &&
    spec { $0.agreedToTerms } &&
    (spec { $0.age >= 18 } || spec { $0.hasParentalConsent })

if isValidRegistration.isSatisfiedBy(form) {
    submitRegistration(form)
}
```

### E-Commerce Rules

```swift
let qualifiesForDiscount = build<Order> { order in
    order.totalAmount >= 100
}
.and(spec { $0.itemCount >= 3 })
.or(spec { $0.customerTier == "VIP" })
.or(spec { $0.isFirstPurchase })
.and(!spec { $0.alreadyDiscounted })
.build()

if qualifiesForDiscount.isSatisfiedBy(order) {
    applyDiscount(to: order)
}
```

## Functional Patterns

### Specification Pipelines

```swift
let pipeline = [
    spec<User> { $0.age >= 18 },
    spec<User> { $0.emailVerified },
    spec<User> { $0.isActive },
    spec<User> { !$0.isBanned }
]

// All must pass
let allPass = pipeline.allSatisfied()

// Any must pass
let anyPass = pipeline.anySatisfied()
```

### Specification Factories

```swift
func createValidation(for type: UserType) -> AnySpecification<User> {
    switch type {
    case .admin:
        return spec { $0.role == "admin" } &&
               spec { $0.emailVerified }

    case .moderator:
        return spec { $0.role == "moderator" } &&
               spec { $0.age >= 21 } &&
               spec { $0.backgroundCheckPassed }

    case .user:
        return spec { $0.emailVerified } &&
               !spec { $0.isBanned }
    }
}

let validation = createValidation(for: .admin)
```

### Higher-Order Specifications

```swift
func requireAll<T>(_ requirements: [AnySpecification<T>]) -> AnySpecification<T> {
    requirements.isEmpty
        ? alwaysTrue()
        : requirements.allSatisfied()
}

func requireAny<T>(_ options: [AnySpecification<T>]) -> AnySpecification<T> {
    options.isEmpty
        ? alwaysFalse()
        : options.anySatisfied()
}

// Use higher-order functions
let must = requireAll([
    spec<User> { $0.age >= 18 },
    spec<User> { $0.isActive }
])

let canBe = requireAny([
    spec<User> { $0.isPremium },
    spec<User> { $0.isAdmin }
])

let finalSpec = must && canBe
```

## Best Practices

### Use Operators for Readability

```swift
// ✅ Good - concise and readable
let spec = adultSpec && activeSpec || premiumSpec

// ❌ Verbose - harder to read
let spec = adultSpec.and(activeSpec).or(premiumSpec)
```

### Use Builders for Complex Logic

```swift
// ✅ Good - clear step-by-step construction
let spec = build(baseSpec)
    .and(requirement1)
    .and(requirement2)
    .or(override)
    .build()

// ❌ Harder to read - complex operator chain
let spec = baseSpec && requirement1 && requirement2 || override
```

### Name Intermediate Specifications

```swift
// ✅ Good - named intermediate specs
let hasValidSubscription = premiumSpec || trialSpec
let meetsAgeRequirement = adultSpec
let isEligible = hasValidSubscription && meetsAgeRequirement

// ❌ Avoid - unnamed complex chains
let spec = premiumSpec || trialSpec && adultSpec
```

### Use spec() for Simple Cases

```swift
// ✅ Good - inline for simple checks
let valid = spec<User> { $0.email.contains("@") }

// ❌ Overkill - creating a struct for simple predicate
struct EmailValidSpec: Specification { /* ... */ }
let valid = EmailValidSpec()
```

## Performance Considerations

- **Operator Overhead**: Operators have no performance overhead vs method calls
- **Builder Allocation**: Builders create intermediate objects; use for readability, not performance-critical paths
- **Inline Specs**: `spec()` function creates closures; consider reusable structs for frequently called specs
- **Short-Circuit Evaluation**: && and || operators short-circuit like standard Swift operators

## Topics

### Logical Operators

- ``&&(_:_:)`` (AND)
- ``||(_:_:)`` (OR)
- ``!(_:)`` (NOT)

### Convenience Functions

- ``spec(_:)``
- ``alwaysTrue()``
- ``alwaysFalse()``

### Builder Pattern

- ``SpecificationBuilder``

### Related Concepts

- ``Specification``
- ``AnySpecification``

## See Also

- <doc:Specification>
- ``AnySpecification``
- ``SpecificationBuilder``
