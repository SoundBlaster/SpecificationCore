# ``SpecificationCore/FirstMatchSpec``

A decision specification that evaluates specifications in priority order and returns the result of the first match.

## Overview

`FirstMatchSpec` implements a priority-based decision system where specifications are evaluated in order until one is satisfied. This is essential for tiered business rules, routing decisions, discount calculations, and any scenario requiring selection from a prioritized list of options.

### Key Benefits

- **Priority-Based**: Evaluates specifications in defined order
- **First Match Wins**: Returns immediately upon first satisfaction
- **Type-Safe Results**: Generic result type ensures compile-time correctness
- **Builder Pattern**: Fluent interface for constructing decision chains
- **Metadata Support**: Optional tracking of which rule matched

### When to Use FirstMatchSpec

Use `FirstMatchSpec` when you need to:
- Implement tiered pricing or discount systems
- Route users to different experiences based on criteria
- Select the first applicable rule from multiple options
- Make priority-based decisions with fallback values
- Implement feature experiment assignments

## Quick Example

```swift
import SpecificationCore

struct User {
    let tier: String
    let daysSinceRegistration: Int
    let isFirstPurchase: Bool
}

// Define discount tiers in priority order
let discountSpec = FirstMatchSpec<User, Double>([
    (PremiumMemberSpec(), 0.20),      // 20% for premium
    (LoyalCustomerSpec(), 0.15),      // 15% for loyal
    (FirstTimeBuyerSpec(), 0.10),     // 10% for first-time
    (RegularUserSpec(), 0.05)         // 5% for everyone else
])

// Use with property wrapper
@Decides(using: discountSpec, or: 0.0)
var discountRate: Double

print("Discount: \(discountRate)")  // e.g., 0.20 for premium user
```

## Creating FirstMatchSpec

### From Tuples

```swift
// Create with specification-result pairs
let routingSpec = FirstMatchSpec<User, String>([
    (PremiumUserSpec(), "premium_dashboard"),
    (BetaUserSpec(), "beta_dashboard"),
    (NewUserSpec(), "onboarding_dashboard")
])

if let route = routingSpec.decide(user) {
    navigateTo(route)
}
```

### With Fallback

```swift
// Ensure a result is always returned
let themeSpec = FirstMatchSpec.withFallback([
    (DarkModePreferenceSpec(), "dark"),
    (HighContrastSpec(), "high_contrast")
], fallback: "light")  // Default theme

let theme = themeSpec.decide(context)  // Never nil
```

### Using Builder Pattern

```swift
let contentSpec = FirstMatchSpec<User, String>.builder()
    .add(SubscriberSpec(), result: "premium_content")
    .add(TrialUserSpec(), result: "trial_content")
    .add(NewUserSpec(), result: "welcome_content")
    .fallback("default_content")
    .build()

let content = contentSpec.decide(user) ?? "error"
```

## Priority-Based Decisions

Specifications are evaluated in array order:

```swift
// High priority first, low priority last
let supportTierSpec = FirstMatchSpec<User, String>([
    (EnterpriseCustomerSpec(), "priority_support"),    // Checked first
    (PremiumSubscriberSpec(), "premium_support"),      // Checked second
    (ActiveUserSpec(), "standard_support"),            // Checked third
    (RegisteredUserSpec(), "basic_support")            // Checked last
])

// Returns first match
let tier = supportTierSpec.decide(user)
```

## Using with Property Wrappers

### Decides Wrapper

For non-optional results with fallback:

```swift
struct PricingViewModel {
    let user: User

    @Decides([
        (PremiumUserSpec(), 9.99),
        (StudentUserSpec(), 4.99),
        (TrialUserSpec(), 0.00)
    ], or: 14.99)  // Regular price
    var monthlyPrice: Double

    init(user: User) {
        self.user = user
        _monthlyPrice = Decides(
            [
                (PremiumUserSpec(), 9.99),
                (StudentUserSpec(), 4.99),
                (TrialUserSpec(), 0.00)
            ],
            or: 14.99,
            with: user
        )
    }
}
```

### Maybe Wrapper

For optional results without fallback:

```swift
struct BonusViewModel {
    let user: User

    @Maybe([
        (LoyaltyMemberSpec(), "loyalty_points"),
        (ReferralUserSpec(), "referral_bonus")
    ])
    var availableBonus: String?

    init(user: User) {
        self.user = user
        _availableBonus = Maybe(
            [
                (LoyaltyMemberSpec(), "loyalty_points"),
                (ReferralUserSpec(), "referral_bonus")
            ],
            with: user
        )
    }
}

if let bonus = viewModel.availableBonus {
    print("Bonus available: \(bonus)")
}
```

