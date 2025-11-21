# @specs Macro

A macro that generates composite specifications by combining multiple specification instances with AND logic.

## Overview

The `@specs` macro simplifies creating composite specifications by automatically combining multiple specification instances using `.and()` logic. Instead of manually chaining specifications together, you can declare a specification type with the `@specs` macro and let it generate all the boilerplate code for you.

### Key Benefits

- **Automatic Composition**: Generates `.and()` chains automatically from specification instances
- **Type-Safe**: Validates that all specifications share the same context type
- **Compile-Time Validation**: Catches errors like mixed context types and incorrect arguments
- **Reduced Boilerplate**: Eliminates repetitive composite specification code
- **Clear Intent**: Declarative syntax makes complex rules easy to understand
- **Auto Context Integration**: Works seamlessly with ``AutoContext`` macro

### When to Use @specs

Use `@specs` when you need to:
- Combine multiple specifications with AND logic
- Create reusable composite specification types
- Define complex business rules declaratively
- Reduce boilerplate in specification-heavy code
- Build eligibility or validation specifications

## Quick Example

```swift
import SpecificationCore

// Without @specs - manual composition
struct PremiumEligibilitySpec: Specification {
    typealias T = EvaluationContext

    let spec1 = FeatureFlagSpec(flagKey: "premium_enabled")
    let spec2 = TimeSinceEventSpec(eventKey: "user_registered", days: 30)
    let spec3 = MaxCountSpec(counterKey: "violations", maximumCount: 1)

    func isSatisfiedBy(_ candidate: EvaluationContext) -> Bool {
        return spec1.and(spec2).and(spec3).isSatisfiedBy(candidate)
    }
}

// With @specs - automatic composition
@specs(
    FeatureFlagSpec(flagKey: "premium_enabled"),
    TimeSinceEventSpec(eventKey: "user_registered", days: 30),
    MaxCountSpec(counterKey: "violations", maximumCount: 1)
)
struct PremiumEligibilitySpec: Specification {
    typealias T = EvaluationContext
}
```

## How @specs Works

The macro generates the necessary boilerplate to combine specifications:

```swift
@specs(Spec1(), Spec2(), Spec3())
struct MyCompositeSpec: Specification {
    typealias T = EvaluationContext
}

// Expands to:
struct MyCompositeSpec: Specification {
    typealias T = EvaluationContext

    private let composite: AnySpecification<T>

    public init() {
        let specChain = Spec1().and(Spec2()).and(Spec3())
        self.composite = AnySpecification(specChain)
    }

    public func isSatisfiedBy(_ candidate: T) -> Bool {
        composite.isSatisfiedBy(candidate)
    }

    public func isSatisfiedByAsync(_ candidate: T) async throws -> Bool {
        composite.isSatisfiedBy(candidate)
    }
}
```

## Usage Examples

### Basic Eligibility Specification

```swift
@specs(
    TimeSinceEventSpec(eventKey: "user_registered", days: 7),
    FeatureFlagSpec(flagKey: "email_verified"),
    MaxCountSpec(counterKey: "violations", maximumCount: 0)
)
struct RewardEligibilitySpec: Specification {
    typealias T = EvaluationContext
}

// Usage
let spec = RewardEligibilitySpec()
let context = DefaultContextProvider.shared.currentContext()

if spec.isSatisfiedBy(context) {
    grantReward()
}
```

### API Access Control

```swift
@specs(
    MaxCountSpec.dailyLimit("api_calls", limit: 1000),
    FeatureFlagSpec(flagKey: "api_access_enabled"),
    CooldownIntervalSpec.hourly("rate_limit_violation").not()
)
struct APIAccessSpec: Specification {
    typealias T = EvaluationContext
}

func makeAPICall() throws {
    let spec = APIAccessSpec()
    let context = DefaultContextProvider.shared.currentContext()

    guard spec.isSatisfiedBy(context) else {
        throw APIError.accessDenied
    }

    // Make API call
}
```

### Feature Rollout Specification

```swift
@specs(
    FeatureFlagSpec(flagKey: "new_feature_enabled"),
    DateRangeSpec(start: rolloutStart, end: rolloutEnd),
    UserSegmentSpec(expectedSegment: .beta)
)
struct NewFeatureAccessSpec: Specification {
    typealias T = EvaluationContext
}

@Satisfies(using: NewFeatureAccessSpec())
var canAccessNewFeature: Bool

if canAccessNewFeature {
    showNewFeature()
}
```

