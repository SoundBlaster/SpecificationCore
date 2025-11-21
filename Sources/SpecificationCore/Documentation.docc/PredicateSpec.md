# ``SpecificationCore/PredicateSpec``

A specification that accepts a closure for arbitrary logic.

## Overview

`PredicateSpec` provides maximum flexibility for custom business rules that don't fit into standard specification patterns. It allows you to create specifications from closures, KeyPath expressions, or use pre-built factory methods for common scenarios.

### Key Benefits

- **Flexible Creation**: Create specs from closures, predicates, or KeyPath expressions
- **Type Safety**: Strongly-typed with generic context parameter
- **Descriptive**: Optional description property for debugging and logging
- **Composable**: Supports composition with other PredicateSpecs
- **EvaluationContext Helpers**: Specialized methods for context-based specs

### When to Use PredicateSpec

Use `PredicateSpec` when you need to:
- Create quick, inline specifications without defining new types
- Prototype specifications before extracting to dedicated types
- Implement simple one-off business rules
- Use KeyPath-based property checks
- Create context-aware predicates for feature flags and counters

## Quick Example

```swift
import SpecificationCore

struct User {
    let age: Int
    let email: String
    let isActive: Bool
}

// Create from closure
let adultSpec = PredicateSpec<User>(description: "Is adult") { user in
    user.age >= 18
}

// Create from KeyPath
let activeSpec = PredicateSpec.keyPath(\.isActive, description: "Is active")

// Create with property comparison
let premiumSpec = PredicateSpec.keyPath(
    \.subscriptionTier,
    equals: "premium",
    description: "Is premium user"
)

// Use like any specification
if adultSpec.isSatisfiedBy(user) {
    print("User is an adult")
}
```

## Creating from Closures

The most flexible way to create predicate specifications:

```swift
// Simple boolean predicate
let emailValid = PredicateSpec<User>(description: "Valid email") { user in
    user.email.contains("@") && user.email.contains(".")
}

// Multi-line logic
let eligibleForDiscount = PredicateSpec<User>(
    description: "Eligible for discount"
) { user in
    guard user.isActive else { return false }
    let daysSinceRegistration = user.daysSinceRegistration
    return daysSinceRegistration > 30 && user.purchaseCount < 5
}

// No description (optional)
let quickCheck = PredicateSpec<User> { $0.age >= 21 }
```

## KeyPath-Based Specifications

Create specifications from Swift KeyPaths:

### Boolean KeyPath

```swift
struct Account {
    let isVerified: Bool
    let isPremium: Bool
}

// Check boolean property
let verifiedSpec = PredicateSpec.keyPath(\.isVerified)
let premiumSpec = PredicateSpec.keyPath(\.isPremium, description: "Premium account")

let account = Account(isVerified: true, isPremium: false)
verifiedSpec.isSatisfiedBy(account)  // true
```

### Equality Checks

```swift
struct Order {
    let status: String
    let priority: Int
}

// Check for specific value
let completedSpec = PredicateSpec.keyPath(
    \.status,
    equals: "completed"
)

let highPrioritySpec = PredicateSpec.keyPath(
    \.priority,
    equals: 1,
    description: "High priority"
)

let order = Order(status: "completed", priority: 1)
completedSpec.isSatisfiedBy(order)  // true
```

### Comparison Operations

```swift
struct Product {
    let price: Decimal
    let stock: Int
    let rating: Double
}

// Greater than
let expensiveSpec = PredicateSpec.keyPath(
    \.price,
    greaterThan: 100.0
)

// Less than
let lowStockSpec = PredicateSpec.keyPath(
    \.stock,
    lessThan: 10
)

// Range check
let ratedSpec = PredicateSpec.keyPath(
    \.rating,
    in: 4.0...5.0,
    description: "Highly rated"
)
```

## EvaluationContext Specifications

Specialized factory methods for working with ``EvaluationContext``:

### Flag Checking

```swift
// Check if flag is true
let premiumEnabled = PredicateSpec.flag("premium_features")

// Check for specific value
let betaDisabled = PredicateSpec.flag("beta_mode", equals: false)

// With description
let analyticsSpec = PredicateSpec.flag(
    "analytics_enabled",
    equals: true,
    description: "Analytics enabled"
)

let context = EvaluationContext(flags: ["premium_features": true])
premiumEnabled.isSatisfiedBy(context)  // true
```

### Counter Checking

```swift
// Check counter value with comparison
let withinLimit = PredicateSpec.counter(
    "api_calls",
    .lessThan,
    100
)

let exactCount = PredicateSpec.counter(
    "login_attempts",
    .equal,
    3,
    description: "Exactly 3 attempts"
)

let highUsage = PredicateSpec.counter(
    "daily_requests",
    .greaterThanOrEqual,
    1000
)

// Available comparisons: .lessThan, .lessThanOrEqual, .equal,
// .greaterThanOrEqual, .greaterThan, .notEqual
```

