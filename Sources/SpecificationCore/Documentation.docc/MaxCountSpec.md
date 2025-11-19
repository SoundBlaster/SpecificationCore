# ``SpecificationCore/MaxCountSpec``

A specification that checks if a counter is below a maximum threshold.

## Overview

`MaxCountSpec` is used to implement limits on actions, display counts, or usage restrictions. It evaluates to true when a counter value is strictly less than a specified maximum, making it ideal for rate limiting, usage quotas, and feature restrictions.

### Key Benefits

- **Simple Usage Limits**: Implement counters and quotas easily
- **Context-Based**: Works with ``EvaluationContext`` counters
- **Type-Safe**: Compile-time safety for counter keys and limits
- **Flexible Variants**: Inclusive, exclusive, exact, and range checks
- **Composable**: Combine with other specifications

### When to Use MaxCountSpec

Use `MaxCountSpec` when you need to:
- Limit the number of times an action can be performed
- Implement daily, weekly, or monthly quotas
- Restrict feature usage based on tier or plan
- Control banner or notification display frequency
- Enforce API rate limits

## Quick Example

```swift
import SpecificationCore

// Set up context
let provider = DefaultContextProvider.shared
provider.setCounter("api_calls_today", to: 50)

// Create spec with limit of 100
let apiLimitSpec = MaxCountSpec(
    counterKey: "api_calls_today",
    maximumCount: 100
)

// Use with property wrapper
@Satisfies(using: apiLimitSpec)
var canMakeAPICall: Bool

if canMakeAPICall {
    makeAPICall()
    provider.incrementCounter("api_calls_today")
}
```

## Creating MaxCountSpec

### Basic Creation

```swift
// Standard initialization
let spec = MaxCountSpec(
    counterKey: "login_attempts",
    maximumCount: 5
)

// Alternative with "limit" parameter
let spec2 = MaxCountSpec(
    counterKey: "login_attempts",
    limit: 5
)

// Both are equivalent
```

### Convenience Factories

```swift
// Generic counter limit
let downloadLimit = MaxCountSpec.counter("downloads", limit: 10)

// Single-use actions
let showOnce = MaxCountSpec.onlyOnce("tutorial_shown")

// Allow twice
let allowTwice = MaxCountSpec.onlyTwice("password_reset")

// Time-period limits
let dailyLimit = MaxCountSpec.dailyLimit("api_calls", limit: 1000)
let weeklyLimit = MaxCountSpec.weeklyLimit("reports_generated", limit: 50)
let monthlyLimit = MaxCountSpec.monthlyLimit("exports", limit: 10)
```

## How It Works

The specification checks if the counter is **strictly less than** the maximum:

```swift
let spec = MaxCountSpec(counterKey: "attempts", maximumCount: 3)

// Counter = 0: satisfied (0 < 3) ✅
// Counter = 1: satisfied (1 < 3) ✅
// Counter = 2: satisfied (2 < 3) ✅
// Counter = 3: NOT satisfied (3 < 3) ❌
// Counter = 4: NOT satisfied (4 < 3) ❌
```

## Usage Examples

### API Rate Limiting

```swift
let provider = DefaultContextProvider.shared

// Set initial count
provider.setCounter("api_requests", to: 0)

// Create rate limit spec
@Satisfies(using: MaxCountSpec(counterKey: "api_requests", maximumCount: 100))
var canMakeRequest: Bool

func makeAPIRequest() async throws -> Response {
    guard canMakeRequest else {
        throw APIError.rateLimitExceeded
    }

    let response = try await performRequest()
    provider.incrementCounter("api_requests")
    return response
}

// Reset daily
func resetDailyLimits() {
    provider.resetCounter("api_requests")
}
```

### Feature Usage Limits

```swift
// Premium users: 100 exports per month
// Free users: 5 exports per month

let provider = DefaultContextProvider.shared
let isPremium = // ... determine user tier

let exportLimit = isPremium
    ? MaxCountSpec.monthlyLimit("exports", limit: 100)
    : MaxCountSpec.monthlyLimit("exports", limit: 5)

@Satisfies(using: exportLimit)
var canExport: Bool

if canExport {
    performExport()
    provider.incrementCounter("exports")
}
```

### Banner Display Limits

```swift
// Show promotional banner maximum 3 times
let bannerSpec = MaxCountSpec.counter("promo_banner_shown", limit: 3)

@Satisfies(using: bannerSpec)
var shouldShowBanner: Bool

struct ContentView: View {
    var body: some View {
        VStack {
            if shouldShowBanner {
                PromoBanner()
                    .onAppear {
                        DefaultContextProvider.shared
                            .incrementCounter("promo_banner_shown")
                    }
            }
            MainContent()
        }
    }
}
```