### Premium Subscription Validation

```swift
@specs(
    FeatureFlagSpec(flagKey: "subscription_active"),
    DateComparisonSpec(
        eventKey: "subscription_start",
        comparison: .before,
        date: Date().addingTimeInterval(365 * 86400)  // Within 1 year
    ),
    MaxCountSpec(counterKey: "payment_failures", maximumCount: 0)
)
struct ActiveSubscriptionSpec: Specification {
    typealias T = EvaluationContext
}

func checkSubscriptionAccess() -> Bool {
    let spec = ActiveSubscriptionSpec()
    let context = DefaultContextProvider.shared.currentContext()
    return spec.isSatisfiedBy(context)
}
```

## Combining with @AutoContext

The `@specs` macro works seamlessly with ``AutoContext`` for even cleaner code:

```swift
@specs(
    FeatureFlagSpec(flagKey: "premium_enabled"),
    TimeSinceEventSpec(eventKey: "user_registered", days: 30),
    MaxCountSpec.dailyLimit("premium_actions", limit: 100)
)
@AutoContext
struct PremiumAccessSpec: Specification {
    typealias T = EvaluationContext
}

// Usage with auto-context - no provider needed!
let spec = PremiumAccessSpec()

// Access isSatisfied property (added by @AutoContext)
if try await spec.isSatisfied {
    enablePremiumFeatures()
}
```

## Real-World Examples

### Multi-Tier Access Control

```swift
// Free tier - basic checks only
@specs(
    FeatureFlagSpec(flagKey: "free_tier_enabled"),
    MaxCountSpec.dailyLimit("free_actions", limit: 10)
)
struct FreeTierSpec: Specification {
    typealias T = EvaluationContext
}

// Premium tier - more permissive
@specs(
    FeatureFlagSpec(flagKey: "premium_subscription"),
    MaxCountSpec.dailyLimit("premium_actions", limit: 1000),
    DateComparisonSpec(
        eventKey: "subscription_start",
        comparison: .before,
        date: Date()
    )
)
struct PremiumTierSpec: Specification {
    typealias T = EvaluationContext
}

// Enterprise tier - most permissive
@specs(
    FeatureFlagSpec(flagKey: "enterprise_subscription"),
    MaxCountSpec.dailyLimit("enterprise_actions", limit: 100000),
    FeatureFlagSpec(flagKey: "priority_support")
)
struct EnterpriseTierSpec: Specification {
    typealias T = EvaluationContext
}

func getAccessLevel() -> AccessLevel {
    let context = DefaultContextProvider.shared.currentContext()

    if EnterpriseTierSpec().isSatisfiedBy(context) {
        return .enterprise
    } else if PremiumTierSpec().isSatisfiedBy(context) {
        return .premium
    } else if FreeTierSpec().isSatisfiedBy(context) {
        return .free
    } else {
        return .none
    }
}
```

### Campaign Eligibility System

```swift
@specs(
    DateRangeSpec(start: campaignStart, end: campaignEnd),
    UserSegmentSpec(expectedSegment: .targetAudience),
    MaxCountSpec(counterKey: "campaign_participations", maximumCount: 0),
    TimeSinceEventSpec(eventKey: "user_registered", days: 7),
    FeatureFlagSpec(flagKey: "campaign_active")
)
struct CampaignEligibilitySpec: Specification {
    typealias T = EvaluationContext
}

func checkCampaignEligibility() -> (eligible: Bool, reason: String?) {
    let spec = CampaignEligibilitySpec()
    let context = DefaultContextProvider.shared.currentContext()

    let eligible = spec.isSatisfiedBy(context)

    if !eligible {
        // Check individual conditions to provide feedback
        if !DateRangeSpec(start: campaignStart, end: campaignEnd)
            .isSatisfiedBy(context) {
            return (false, "Campaign is not currently active")
        }
        if !TimeSinceEventSpec(eventKey: "user_registered", days: 7)
            .isSatisfiedBy(context) {
            return (false, "Account must be at least 7 days old")
        }
        return (false, "Not eligible for this campaign")
    }

    return (true, nil)
}
```

### Security Gate Specification

