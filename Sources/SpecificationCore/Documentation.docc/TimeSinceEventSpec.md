# ``SpecificationCore/TimeSinceEventSpec``

A specification that checks if a minimum duration has passed since a specific event.

## Overview

`TimeSinceEventSpec` verifies that sufficient time has elapsed since an event was recorded. It's useful for implementing delays, cooldown periods, or time-based restrictions where you need to ensure a minimum time has passed before allowing an action.

### Key Benefits

- **Minimum Time Enforcement**: Ensure enough time has passed before proceeding
- **Flexible Time Units**: Specify durations in seconds, minutes, hours, or days
- **Event-Based Tracking**: Works with ``EvaluationContext`` event timestamps
- **App Launch Tracking**: Special support for time since app launch
- **Readable API**: Clear, expressive time unit extensions

### When to Use TimeSinceEventSpec

Use `TimeSinceEventSpec` when you need to:
- Enforce minimum wait times between actions
- Delay feature availability after onboarding
- Implement tutorial or welcome flows
- Check if enough time has passed since user registration
- Verify minimum session duration

## Quick Example

```swift
import SpecificationCore

// Record user registration
let provider = DefaultContextProvider.shared
provider.recordEvent("user_registered")

// Check if user has been registered for at least 7 days
let eligibilitySpec = TimeSinceEventSpec(
    eventKey: "user_registered",
    days: 7
)

@Satisfies(using: eligibilitySpec)
var isEligibleForReward: Bool

if isEligibleForReward {
    grantLoyaltyReward()
}
```

## Creating TimeSinceEventSpec

### Basic Creation

```swift
// With TimeInterval (seconds)
let spec1 = TimeSinceEventSpec(
    eventKey: "first_launch",
    minimumInterval: 300  // 5 minutes
)

// With time unit convenience init
let spec2 = TimeSinceEventSpec(
    eventKey: "first_launch",
    minutes: 5
)
```

### Time Unit Initializers

```swift
// Seconds
let shortDelay = TimeSinceEventSpec(
    eventKey: "tutorial_started",
    seconds: 30
)

// Minutes
let mediumDelay = TimeSinceEventSpec(
    eventKey: "onboarding_completed",
    minutes: 15
)

// Hours
let longDelay = TimeSinceEventSpec(
    eventKey: "account_created",
    hours: 24
)

// Days
let veryLongDelay = TimeSinceEventSpec(
    eventKey: "user_registered",
    days: 30
)
```

## How It Works

The specification checks if enough time has passed since the event:

```swift
let spec = TimeSinceEventSpec(eventKey: "action", hours: 1)

// Event never occurred: satisfied ✅ (no wait needed)
// Event 30 minutes ago: NOT satisfied ❌ (not enough time)
// Event 1 hour ago: satisfied ✅ (exactly enough time)
// Event 2 hours ago: satisfied ✅ (more than enough time)
```

## Usage Examples

### Onboarding Delay

```swift
// Record when user completes onboarding
provider.recordEvent("onboarding_completed")

// Show advanced features after 1 hour of app use
let advancedFeaturesSpec = TimeSinceEventSpec(
    eventKey: "onboarding_completed",
    hours: 1
)

@Satisfies(using: advancedFeaturesSpec)
var canShowAdvancedFeatures: Bool

if canShowAdvancedFeatures {
    showAdvancedTutorial()
}
```

### Loyalty Program Eligibility

```swift
// Check if user has been member for 30 days
let loyaltySpec = TimeSinceEventSpec(
    eventKey: "user_registered",
    days: 30
)

@Satisfies(using: loyaltySpec)
var isLoyaltyEligible: Bool

func checkLoyaltyRewards() {
    if isLoyaltyEligible {
        unlockLoyaltyTier()
    } else {
        showIneligibleMessage()
    }
}
```

### Trial Period Verification

```swift
// Check if trial period has expired (14 days)
let trialSpec = TimeSinceEventSpec(
    eventKey: "trial_started",
    days: 14
)

@Satisfies(using: trialSpec)
var isTrialExpired: Bool

if isTrialExpired {
    showUpgradePrompt()
}
```

### Feature Unlock Timing

```swift
// Unlock advanced features after 3 days of usage
let featureUnlockSpec = TimeSinceEventSpec(
    eventKey: "app_first_launch",
    days: 3
)

@Satisfies(using: featureUnlockSpec)
var canAccessAdvancedFeatures: Bool

struct FeatureView: View {
    var body: some View {
        if canAccessAdvancedFeatures {
            AdvancedFeaturePanel()
        } else {
            LockedFeatureMessage()
        }
    }
}
```

## App Launch Tracking

Special support for checking time since app launch:

```swift
// Minimum 5 minutes since launch
let launchDelaySpec = TimeSinceEventSpec.sinceAppLaunch(minutes: 5)

@Satisfies(using: launchDelaySpec)
var hasBeenRunningLongEnough: Bool

// Show rating prompt after app has been open for a while
if hasBeenRunningLongEnough {
    showRatingPrompt()
}
```