## Builder Pattern

Construct decision specs fluently:

### Basic Building

```swift
let featureSpec = FirstMatchSpec<EvaluationContext, String>.builder()
    .add(FeatureFlagSpec(flagKey: "new_feature"), result: "new_ui")
    .add(BetaTesterSpec(), result: "beta_ui")
    .build()
```

### With Predicates

```swift
let experimentSpec = FirstMatchSpec<User, String>.builder()
    .add({ $0.tier == "enterprise" }, result: "variant_a")
    .add({ $0.daysSinceRegistration < 30 }, result: "variant_b")
    .add({ $0.age >= 65 }, result: "variant_c")
    .fallback("control")
    .build()
```

### With Metadata Tracking

```swift
let spec = FirstMatchSpec<User, String>.builder()
    .add(PremiumSpec(), result: "premium")
    .add(TrialSpec(), result: "trial")
    .withMetadata(true)
    .build()

if let (result, index) = spec.decideWithMetadata(user) {
    print("Matched rule #\(index): \(result)")
}
```

## Metadata and Debugging

Track which specification matched:

```swift
let ruleSpec = FirstMatchSpec<User, String>([
    (Rule1Spec(), "action_1"),
    (Rule2Spec(), "action_2"),
    (Rule3Spec(), "action_3")
], includeMetadata: true)

// Get result with index
if let (action, index) = ruleSpec.decideWithMetadata(user) {
    print("Matched rule at index \(index): \(action)")
    // Matched rule at index 1: action_2
}
```

## Real-World Examples

### Discount Calculation

```swift
struct Order {
    let total: Decimal
    let itemCount: Int
    let customerTier: String
}

let discountSpec = FirstMatchSpec<Order, Decimal>.builder()
    .add({ $0.total >= 500 }, result: 100.0)  // $100 off orders over $500
    .add({ $0.itemCount >= 10 }, result: 50.0)  // $50 off 10+ items
    .add({ $0.customerTier == "VIP" }, result: 25.0)  // $25 VIP discount
    .fallback(0.0)  // No discount
    .build()

let discount = discountSpec.decide(order) ?? 0.0
```

### Content Routing

```swift
let routingSpec = FirstMatchSpec<EvaluationContext, String>.builder()
    .add(
        PredicateSpec.flag("maintenance_mode"),
        result: "maintenance_page"
    )
    .add(
        PredicateSpec.counter("onboarding_completed", .equal, 0),
        result: "onboarding_flow"
    )
    .add(
        PredicateSpec.flag("premium_user"),
        result: "premium_dashboard"
    )
    .fallback("standard_dashboard")
    .build()

let route = routingSpec.decide(context) ?? "error_page"
navigateTo(route)
```

### Feature Experiment Assignment

```swift
enum ExperimentVariant: String {
    case control = "control"
    case variantA = "variant_a"
    case variantB = "variant_b"
    case variantC = "variant_c"
}

let experimentSpec = FirstMatchSpec<User, ExperimentVariant>.builder()
    .add(
        BetaTesterSpec(),
        result: .variantA
    )
    .add(
        { user in user.id.hashValue % 3 == 0 },
        result: .variantB
    )
    .add(
        { user in user.id.hashValue % 3 == 1 },
        result: .variantC
    )
    .fallback(.control)
    .build()

let variant = experimentSpec.decide(user) ?? .control
```

### Notification Priority

```swift
enum NotificationPriority {
    case critical
    case high
    case normal
    case low
}

let prioritySpec = FirstMatchSpec<Notification, NotificationPriority>([
    (SecurityAlertSpec(), .critical),
    (PaymentDueSpec(), .high),
    (MessageReceivedSpec(), .normal),
    (NewsletterSpec(), .low)
])

if let priority = prioritySpec.decide(notification) {
    sendNotification(notification, priority: priority)
}
```

### Pricing Tier Selection

