# ``SpecificationCore/Satisfies``

A property wrapper that provides declarative specification evaluation with boolean results.

## Overview

`@Satisfies` enables clean, readable specification usage by automatically handling context retrieval and specification evaluation. It transforms complex specification evaluation into simple boolean properties, making your code more expressive and maintainable.

### Key Benefits

- **Declarative Syntax**: Convert specification evaluation into readable property declarations
- **Automatic Context**: Handles context provider integration automatically
- **Multiple Initialization Patterns**: Supports specifications, predicates, and builders
- **Async Support**: Optional async evaluation through projected value
- **Type-Safe**: Compile-time safety for context and specification types
- **Composable**: Works with all specification types and operators

### When to Use @Satisfies

Use `@Satisfies` when you need to:
- Convert specification evaluation into properties
- Simplify boolean condition checking
- Create declarative feature flags or eligibility checks
- Automatically manage context provider access
- Build reactive UIs based on specification results

## Quick Example

```swift
import SpecificationCore

// Simple feature flag check
@Satisfies(using: FeatureFlagSpec(flagKey: "new_ui"))
var isNewUIEnabled: Bool

// Usage
if isNewUIEnabled {
    showNewUI()
} else {
    showLegacyUI()
}
```

## Creating @Satisfies

### With Specification Instances

```swift
// Using a specification instance
@Satisfies(using: MaxCountSpec(counterKey: "api_calls", maximumCount: 100))
var canMakeAPICall: Bool

// Using custom provider
@Satisfies(provider: customProvider, using: PremiumUserSpec())
var isPremiumUser: Bool
```

### With Predicates

```swift
// Simple predicate
@Satisfies(predicate: { context in
    context.counter(for: "login_attempts") < 5
})
var canAttemptLogin: Bool

// With custom provider
@Satisfies(provider: myProvider, predicate: { context in
    context.flag(for: "beta_access") && context.counter(for: "sessions") > 10
})
var hasBetaAccess: Bool
```

### With Manual Context

```swift
// Provide context directly
let myContext = EvaluationContext(currentDate: Date())

@Satisfies(context: myContext, using: DateRangeSpec(start: startDate, end: endDate))
var isInDateRange: Bool
```

### With Specification Types

```swift
// For specifications conforming to ExpressibleByNilLiteral
@Satisfies(using: FeatureFlagSpec.self)
var isFeatureEnabled: Bool
```

## How It Works

The property wrapper evaluates the specification each time the property is accessed:

```swift
@Satisfies(using: MaxCountSpec(counterKey: "attempts", maximumCount: 3))
var canRetry: Bool

// Each access re-evaluates:
if canRetry {  // Evaluates specification
    attemptOperation()
    provider.incrementCounter("attempts")
}

if canRetry {  // Re-evaluates with updated context
    attemptAgain()
}
```

## Usage Examples

### Feature Flag Management

```swift
@Satisfies(using: FeatureFlagSpec(flagKey: "premium_features"))
var showPremiumFeatures: Bool

@Satisfies(using: FeatureFlagSpec(flagKey: "experimental_ui"))
var useExperimentalUI: Bool

@Satisfies(using: FeatureFlagSpec(flagKey: "analytics_enabled"))
var shouldTrackAnalytics: Bool

func setupApp() {
    if showPremiumFeatures {
        enablePremiumContent()
    }

    if useExperimentalUI {
        loadExperimentalComponents()
    }

    if shouldTrackAnalytics {
        startAnalyticsTracking()
    }
}
```

### User Eligibility Checks

```swift
@Satisfies(using: TimeSinceEventSpec(eventKey: "user_registered", days: 30))
var isLoyalUser: Bool

@Satisfies(using: MaxCountSpec(counterKey: "purchases", maximumCount: 0).not())
var hasMadePurchases: Bool

@Satisfies(predicate: { context in
    context.flag(for: "email_verified") &&
    context.counter(for: "profile_completeness") >= 80
})
var hasCompleteProfile: Bool

func checkRewardEligibility() {
    if isLoyalUser && hasMadePurchases && hasCompleteProfile {
        offerLoyaltyReward()
    }
}
```