### Trial Limits

```swift
// Free trial: 10 AI generations
let trialSpec = MaxCountSpec(
    counterKey: "ai_generations",
    maximumCount: 10
)

@Satisfies(using: trialSpec)
var canGenerateAI: Bool

if canGenerateAI {
    let result = generateAIContent()
    provider.incrementCounter("ai_generations")
    return result
} else {
    showUpgradePrompt()
}
```

## Variant Specifications

### Inclusive Maximum

Allow values up to and including the maximum:

```swift
// Allow 0, 1, 2, 3, 4, 5 (inclusive)
let inclusiveSpec = MaxCountSpec.inclusive(
    counterKey: "attempts",
    maximumCount: 5
)

// Counter = 5: satisfied (5 <= 5) ✅
// Counter = 6: NOT satisfied (6 <= 5) ❌
```

### Exact Count

Match an exact counter value:

```swift
// Satisfied only when counter equals 3
let exactSpec = MaxCountSpec.exactly(
    counterKey: "steps_completed",
    count: 3
)

// Counter = 2: NOT satisfied ❌
// Counter = 3: satisfied ✅
// Counter = 4: NOT satisfied ❌
```

### Range Checks

Check if counter is within a range:

```swift
// Satisfied when counter is between 10 and 20 (inclusive)
let rangeSpec = MaxCountSpec.inRange(
    counterKey: "items",
    range: 10...20
)

// Counter = 9: NOT satisfied ❌
// Counter = 15: satisfied ✅
// Counter = 21: NOT satisfied ❌
```

## Composition

Combine with other MaxCountSpecs or specifications:

### AND Combination

```swift
// Both limits must be satisfied
let multiLimit = MaxCountSpec(counterKey: "daily_requests", maximumCount: 100)
    .and(MaxCountSpec(counterKey: "hourly_requests", maximumCount: 10))

// Requires daily < 100 AND hourly < 10
```

### OR Combination

```swift
// Either limit can be satisfied
let flexibleLimit = MaxCountSpec(counterKey: "free_tier_calls", maximumCount: 10)
    .or(MaxCountSpec(counterKey: "premium_tier_calls", maximumCount: 1000))

// Allows either counter to be under limit
```

### With Other Specifications

```swift
// Counter limit AND feature flag
let combinedSpec = MaxCountSpec(counterKey: "feature_uses", maximumCount: 5)
    .and(FeatureFlagSpec(flagKey: "feature_enabled"))

// Must be under limit AND feature must be enabled
```

## Real-World Examples

### Multi-Tier Access Control

```swift
enum UserTier {
    case free, basic, premium, enterprise
}

func getAPILimitSpec(for tier: UserTier) -> MaxCountSpec {
    switch tier {
    case .free:
        return MaxCountSpec.dailyLimit("api_calls", limit: 100)
    case .basic:
        return MaxCountSpec.dailyLimit("api_calls", limit: 1000)
    case .premium:
        return MaxCountSpec.dailyLimit("api_calls", limit: 10000)
    case .enterprise:
        return MaxCountSpec.dailyLimit("api_calls", limit: 100000)
    }
}

let limitSpec = getAPILimitSpec(for: currentUserTier)

@Satisfies(using: limitSpec)
var canCallAPI: Bool
```

### Onboarding Flow

```swift
// Show onboarding only on first 3 app launches
let onboardingSpec = MaxCountSpec.counter("app_launches", limit: 3)

@Satisfies(using: onboardingSpec)
var shouldShowOnboarding: Bool

func application(_ application: UIApplication, didFinishLaunchingWithOptions...) {
    DefaultContextProvider.shared.incrementCounter("app_launches")

    if shouldShowOnboarding {
        presentOnboarding()
    }
}
```

### Password Reset Limits

```swift
// Allow 3 password reset attempts per hour
let resetLimitSpec = MaxCountSpec(
    counterKey: "password_reset_attempts",
    maximumCount: 3
)

@Satisfies(using: resetLimitSpec)
var canResetPassword: Bool

func requestPasswordReset() {
    guard canResetPassword else {
        showError("Too many reset attempts. Try again in an hour.")
        return
    }

    sendPasswordResetEmail()
    DefaultContextProvider.shared.incrementCounter("password_reset_attempts")
}

// Reset hourly
Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
    DefaultContextProvider.shared.resetCounter("password_reset_attempts")
}
```

### Feature Rollout with Limits

```swift
// New feature limited to first 1000 users
let betaAccessSpec = MaxCountSpec(
    counterKey: "beta_users_enrolled",
    maximumCount: 1000
)

@Satisfies(using: betaAccessSpec)
var canEnrollInBeta: Bool

func enrollInBeta() {
    guard canEnrollInBeta else {
        showAlert("Beta program is full")
        return
    }

    enrollUser()
    DefaultContextProvider.shared.incrementCounter("beta_users_enrolled")
}
```