```swift
struct PricingTier {
    let name: String
    let monthlyPrice: Decimal
    let features: [String]
}

let pricingSpec = FirstMatchSpec<User, PricingTier>.builder()
    .add(
        EnterpriseContractSpec(),
        result: PricingTier(
            name: "Enterprise",
            monthlyPrice: 999.99,
            features: ["Unlimited", "Priority Support", "Custom Integration"]
        )
    )
    .add(
        TeamAccountSpec(),
        result: PricingTier(
            name: "Team",
            monthlyPrice: 49.99,
            features: ["Up to 25 users", "Standard Support"]
        )
    )
    .add(
        IndividualUserSpec(),
        result: PricingTier(
            name: "Pro",
            monthlyPrice: 9.99,
            features: ["Single user", "Email Support"]
        )
    )
    .fallback(
        PricingTier(
            name: "Free",
            monthlyPrice: 0.00,
            features: ["Limited"]
        )
    )
    .build()

let tier = pricingSpec.decide(user)!
```

## Combining with Context

Use with ``EvaluationContext`` for dynamic decisions:

```swift
let featureAccessSpec = FirstMatchSpec<EvaluationContext, [String]>.builder()
    .add(
        PredicateSpec.flag("admin_access"),
        result: ["admin", "premium", "standard", "basic"]
    )
    .add(
        PredicateSpec.flag("premium_user"),
        result: ["premium", "standard", "basic"]
    )
    .add(
        PredicateSpec.counter("login_count", .greaterThan, 10),
        result: ["standard", "basic"]
    )
    .fallback(["basic"])
    .build()

let provider = DefaultContextProvider.shared
provider.setFlag("premium_user", to: true)

let context = provider.currentContext()
let features = featureAccessSpec.decide(context) ?? []
```

## Best Practices

### Order Matters

```swift
// ✅ Good - most specific first
let spec = FirstMatchSpec([
    (VIPCustomerSpec(), "vip_service"),     // Most specific
    (PremiumUserSpec(), "premium_service"), // Less specific
    (ActiveUserSpec(), "standard_service")  // Least specific
])

// ❌ Wrong - general rules first prevent specific matches
let badSpec = FirstMatchSpec([
    (ActiveUserSpec(), "standard_service"), // Catches everyone
    (PremiumUserSpec(), "premium_service"), // Never reached
    (VIPCustomerSpec(), "vip_service")      // Never reached
])
```

### Always Provide Fallback for Critical Decisions

```swift
// ✅ Good - guaranteed result
let spec = FirstMatchSpec.withFallback([
    (PremiumSpec(), "premium_experience")
], fallback: "default_experience")

// ❌ Risky - might return nil
let riskySpec = FirstMatchSpec([
    (PremiumSpec(), "premium_experience")
])

// Need to handle nil
let experience = riskySpec.decide(user) ?? "error"
```

### Use Builder for Complex Decisions

```swift
// ✅ Good - clear and maintainable
let spec = FirstMatchSpec<User, String>.builder()
    .add(Spec1(), result: "result1")
    .add(Spec2(), result: "result2")
    .add(Spec3(), result: "result3")
    .fallback("default")
    .build()

// ❌ Harder to read - array of tuples
let spec = FirstMatchSpec([
    (Spec1(), "result1"),
    (Spec2(), "result2"),
    (Spec3(), "result3"),
    (AlwaysTrueSpec(), "default")
])
```

### Type Consistency

```swift
// ✅ Good - consistent result types
let spec = FirstMatchSpec<User, String>([
    (Spec1(), "option_a"),
    (Spec2(), "option_b"),
    (Spec3(), "option_c")
])

// Compiler enforces type consistency
```

## Performance Considerations

- **Short-Circuit Evaluation**: Stops at first match; no unnecessary evaluations
- **Order Optimization**: Place most likely matches first for better performance
- **Metadata Overhead**: Minimal; only stores index when requested
- **Builder Allocation**: Creates array; efficient for reasonable rule counts
- **Type Erasure**: Uses `AnySpecification` internally; minimal overhead

## Topics

### Creating Specifications

- ``init(_:includeMetadata:)``
- ``init(_:includeMetadata:)-swift.init.1``
- ``withFallback(_:fallback:)``
- ``withFallback(_:fallback:)-swift.type.method.1``

### Builder Pattern

- ``Builder``
- ``builder()``

### Decision Methods

- ``decide(_:)``
- ``decideWithMetadata(_:)``

### Supporting Types

- ``SpecificationPair``

### Property Wrappers

- ``Decides``
- ``Maybe``

### Related Types

- ``DecisionSpec``
- ``Specification``

## See Also

- <doc:DecisionSpec>
- ``Decides``
- ``Maybe``
- ``PredicateSpec``