### Rate Limiting

```swift
@Satisfies(using: MaxCountSpec.dailyLimit("api_requests", limit: 1000))
var canMakeRequest: Bool

@Satisfies(using: CooldownIntervalSpec.hourly("notification_sent"))
var canSendNotification: Bool

func performAPICall() async throws {
    guard canMakeRequest else {
        throw APIError.rateLimitExceeded
    }

    let response = try await makeRequest()
    DefaultContextProvider.shared.incrementCounter("api_requests")
    return response
}
```

### Complex Conditions

```swift
// Combine multiple specifications
@Satisfies(predicate: { context in
    // Premium user OR trial user with remaining days
    let isPremium = context.flag(for: "premium_subscription")
    let isTrialActive = context.flag(for: "trial_active")
    let trialDaysRemaining = context.counter(for: "trial_days_remaining")

    return isPremium || (isTrialActive && trialDaysRemaining > 0)
})
var hasProAccess: Bool
```

## Builder Pattern

Create complex specifications using the builder API:

```swift
@Satisfies(build: { builder in
    builder
        .with(FeatureFlagSpec(flagKey: "feature_enabled"))
        .with { context in context.counter(for: "sessions") >= 5 }
        .with(TimeSinceEventSpec(eventKey: "first_launch", days: 7))
        .buildAll()  // Requires ALL conditions
})
var isEligibleForAdvancedFeatures: Bool

@Satisfies(build: { builder in
    builder
        .with(PremiumUserSpec())
        .with(BetaUserSpec())
        .buildAny()  // Requires ANY condition
})
var hasSpecialAccess: Bool
```

## Convenience Initializers

### Time-Based Conditions

```swift
// Time since app launch
@Satisfies(Satisfies.timeSinceLaunch(minimumSeconds: 300))
var hasBeenRunningLongEnough: Bool

// Custom cooldown
@Satisfies(Satisfies.cooldown("last_prompt", minimumInterval: 3600))
var canShowPrompt: Bool
```

### Counter-Based Conditions

```swift
@Satisfies(Satisfies.counter("login_attempts", lessThan: 5))
var canAttemptLogin: Bool

@Satisfies(Satisfies.counter("page_views", lessThan: 10))
var isWithinFreeLimit: Bool
```

### Flag-Based Conditions

```swift
@Satisfies(Satisfies.flag("dark_mode_enabled"))
var isDarkModeEnabled: Bool

@Satisfies(Satisfies.flag("notifications_allowed", equals: true))
var canSendNotifications: Bool
```

## Async Evaluation

Access async evaluation through the projected value:

```swift
@Satisfies(using: AsyncRemoteConfigSpec(key: "feature_gate"))
var isRemoteFeatureEnabled: Bool

func checkFeature() async {
    do {
        let enabled = try await $isRemoteFeatureEnabled.evaluateAsync()
        if enabled {
            activateFeature()
        }
    } catch {
        handleError(error)
    }
}
```

## Real-World Examples

### App Launch Flow

```swift
class AppCoordinator {
    @Satisfies(using: TimeSinceEventSpec(eventKey: "first_launch", hours: 0).not())
    var isFirstLaunch: Bool

    @Satisfies(using: MaxCountSpec.onlyOnce("onboarding_completed").not())
    var needsOnboarding: Bool

    @Satisfies(predicate: { context in
        context.flag(for: "user_logged_in")
    })
    var isUserLoggedIn: Bool

    func determineInitialRoute() -> AppRoute {
        if isFirstLaunch {
            return .welcome
        } else if needsOnboarding {
            return .onboarding
        } else if !isUserLoggedIn {
            return .login
        } else {
            return .home
        }
    }
}
```

### Feature Gate System