### Event Checking

```swift
// Check if event exists
let hasLoggedIn = PredicateSpec.eventExists("last_login")

let hasCompletedTutorial = PredicateSpec.eventExists(
    "tutorial_completed",
    description: "Tutorial completed"
)

let context = EvaluationContext(
    events: ["last_login": Date()]
)
hasLoggedIn.isSatisfiedBy(context)  // true
```

### Time-Based Specifications

```swift
// Check time since launch
let runningSufficiently = PredicateSpec.timeSinceLaunch(
    greaterThan: 60  // 1 minute
)

// Check current hour
let businessHours = PredicateSpec.currentHour(in: 9...17)

let lateNight = PredicateSpec.currentHour(
    in: 22...6,  // Wraps around midnight
    description: "Late night hours"
)

// Weekday/weekend checks
let isWeekday = PredicateSpec.isWeekday()
let isWeekend = PredicateSpec.isWeekend(description: "Weekend")
```

## Constant Specifications

Pre-built specifications for edge cases:

```swift
// Always returns true
let alwaysTrue = PredicateSpec<User>.alwaysTrue()

// Always returns false
let alwaysFalse = PredicateSpec<User>.alwaysFalse()

// Useful for conditional logic
let spec = isMaintenanceMode
    ? PredicateSpec<User>.alwaysFalse()
    : ActualEligibilitySpec()
```

## Composition

Combine PredicateSpecs with logical operators:

### AND Composition

```swift
let adult = PredicateSpec<User> { $0.age >= 18 }
let active = PredicateSpec<User> { $0.isActive }

// Combine with AND
let eligible = adult.and(active)

// Description is combined
print(eligible.description)  // "Is adult AND Is active"
```

### OR Composition

```swift
let premium = PredicateSpec<User> { $0.tier == "premium" }
let trial = PredicateSpec<User> { $0.tier == "trial" }

// Combine with OR
let hasAccess = premium.or(trial)
```

### NOT Composition

```swift
let banned = PredicateSpec<User> { $0.isBanned }

// Negate
let notBanned = banned.not()

print(notBanned.description)  // "NOT (Is banned)"
```

### Complex Composition

```swift
let adultSpec = PredicateSpec<User>(description: "Adult") { $0.age >= 18 }
let activeSpec = PredicateSpec<User>(description: "Active") { $0.isActive }
let bannedSpec = PredicateSpec<User>(description: "Banned") { $0.isBanned }

// (Adult AND Active) AND NOT Banned
let eligible = adultSpec
    .and(activeSpec)
    .and(bannedSpec.not())
```

## Contramap Transformation

Transform the input type of a predicate:

```swift
struct User {
    let profile: UserProfile
}

struct UserProfile {
    let age: Int
}

// Spec for UserProfile
let adultProfileSpec = PredicateSpec<UserProfile> { $0.age >= 18 }

// Transform to work with User
let adultUserSpec = adultProfileSpec.contramap { (user: User) in
    user.profile
}

let user = User(profile: UserProfile(age: 25))
adultUserSpec.isSatisfiedBy(user)  // true
```

## Collection Extensions

Create specifications from collections of specifications:

```swift
let validations: [PredicateSpec<User>] = [
    PredicateSpec { $0.email.contains("@") },
    PredicateSpec { $0.age >= 18 },
    PredicateSpec { $0.isActive }
]

// All must be satisfied (AND)
let allValid = validations.allSatisfiedPredicate()

// Any can be satisfied (OR)
let anyValid = validations.anySatisfiedPredicate()
```

## Debugging with Descriptions

Use descriptions for logging and debugging:

```swift
let spec = PredicateSpec<User>(description: "Premium user check") { user in
    user.subscriptionTier == "premium" && user.isActive
}

// Access description
print("Evaluating: \(spec.description ?? "unnamed spec")")

// Useful in logs
func evaluate(user: User, with spec: PredicateSpec<User>) -> Bool {
    let result = spec.isSatisfiedBy(user)
    print("[\(spec.description ?? "spec")] = \(result)")
    return result
}
```

## Real-World Examples

### Form Validation

```swift
struct RegistrationForm {
    let email: String
    let password: String
    let age: Int
    let agreedToTerms: Bool
}

let validEmail = PredicateSpec<RegistrationForm>(
    description: "Valid email"
) { form in
    let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
    return NSPredicate(format: "SELF MATCHES %@", emailRegex)
        .evaluate(with: form.email)
}

let strongPassword = PredicateSpec<RegistrationForm>(
    description: "Strong password"
) { form in
    form.password.count >= 8 &&
    form.password.rangeOfCharacter(from: .uppercaseLetters) != nil &&
    form.password.rangeOfCharacter(from: .decimalDigits) != nil
}

let legalAge = PredicateSpec.keyPath(
    \RegistrationForm.age,
    greaterThanOrEqual: 18,
    description: "Legal age"
)

let termsAccepted = PredicateSpec.keyPath(
    \.agreedToTerms,
    description: "Terms accepted"
)

// Combine all validations
let formValid = validEmail
    .and(strongPassword)
    .and(legalAge)
    .and(termsAccepted)
```