## Testing

Test counter-based logic with ``MockContextProvider``:

```swift
func testAPIRateLimit() {
    // Setup mock with counter at 99
    let provider = MockContextProvider()
        .withCounter("api_calls", value: 99)

    let spec = MaxCountSpec(counterKey: "api_calls", maximumCount: 100)

    // Should be satisfied (99 < 100)
    XCTAssertTrue(spec.isSatisfiedBy(provider.currentContext()))

    // Test at limit
    let atLimit = MockContextProvider()
        .withCounter("api_calls", value: 100)

    // Should NOT be satisfied (100 < 100 is false)
    XCTAssertFalse(spec.isSatisfiedBy(atLimit.currentContext()))
}

func testExactCount() {
    let spec = MaxCountSpec.exactly(counterKey: "steps", count: 3)

    // Not satisfied before reaching count
    let before = MockContextProvider().withCounter("steps", value: 2)
    XCTAssertFalse(spec.isSatisfiedBy(before.currentContext()))

    // Satisfied at exact count
    let exact = MockContextProvider().withCounter("steps", value: 3)
    XCTAssertTrue(spec.isSatisfiedBy(exact.currentContext()))

    // Not satisfied after exceeding count
    let after = MockContextProvider().withCounter("steps", value: 4)
    XCTAssertFalse(spec.isSatisfiedBy(after.currentContext()))
}
```

## Best Practices

### Choose Appropriate Limits

```swift
// ✅ Good - reasonable limits based on use case
let apiLimit = MaxCountSpec.dailyLimit("api_calls", limit: 1000)  // Generous
let retryLimit = MaxCountSpec.counter("retries", limit: 3)  // Conservative

// ❌ Avoid - limits that don't match use case
let tooRestrictive = MaxCountSpec.dailyLimit("page_views", limit: 1)  // Too low
let tooGenerous = MaxCountSpec.counter("login_attempts", limit: 1000)  // Too high
```

### Reset Counters Appropriately

```swift
// ✅ Good - reset at appropriate intervals
func resetDailyCounters() {
    provider.resetCounter("daily_api_calls")
    provider.resetCounter("daily_downloads")
}

Timer.scheduledTimer(withTimeInterval: 86400, repeats: true) { _ in
    resetDailyCounters()
}

// ❌ Avoid - never resetting counters
// Counters grow forever without reset
```

### Use Descriptive Counter Keys

```swift
// ✅ Good - clear, specific keys
let spec1 = MaxCountSpec.counter("password_reset_attempts_today", limit: 3)
let spec2 = MaxCountSpec.counter("api_calls_per_hour", limit: 100)

// ❌ Avoid - ambiguous keys
let spec3 = MaxCountSpec.counter("count", limit: 3)  // What count?
let spec4 = MaxCountSpec.counter("limit", limit: 100)  // Confusing
```

### Handle Counter Overflow Gracefully

```swift
// ✅ Good - check before incrementing
if canPerformAction {
    performAction()
    provider.incrementCounter("actions")
} else {
    handleLimitReached()
}

// ❌ Avoid - increment without checking
performAction()
provider.incrementCounter("actions")  // Might exceed limit
```

## Performance Considerations

- **Dictionary Lookup**: O(1) counter access from context
- **No Side Effects**: Read-only evaluation; no state modification
- **Missing Counters**: Returns 0 if counter doesn't exist; no overhead
- **Composition**: Each composition creates new specification; efficient
- **Context Creation**: Provider creates context on each call; lightweight operation

## Topics

### Creating Specifications

- ``init(counterKey:maximumCount:)``
- ``init(counterKey:limit:)``

### Convenience Factories

- ``counter(_:limit:)``
- ``onlyOnce(_:)``
- ``onlyTwice(_:)``
- ``dailyLimit(_:limit:)``
- ``weeklyLimit(_:limit:)``
- ``monthlyLimit(_:limit:)``

### Variant Specifications

- ``inclusive(counterKey:maximumCount:)``
- ``exactly(counterKey:count:)``
- ``inRange(counterKey:range:)``

### Composition

- ``and(_:)``
- ``or(_:)``

### Properties

- ``counterKey``
- ``maximumCount``

### Related Types

- ``EvaluationContext``
- ``DefaultContextProvider``
- ``MockContextProvider``

## See Also

- <doc:EvaluationContext>
- <doc:DefaultContextProvider>
- <doc:CooldownIntervalSpec>
- <doc:TimeSinceEventSpec>