### Available App Launch Methods

```swift
// Seconds
let spec1 = TimeSinceEventSpec.sinceAppLaunch(seconds: 30)

// Minutes
let spec2 = TimeSinceEventSpec.sinceAppLaunch(minutes: 5)

// Hours
let spec3 = TimeSinceEventSpec.sinceAppLaunch(hours: 1)

// Days
let spec4 = TimeSinceEventSpec.sinceAppLaunch(days: 1)
```

## TimeInterval Extensions

Readable time constants for specifications:

```swift
import SpecificationCore

// Use TimeInterval extension methods
let spec1 = TimeSinceEventSpec(
    eventKey: "action",
    minimumInterval: .seconds(30)
)

let spec2 = TimeSinceEventSpec(
    eventKey: "action",
    minimumInterval: .minutes(5)
)

let spec3 = TimeSinceEventSpec(
    eventKey: "action",
    minimumInterval: .hours(2)
)

let spec4 = TimeSinceEventSpec(
    eventKey: "action",
    minimumInterval: .days(7)
)

let spec5 = TimeSinceEventSpec(
    eventKey: "action",
    minimumInterval: .weeks(2)
)
```

## Real-World Examples

### Welcome Flow Timing

```swift
class WelcomeFlowManager {
    let provider = DefaultContextProvider.shared

    // Show different welcome messages based on time since registration
    let newUserSpec = TimeSinceEventSpec(
        eventKey: "user_registered",
        days: 0  // Just registered
    )

    let weekOldSpec = TimeSinceEventSpec(
        eventKey: "user_registered",
        days: 7
    )

    let monthOldSpec = TimeSinceEventSpec(
        eventKey: "user_registered",
        days: 30
    )

    func getWelcomeMessage() -> String {
        let context = provider.currentContext()

        if !newUserSpec.isSatisfiedBy(context) {
            return "Welcome! Let's get started."
        } else if !weekOldSpec.isSatisfiedBy(context) {
            return "Welcome back! Enjoying the app?"
        } else if !monthOldSpec.isSatisfiedBy(context) {
            return "Thanks for sticking with us!"
        } else {
            return "Welcome back, valued member!"
        }
    }
}
```

### Progressive Feature Disclosure

```swift
struct FeatureGate {
    let provider = DefaultContextProvider.shared

    // Unlock features progressively over time
    enum Feature {
        case basic
        case intermediate
        case advanced
        case expert

        var unlockSpec: TimeSinceEventSpec {
            switch self {
            case .basic:
                return TimeSinceEventSpec(
                    eventKey: "app_first_launch",
                    days: 0  // Immediate
                )
            case .intermediate:
                return TimeSinceEventSpec(
                    eventKey: "app_first_launch",
                    days: 3
                )
            case .advanced:
                return TimeSinceEventSpec(
                    eventKey: "app_first_launch",
                    days: 7
                )
            case .expert:
                return TimeSinceEventSpec(
                    eventKey: "app_first_launch",
                    days: 14
                )
            }
        }
    }

    func isUnlocked(_ feature: Feature) -> Bool {
        let context = provider.currentContext()
        return feature.unlockSpec.isSatisfiedBy(context)
    }
}
```

### Rating Prompt Strategy

```swift
class RatingPromptManager {
    let provider = DefaultContextProvider.shared

    // Wait for 7 days AND 10+ sessions before asking for rating
    let timeRequirement = TimeSinceEventSpec(
        eventKey: "app_first_launch",
        days: 7
    )

    let usageRequirement = MaxCountSpec(
        counterKey: "app_sessions",
        maximumCount: 10
    ).not()  // More than 10 sessions

    var shouldPromptForRating: Bool {
        let context = provider.currentContext()
        return timeRequirement.isSatisfiedBy(context) &&
               usageRequirement.isSatisfiedBy(context)
    }

    func promptIfAppropriate() {
        guard shouldPromptForRating else { return }

        requestAppStoreReview()
        // Record to prevent repeated prompts
        provider.recordEvent("rating_prompted")
    }
}
```

### Subscription Grace Period

```swift
class SubscriptionManager {
    let provider = DefaultContextProvider.shared

    // Allow 3-day grace period after subscription expiration
    let gracePeriodSpec = TimeSinceEventSpec(
        eventKey: "subscription_expired",
        days: 3
    ).not()  // NOT yet 3 days past expiration

    var isInGracePeriod: Bool {
        let context = provider.currentContext()
        return gracePeriodSpec.isSatisfiedBy(context)
    }

    func checkAccess() -> AccessLevel {
        if isActiveSubscription {
            return .full
        } else if isInGracePeriod {
            return .grace
        } else {
            return .expired
        }
    }
}
```

## Testing

Test time-based logic with ``MockContextProvider``:

```swift
func testRecentEvent() {
    // Event occurred 5 minutes ago
    let fiveMinutesAgo = Date().addingTimeInterval(-300)

    let provider = MockContextProvider()
        .withEvent("action", date: fiveMinutesAgo)

    let spec = TimeSinceEventSpec(eventKey: "action", minutes: 10)

    // Should NOT be satisfied (5 min < 10 min)
    XCTAssertFalse(spec.isSatisfiedBy(provider.currentContext()))
}

func testOldEvent() {
    // Event occurred 1 hour ago
    let oneHourAgo = Date().addingTimeInterval(-3600)

    let provider = MockContextProvider()
        .withEvent("action", date: oneHourAgo)

    let spec = TimeSinceEventSpec(eventKey: "action", minutes: 30)

    // Should be satisfied (60 min > 30 min)
    XCTAssertTrue(spec.isSatisfiedBy(provider.currentContext()))
}

func testNoEvent() {
    let provider = MockContextProvider()

    let spec = TimeSinceEventSpec(eventKey: "never_happened", hours: 1)

    // Should be satisfied (no event = no wait required)
    XCTAssertTrue(spec.isSatisfiedBy(provider.currentContext()))
}

func testAppLaunchTiming() {
    // App launched 10 minutes ago
    let provider = MockContextProvider.launchDelayScenario(
        timeSinceLaunch: 600  // 10 minutes
    )

    let spec = TimeSinceEventSpec.sinceAppLaunch(minutes: 5)

    // Should be satisfied (10 min > 5 min)
    XCTAssertTrue(spec.isSatisfiedBy(provider.currentContext()))
}
```

## Best Practices

### Use Readable Time Units

```swift
// ✅ Good - clear intent
let spec = TimeSinceEventSpec(eventKey: "registration", days: 30)

// ❌ Less clear - requires mental calculation
let spec = TimeSinceEventSpec(eventKey: "registration", seconds: 2592000)
```

### Record Events at Appropriate Times

```swift
// ✅ Good - record when event actually occurs
func completeOnboarding() {
    finishOnboarding()
    provider.recordEvent("onboarding_completed")
}

// ❌ Avoid - recording before event completes
func completeOnboarding() {
    provider.recordEvent("onboarding_completed")
    finishOnboarding()  // Might fail
}
```

### Choose Appropriate Minimum Times

```swift
// ✅ Good - reasonable timeframes
let newUserPeriod = TimeSinceEventSpec(eventKey: "registered", days: 7)
let trialPeriod = TimeSinceEventSpec(eventKey: "trial_start", days: 14)

// ❌ Avoid - unreasonable timeframes
let newUserPeriod = TimeSinceEventSpec(eventKey: "registered", seconds: 10)
```

### Use Descriptive Event Keys

```swift
// ✅ Good - clear, specific keys
"user_registered"
"onboarding_completed"
"subscription_started"

// ❌ Avoid - ambiguous keys
"event1"
"start"
"done"
```

## Comparison with CooldownIntervalSpec

`TimeSinceEventSpec` and ``CooldownIntervalSpec`` are similar but have different use cases:

### TimeSinceEventSpec
- **Purpose**: Verify minimum time has passed
- **Returns True When**: Event never occurred OR enough time has passed
- **Use For**: One-time delays, eligibility checks, progressive disclosure

### CooldownIntervalSpec
- **Purpose**: Enforce cooldown periods for repeated actions
- **Returns True When**: Event never occurred OR cooldown has expired
- **Use For**: Throttling, rate limiting, notification control

```swift
// TimeSinceEventSpec: "Has it been at least X time since Y?"
let eligibility = TimeSinceEventSpec(
    eventKey: "user_registered",
    days: 30
)

// CooldownIntervalSpec: "Can we do X again? (enough time since last time)"
let canNotify = CooldownIntervalSpec(
    eventKey: "last_notification",
    hours: 1
)
```

## Performance Considerations

- **Event Lookup**: O(1) dictionary access
- **Date Arithmetic**: Simple subtraction operation
- **No Side Effects**: Read-only evaluation
- **Missing Events**: Returns true immediately
- **Context Creation**: Lightweight operation

## Topics

### Creating Specifications

- ``init(eventKey:minimumInterval:)``
- ``init(eventKey:seconds:)``
- ``init(eventKey:minutes:)``
- ``init(eventKey:hours:)``
- ``init(eventKey:days:)``

### App Launch Tracking

- ``sinceAppLaunch(minimumInterval:)``
- ``sinceAppLaunch(seconds:)``
- ``sinceAppLaunch(minutes:)``
- ``sinceAppLaunch(hours:)``
- ``sinceAppLaunch(days:)``

### Properties

- ``eventKey``
- ``minimumInterval``

### Related Types

- ``EvaluationContext``
- ``DefaultContextProvider``
- ``MockContextProvider``
- ``CooldownIntervalSpec``

## See Also

- <doc:CooldownIntervalSpec>
- <doc:DateRangeSpec>
- <doc:DateComparisonSpec>
- <doc:EvaluationContext>