```swift
struct FeatureGate {
    @Satisfies(using: FeatureFlagSpec(flagKey: "experimental_ai"))
    var hasAIFeatures: Bool

    @Satisfies(using: FeatureFlagSpec(flagKey: "beta_testing"))
    var isBetaTester: Bool

    @Satisfies(predicate: { context in
        context.flag(for: "premium_subscription") ||
        context.flag(for: "lifetime_access")
    })
    var hasPremiumAccess: Bool

    func canAccessFeature(_ feature: Feature) -> Bool {
        switch feature {
        case .aiGeneration:
            return hasAIFeatures && hasPremiumAccess
        case .advancedAnalytics:
            return hasPremiumAccess
        case .experimentalFeatures:
            return isBetaTester
        case .basicFeatures:
            return true
        }
    }
}
```

### Rate Limit Manager

```swift
class RateLimitManager {
    @Satisfies(using: MaxCountSpec.dailyLimit("api_calls", limit: 10000))
    var withinDailyLimit: Bool

    @Satisfies(using: MaxCountSpec(counterKey: "api_calls_this_hour", maximumCount: 1000))
    var withinHourlyLimit: Bool

    @Satisfies(using: CooldownIntervalSpec(eventKey: "last_burst", seconds: 1))
    var notInBurstCooldown: Bool

    func canMakeRequest(type: RequestType) -> Bool {
        guard withinDailyLimit else {
            return false
        }

        switch type {
        case .standard:
            return withinHourlyLimit
        case .burst:
            return withinHourlyLimit && notInBurstCooldown
        case .priority:
            return true  // Priority requests bypass rate limits
        }
    }

    func recordRequest(type: RequestType) {
        let provider = DefaultContextProvider.shared
        provider.incrementCounter("api_calls")
        provider.incrementCounter("api_calls_this_hour")

        if type == .burst {
            provider.recordEvent("last_burst")
        }
    }
}
```

### Subscription Management

```swift
class SubscriptionManager {
    @Satisfies(predicate: { context in
        context.flag(for: "subscription_active")
    })
    var hasActiveSubscription: Bool

    @Satisfies(using: DateComparisonSpec(
        eventKey: "subscription_expired",
        comparison: .before,
        date: Date().addingTimeInterval(3 * 86400)  // 3 day grace
    ))
    var isInGracePeriod: Bool

    @Satisfies(using: TimeSinceEventSpec(eventKey: "trial_started", days: 14).not())
    var isTrialActive: Bool

    func getAccessLevel() -> AccessLevel {
        if hasActiveSubscription {
            return .premium
        } else if isInGracePeriod {
            return .gracePeriod
        } else if isTrialActive {
            return .trial
        } else {
            return .free
        }
    }

    func canAccessPremiumContent() -> Bool {
        return hasActiveSubscription || isInGracePeriod || isTrialActive
    }
}
```

## Composition with Specifications

Use specification operators for complex logic:

```swift
// Create composed specifications
let premiumSpec = FeatureFlagSpec(flagKey: "premium")
let trialSpec = FeatureFlagSpec(flagKey: "trial_active")
let accessSpec = premiumSpec.or(trialSpec)

@Satisfies(using: accessSpec)
var hasProAccess: Bool

// Negation
let blockedSpec = FeatureFlagSpec(flagKey: "account_blocked")
@Satisfies(using: blockedSpec.not())
var isNotBlocked: Bool

// Complex composition
let eligibilitySpec = PremiumUserSpec()
    .and(EmailVerifiedSpec())
    .and(MaxCountSpec(counterKey: "violations", maximumCount: 1))

@Satisfies(using: eligibilitySpec)
var isEligibleForRewards: Bool
```

## Testing

Test property wrapper usage with ``MockContextProvider``:

