# ``SpecificationCore/DecisionSpec``

A protocol for specifications that return typed results beyond boolean values.

## Overview

The `DecisionSpec` protocol extends the Specification Pattern to support decision-making with typed payloads. While regular ``Specification`` protocols return boolean values, `DecisionSpec` allows you to return rich, typed results when a specification is satisfied.

### Key Benefits

- **Typed Results**: Return specific values (strings, enums, objects) instead of just `true`/`false`
- **Priority-Based Decisions**: Evaluate multiple specifications and return the first matching result
- **Type Safety**: Generic associated types ensure compile-time correctness
- **Flexibility**: Bridge boolean specifications to decision specs easily
- **Composability**: Works alongside regular specifications

### When to Use DecisionSpec

Use `DecisionSpec` when you need to:
- Make priority-based decisions with typed outcomes
- Map business rules to specific actions or values
- Implement feature flags that return configuration objects
- Create eligibility systems that provide reasons or results
- Build routing or dispatching logic based on conditions

## Quick Example

```swift
import SpecificationCore

struct User {
    let subscriptionTier: String
    let accountAge: Int
}

// Define a decision specification
struct DiscountDecisionSpec: DecisionSpec {
    func decide(_ user: User) -> String? {
        if user.subscriptionTier == "premium" {
            return "PREMIUM20"
        }
        if user.accountAge > 365 {
            return "LOYAL15"
        }
        return nil
    }
}

// Use the decision spec
let spec = DiscountDecisionSpec()
let user = User(subscriptionTier: "premium", accountAge: 200)

if let discountCode = spec.decide(user) {
    print("Apply discount: \(discountCode)")  // "PREMIUM20"
}
```

## Bridging Boolean Specifications

Convert any ``Specification`` to a ``DecisionSpec`` using the `returning(_:)` method:

```swift
struct PremiumUserSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.subscriptionTier == "premium"
    }
}

// Convert to DecisionSpec
let premiumDiscount = PremiumUserSpec().returning("PREMIUM20")

if let code = premiumDiscount.decide(user) {
    print("Discount code: \(code)")
}
```

## Priority-Based Decisions

Use ``FirstMatchSpec`` to evaluate multiple decision specs in priority order:

```swift
struct LoyaltyDecisionSpec: DecisionSpec {
    func decide(_ user: User) -> String? {
        user.accountAge > 365 ? "LOYAL15" : nil
    }
}

struct NewUserDecisionSpec: DecisionSpec {
    func decide(_ user: User) -> String? {
        user.accountAge < 30 ? "WELCOME10" : nil
    }
}

// Evaluate in order: premium → loyalty → new user → default
let discountSpec = FirstMatchSpec(
    specs: [
        DiscountDecisionSpec(),
        LoyaltyDecisionSpec(),
        NewUserDecisionSpec()
    ],
    defaultResult: "STANDARD5"
)

let discount = discountSpec.decide(user)  // Returns first match or default
```

## Type-Erased Decision Specs

Use ``AnyDecisionSpec`` to store decision specs of the same context and result types:

```swift
// Store different decision specs in an array
let rules: [AnyDecisionSpec<User, String>] = [
    AnyDecisionSpec(DiscountDecisionSpec()),
    AnyDecisionSpec(LoyaltyDecisionSpec()),
    AnyDecisionSpec { user in
        user.subscriptionTier == "trial" ? "TRIAL5" : nil
    }
]

// Evaluate all rules
for rule in rules {
    if let result = rule.decide(user) {
        print("Matched rule with result: \(result)")
        break
    }
}
```

## Creating Decision Specs from Predicates

Use ``PredicateDecisionSpec`` to create decision specs from simple predicates:

```swift
let seniorDiscount = PredicateDecisionSpec(
    predicate: { (user: User) in user.accountAge > 1000 },
    result: "SENIOR25"
)

if let code = seniorDiscount.decide(user) {
    print("Senior discount: \(code)")
}
```

## Using with Property Wrappers

Combine decision specs with the ``Decides`` property wrapper:

```swift
struct DiscountViewModel {
    let user: User

    @Decides([
        (PremiumUserSpec(), "PREMIUM20"),
        (LoyaltyUserSpec(), "LOYAL15"),
        (NewUserSpec(), "WELCOME10")
    ], or: "STANDARD5")
    var discountCode: String

    init(user: User) {
        self.user = user
        _discountCode = Decides(
            [
                (PremiumUserSpec(), "PREMIUM20"),
                (LoyaltyUserSpec(), "LOYAL15"),
                (NewUserSpec(), "WELCOME10")
            ],
            or: "STANDARD5",
            with: user
        )
    }
}

let viewModel = DiscountViewModel(user: user)
print("Discount: \(viewModel.discountCode)")  // Always has a value
```