```swift
@specs(
    FeatureFlagSpec(flagKey: "account_verified"),
    FeatureFlagSpec(flagKey: "two_factor_enabled"),
    MaxCountSpec(counterKey: "failed_login_attempts", maximumCount: 3),
    CooldownIntervalSpec(eventKey: "last_password_change", days: 90).not(),
    MaxCountSpec(counterKey: "security_violations", maximumCount: 0)
)
struct HighSecurityAccessSpec: Specification {
    typealias T = EvaluationContext
}

func canAccessSensitiveData() -> Bool {
    let spec = HighSecurityAccessSpec()
    let context = DefaultContextProvider.shared.currentContext()
    return spec.isSatisfiedBy(context)
}

func performSensitiveOperation() throws {
    guard canAccessSensitiveData() else {
        throw SecurityError.insufficientPermissions
    }

    // Perform operation
}
```

### Content Moderation Specification

```swift
@specs(
    FeatureFlagSpec(flagKey: "account_in_good_standing"),
    MaxCountSpec(counterKey: "content_warnings", maximumCount: 2),
    MaxCountSpec(counterKey: "community_reports", maximumCount: 5),
    TimeSinceEventSpec(eventKey: "last_violation", days: 30),
    CooldownIntervalSpec(eventKey: "last_suspension", days: 90)
)
struct CanPostContentSpec: Specification {
    typealias T = EvaluationContext
}

func validateUserCanPost() -> PostPermission {
    let spec = CanPostContentSpec()
    let context = DefaultContextProvider.shared.currentContext()

    if spec.isSatisfiedBy(context) {
        return .allowed
    } else {
        return .restricted(reason: "Account restrictions in effect")
    }
}
```

## Validation and Diagnostics

The `@specs` macro provides compile-time validation:

### Requires Specification Conformance

```swift
// ❌ Error - must conform to Specification
@specs(Spec1(), Spec2())
struct MySpec {  // Missing: Specification
    typealias T = EvaluationContext
}
```

### Requires At Least One Argument

```swift
// ❌ Error - requires at least one specification
@specs()
struct EmptySpec: Specification {
    typealias T = EvaluationContext
}
```

### Warns About Missing typealias T

```swift
// ⚠️ Warning - should add typealias T
@specs(Spec1(), Spec2())
struct MySpec: Specification {
    // Missing: typealias T = EvaluationContext
}
```

### Detects Mixed Context Types

```swift
// ❌ Error - mixed context types
@specs(
    MaxCountSpec(counterKey: "count", maximumCount: 10),  // EvaluationContext
    CustomSpec<OtherContext>()                             // OtherContext
)
struct MixedSpec: Specification {
    typealias T = EvaluationContext
}
```

### Prevents Async Specifications

```swift
// ❌ Error - async specifications not supported
@specs(
    MaxCountSpec(counterKey: "count", maximumCount: 10),
    SomeAsyncSpec()  // AsyncSpecification not allowed
)
struct MySpec: Specification {
    typealias T = EvaluationContext
}
```

### Warns About Type References

```swift
// ⚠️ Warning - looks like a type reference
@specs(
    MaxCountSpec.self,  // Should be MaxCountSpec(...)
    FeatureFlagSpec.self
)
struct MySpec: Specification {
    typealias T = EvaluationContext
}
```

## Testing

Test macro-generated specifications like any other:

```swift
func testCompositeSpecification() {
    @specs(
        FeatureFlagSpec(flagKey: "enabled"),
        MaxCountSpec(counterKey: "count", maximumCount: 10)
    )
    struct TestSpec: Specification {
        typealias T = EvaluationContext
    }

    let provider = MockContextProvider()
        .withFlag("enabled", value: true)
        .withCounter("count", value: 5)

    let spec = TestSpec()
    let context = provider.currentContext()

    // Both conditions satisfied
    XCTAssertTrue(spec.isSatisfiedBy(context))

    // Disable flag - should fail
    provider.setFlag("enabled", to: false)
    XCTAssertFalse(spec.isSatisfiedBy(context))

    // Exceed count - should fail
    provider.setFlag("enabled", to: true)
    provider.setCounter("count", to: 15)
    XCTAssertFalse(spec.isSatisfiedBy(context))
}

func testSpecsWithAutoContext() async throws {
    @specs(
        FeatureFlagSpec(flagKey: "feature_enabled")
    )
    @AutoContext
    struct AutoSpec: Specification {
        typealias T = EvaluationContext
    }

    // Set up test context
    DefaultContextProvider.shared.setFlag("feature_enabled", to: true)

    let spec = AutoSpec()

    // Test using isSatisfied property
    let result = try await spec.isSatisfied
    XCTAssertTrue(result)
}
```