```swift
func testFeatureFlag() {
    // Setup mock context
    let provider = MockContextProvider()
        .withFlag("premium_features", value: true)

    // Create specification that uses the provider
    @Satisfies(provider: provider, using: FeatureFlagSpec(flagKey: "premium_features"))
    var hasPremium: Bool

    // Test evaluation
    XCTAssertTrue(hasPremium)

    // Update context
    provider.setFlag("premium_features", to: false)

    // Re-evaluation reflects new context
    XCTAssertFalse(hasPremium)
}

func testRateLimit() {
    let provider = MockContextProvider()
        .withCounter("api_calls", value: 99)

    @Satisfies(
        provider: provider,
        using: MaxCountSpec(counterKey: "api_calls", maximumCount: 100)
    )
    var canMakeCall: Bool

    // Under limit
    XCTAssertTrue(canMakeCall)

    // Reach limit
    provider.setCounter("api_calls", to: 100)
    XCTAssertFalse(canMakeCall)
}

func testAsyncEvaluation() async throws {
    let provider = MockContextProvider()
        .withFlag("remote_feature", value: true)

    @Satisfies(provider: provider, using: FeatureFlagSpec(flagKey: "remote_feature"))
    var isEnabled: Bool

    let result = try await $isEnabled.evaluateAsync()
    XCTAssertTrue(result)
}
```

## Best Practices

### Use Descriptive Property Names

```swift
// ✅ Good - clear intent
@Satisfies(using: PremiumUserSpec())
var hasPremiumAccess: Bool

@Satisfies(using: MaxCountSpec.dailyLimit("exports", limit: 10))
var canExportToday: Bool

// ❌ Avoid - unclear purpose
@Satisfies(using: PremiumUserSpec())
var spec1: Bool

@Satisfies(using: MaxCountSpec.dailyLimit("exports", limit: 10))
var check: Bool
```

### Choose Appropriate Initialization

```swift
// ✅ Good - simple specification
@Satisfies(using: FeatureFlagSpec(flagKey: "new_feature"))
var isFeatureEnabled: Bool

// ✅ Good - simple predicate for inline logic
@Satisfies(predicate: { context in
    context.counter(for: "score") > 100
})
var hasHighScore: Bool

// ✅ Good - complex composition with builder
@Satisfies(build: { builder in
    builder
        .with(Spec1())
        .with(Spec2())
        .buildAll()
})
var meetsComplexCriteria: Bool
```

### Consider Re-Evaluation Cost

```swift
// ✅ Good - lightweight evaluation
@Satisfies(using: FeatureFlagSpec(flagKey: "simple_flag"))
var isEnabled: Bool

// ⚠️ Consider caching - expensive evaluation
@Satisfies(predicate: { context in
    // Expensive computation on each access
    performComplexCalculation(context)
})
var expensiveCheck: Bool

// ✅ Better - cache or use alternative approach
let cachedResult = performComplexCalculation(context)
@Satisfies({ _ in cachedResult })
var cachedCheck: Bool
```

### Handle Provider Lifecycle

```swift
// ✅ Good - use shared provider for simple cases
@Satisfies(using: FeatureFlagSpec(flagKey: "feature"))
var isEnabled: Bool

// ✅ Good - custom provider for specific needs
let scopedProvider = DefaultContextProvider()
@Satisfies(provider: scopedProvider, using: MySpec())
var isSatisfied: Bool

// ✅ Good - manual context for testing or special cases
@Satisfies(context: testContext, using: MySpec())
var testResult: Bool
```

## Performance Considerations

- **Evaluation on Access**: Specification is evaluated each time the property is accessed
- **Context Fetching**: Context is fetched from provider on each evaluation
- **No Caching**: No automatic caching of results; re-evaluates every time
- **Lightweight Specs**: Use simple specifications for properties accessed frequently
- **Async Overhead**: Async evaluation via projected value has async context fetching overhead
- **Provider Cost**: Context provider performance affects property access performance

Consider using cached variants or manual caching for expensive evaluations:

```swift
// For expensive specifications accessed frequently
class ViewModel {
    private var cachedValue: Bool?
    private let spec = ExpensiveSpec()

    var isExpensiveConditionMet: Bool {
        if let cached = cachedValue {
            return cached
        }
        let result = spec.isSatisfiedBy(context)
        cachedValue = result
        return result
    }

    func invalidateCache() {
        cachedValue = nil
    }
}
```

## Topics

### Property Values

- ``wrappedValue``
- ``projectedValue``

### Async Support

- ``evaluateAsync()``

## See Also

- <doc:Decides>
- <doc:Maybe>
- <doc:AsyncSatisfies>
- <doc:Specification>
- <doc:EvaluationContext>