### Feature Access Control

```swift
// Context-based feature access
let canAccessPremiumFeatures = PredicateSpec<EvaluationContext>(
    description: "Premium feature access"
) { context in
    let isPremium = context.flag(for: "is_premium")
    let withinLimit = context.counter(for: "monthly_usage") < 1000
    let notOnCooldown = context.timeSinceEvent("last_feature_use")
        .map { $0 > 3600 } ?? true

    return isPremium && withinLimit && notOnCooldown
}
```

### Business Hours Check

```swift
let isDuringBusinessHours = PredicateSpec<EvaluationContext>(
    description: "Business hours"
) { context in
    let calendar = context.calendar
    let components = calendar.dateComponents(
        [.hour, .weekday],
        from: context.currentDate
    )

    guard let hour = components.hour,
          let weekday = components.weekday else {
        return false
    }

    let isWeekday = (2...6).contains(weekday)  // Mon-Fri
    let isBusinessHours = (9...17).contains(hour)  // 9 AM - 5 PM

    return isWeekday && isBusinessHours
}
```

## Best Practices

### Provide Descriptions

```swift
// ✅ Good - descriptive for debugging
let spec = PredicateSpec<User>(description: "Active premium user") { user in
    user.isActive && user.tier == "premium"
}

// ❌ Less useful - no description
let spec = PredicateSpec<User> { user in
    user.isActive && user.tier == "premium"
}
```

### Keep Predicates Focused

```swift
// ✅ Good - single responsibility
let adultSpec = PredicateSpec<User>(description: "Adult") { $0.age >= 18 }
let activeSpec = PredicateSpec<User>(description: "Active") { $0.isActive }
let eligible = adultSpec.and(activeSpec)

// ❌ Avoid - mixed concerns in one predicate
let spec = PredicateSpec<User> { user in
    user.age >= 18 && user.isActive && user.email.contains("@")
}
```

### Use KeyPath Methods When Possible

```swift
// ✅ Good - concise with KeyPath
let activeSpec = PredicateSpec.keyPath(\.isActive)

// ❌ Verbose - unnecessary closure
let activeSpec = PredicateSpec<User> { user in
    user.isActive
}
```

### Extract Complex Logic

```swift
// ✅ Good - extract to named function
func isEligibleForRefund(_ order: Order) -> Bool {
    let daysSincePurchase = Date().timeIntervalSince(order.purchaseDate) / 86400
    return daysSincePurchase <= 30 && !order.isRefunded
}

let refundEligible = PredicateSpec<Order>(
    description: "Refund eligible",
    isEligibleForRefund
)

// ❌ Harder to read - complex inline logic
let refundEligible = PredicateSpec<Order> { order in
    let daysSincePurchase = Date().timeIntervalSince(order.purchaseDate) / 86400
    return daysSincePurchase <= 30 && !order.isRefunded
}
```

## Performance Considerations

- **Closure Overhead**: Minimal overhead; closures are stored and called directly
- **KeyPath Performance**: KeyPath access is optimized by Swift runtime
- **Description Storage**: Optional string has minimal memory impact
- **Composition**: Each composition creates a new PredicateSpec; efficient for short chains
- **Collection Methods**: `allSatisfiedPredicate()` short-circuits on first failure

## Topics

### Creating Specifications

- ``init(description:_:)``

### Constant Specifications

- ``alwaysTrue()``
- ``alwaysFalse()``

### KeyPath-Based Creation

- ``keyPath(_:description:)`` (Boolean)
- ``keyPath(_:equals:description:)`` (Equatable)
- ``keyPath(_:greaterThan:description:)``
- ``keyPath(_:lessThan:description:)``
- ``keyPath(_:in:description:)`` (Range)

### EvaluationContext Helpers

- ``flag(_:equals:description:)``
- ``counter(_:_:_:description:)``
- ``eventExists(_:description:)``
- ``timeSinceLaunch(greaterThan:description:)``
- ``currentHour(in:description:)``
- ``isWeekday(description:)``
- ``isWeekend(description:)``

### Composition

- ``and(_:)``
- ``or(_:)``
- ``not()``
- ``contramap(_:)``

### Properties

- ``description``

### Supporting Types

- ``CounterComparison``

## See Also

- <doc:Specification>
- <doc:EvaluationContext>