## Best Practices

### Use Descriptive Specification Names

```swift
// ✅ Good - clear intent
@specs(
    PremiumUserSpec(),
    EmailVerifiedSpec(),
    NoViolationsSpec()
)
struct PremiumAccessSpec: Specification {
    typealias T = EvaluationContext
}

// ❌ Avoid - unclear purpose
@specs(
    Spec1(),
    Spec2(),
    Spec3()
)
struct ComboSpec: Specification {
    typealias T = EvaluationContext
}
```

### Group Related Specifications

```swift
// ✅ Good - grouped by concern
@specs(
    // Account status
    FeatureFlagSpec(flagKey: "account_active"),
    FeatureFlagSpec(flagKey: "email_verified"),

    // Usage limits
    MaxCountSpec.dailyLimit("api_calls", limit: 1000),
    CooldownIntervalSpec.hourly("rate_limit"),

    // Security
    MaxCountSpec(counterKey: "failed_attempts", maximumCount: 3)
)
struct SecureAPIAccessSpec: Specification {
    typealias T = EvaluationContext
}
```

### Document Complex Specifications

```swift
/// Determines eligibility for loyalty rewards program.
///
/// Requirements:
/// - Account registered for at least 30 days
/// - Email verified
/// - Made at least 5 purchases
/// - No account violations
/// - Loyalty program is currently active
@specs(
    TimeSinceEventSpec(eventKey: "user_registered", days: 30),
    FeatureFlagSpec(flagKey: "email_verified"),
    MaxCountSpec(counterKey: "purchases", maximumCount: 5).not(),
    MaxCountSpec(counterKey: "violations", maximumCount: 0),
    FeatureFlagSpec(flagKey: "loyalty_program_active")
)
struct LoyaltyRewardsEligibilitySpec: Specification {
    typealias T = EvaluationContext
}
```

### Combine with Property Wrappers

```swift
@specs(
    PremiumSubscriptionSpec(),
    NoPaymentIssuesSpec(),
    AccountInGoodStandingSpec()
)
struct PremiumAccessSpec: Specification {
    typealias T = EvaluationContext
}

// Use with @Satisfies for clean integration
@Satisfies(using: PremiumAccessSpec())
var hasPremiumAccess: Bool

if hasPremiumAccess {
    showPremiumContent()
}
```

## Performance Considerations

- **Single Evaluation**: Composite specification is created once at initialization
- **Chained Evaluation**: Evaluates specifications in order, stops at first failure
- **No Overhead**: Macro expansion happens at compile time
- **Type Erasure**: Uses `AnySpecification` for type erasure (minimal overhead)
- **Short-Circuit Logic**: AND logic stops at first false result

## Comparison with Manual Composition

### Manual Composition

```swift
struct ManualCompositeSpec: Specification {
    typealias T = EvaluationContext

    private let spec1 = FeatureFlagSpec(flagKey: "enabled")
    private let spec2 = MaxCountSpec(counterKey: "count", maximumCount: 10)
    private let spec3 = TimeSinceEventSpec(eventKey: "start", days: 7)

    func isSatisfiedBy(_ candidate: EvaluationContext) -> Bool {
        return spec1.and(spec2).and(spec3).isSatisfiedBy(candidate)
    }
}
```

### With @specs Macro

```swift
@specs(
    FeatureFlagSpec(flagKey: "enabled"),
    MaxCountSpec(counterKey: "count", maximumCount: 10),
    TimeSinceEventSpec(eventKey: "start", days: 7)
)
struct MacroCompositeSpec: Specification {
    typealias T = EvaluationContext
}
```

**Benefits of @specs**:
- Less boilerplate (no manual property declarations)
- Clearer intent (specifications listed declaratively)
- Consistent pattern across codebase
- Automatic validation at compile time
- Less room for implementation errors

## Topics

### Macro Usage



### Related Macros

- <doc:AutoContextMacro>

### Related Types

- ``Specification``
- ``AnySpecification``
- ``EvaluationContext``

## See Also

- <doc:AutoContextMacro>
- <doc:Specification>
- <doc:AnySpecification>
- <doc:EvaluationContext>