## Optional Results with Maybe

For decisions that might not have a result, use ``Maybe``:

```swift
struct BonusViewModel {
    let user: User

    @Maybe([
        (PremiumUserSpec(), "Free shipping"),
        (LoyaltyUserSpec(), "Bonus points")
    ])
    var bonus: String?

    init(user: User) {
        self.user = user
        _bonus = Maybe(
            [
                (PremiumUserSpec(), "Free shipping"),
                (LoyaltyUserSpec(), "Bonus points")
            ],
            with: user
        )
    }
}

let viewModel = BonusViewModel(user: user)
if let bonus = viewModel.bonus {
    print("Bonus: \(bonus)")
}
```

## Advanced Patterns

### Enum-Based Results

Return enums for type-safe, exhaustive results:

```swift
enum AccessLevel {
    case admin
    case moderator
    case user
    case guest
}

struct AccessLevelDecisionSpec: DecisionSpec {
    func decide(_ user: User) -> AccessLevel? {
        switch user.subscriptionTier {
        case "admin": return .admin
        case "premium": return .moderator
        case "basic": return .user
        default: return .guest
        }
    }
}
```

### Structured Result Types

Return complex objects with metadata:

```swift
struct PricingDecision {
    let basePrice: Decimal
    let discountPercent: Double
    let discountReason: String
}

struct PricingDecisionSpec: DecisionSpec {
    func decide(_ user: User) -> PricingDecision? {
        if user.subscriptionTier == "premium" {
            return PricingDecision(
                basePrice: 99.99,
                discountPercent: 20,
                discountReason: "Premium subscriber"
            )
        }
        return nil
    }
}
```

### Combining with Context Providers

Use with ``EvaluationContext`` for dynamic decisions:

```swift
struct FeatureConfigDecisionSpec: DecisionSpec {
    func decide(_ context: EvaluationContext) -> FeatureConfig? {
        let isPremium = context.flag(for: "is_premium") == true
        let isEarlyAccess = context.flag(for: "early_access") == true

        if isPremium && isEarlyAccess {
            return FeatureConfig(tier: .premium, features: ["ai", "analytics", "priority"])
        } else if isPremium {
            return FeatureConfig(tier: .premium, features: ["ai", "analytics"])
        }
        return nil
    }
}
```

## Best Practices

### Return nil for Non-Matches

Always return `nil` when the decision spec doesn't match:

```swift
// ✅ Good
func decide(_ user: User) -> String? {
    guard user.subscriptionTier == "premium" else {
        return nil  // Explicit non-match
    }
    return "PREMIUM20"
}

// ❌ Avoid - throwing errors or returning empty values
func decide(_ user: User) -> String? {
    if user.subscriptionTier != "premium" {
        return ""  // Ambiguous - is this a match or not?
    }
    return "PREMIUM20"
}
```

### Use FirstMatchSpec for Priority Lists

When you have multiple decision specs, use ``FirstMatchSpec`` for clear priority ordering:

```swift
// ✅ Good - explicit priorities
let spec = FirstMatchSpec(
    specs: [highPrioritySpec, mediumPrioritySpec, lowPrioritySpec],
    defaultResult: defaultValue
)

// ❌ Avoid - complex nested conditionals
func decide(_ context: Context) -> Result? {
    if let high = highPrioritySpec.decide(context) { return high }
    if let medium = mediumPrioritySpec.decide(context) { return medium }
    if let low = lowPrioritySpec.decide(context) { return low }
    return defaultValue
}
```

### Provide Meaningful Results

Return values that are useful to callers:

```swift
// ✅ Good - informative results
enum RecommendationType {
    case upgrade(tier: String, savings: Decimal)
    case renew(discount: Double)
    case downgrade(reason: String)
}

// ❌ Avoid - opaque results
typealias Result = Int  // What does the number mean?
```

## Performance Considerations

- **Lazy Evaluation**: Decision specs only execute when `decide(_:)` is called
- **Short-Circuit Logic**: ``FirstMatchSpec`` stops after the first match
- **Result Caching**: Consider caching expensive decision results when appropriate
- **Nil Returns**: Returning `nil` is cheap - use it for non-matches

## Topics

### Essential Protocol

- ``decide(_:)``

### Bridging from Specifications

- ``Specification/returning(_:)``
- ``BooleanDecisionAdapter``

### Type Erasure

- ``AnyDecisionSpec``

### Predicate-Based Decisions

- ``PredicateDecisionSpec``

### Priority-Based Decisions

- ``FirstMatchSpec``

### Property Wrappers

- ``Decides``
- ``Maybe``

## See Also

- <doc:Specification>
- <doc:FirstMatchSpec>
- ``Decides``
- ``Maybe``
