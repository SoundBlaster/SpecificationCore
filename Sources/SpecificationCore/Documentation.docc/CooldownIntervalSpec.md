# ``SpecificationCore/CooldownIntervalSpec``

A specification that ensures enough time has passed since the last occurrence of an event.

## Overview

`CooldownIntervalSpec` implements cooldown periods for actions like showing banners, notifications, or any time-sensitive operations that shouldn't happen too frequently. It evaluates to true when sufficient time has elapsed since an event was last recorded.

### Key Benefits

- **Time-Based Throttling**: Prevent actions from occurring too frequently
- **Flexible Time Units**: Create cooldowns in seconds, minutes, hours, or days
- **Event Tracking**: Works with ``EvaluationContext`` event timestamps
- **Utility Methods**: Calculate remaining time and next allowed execution
- **Advanced Patterns**: Exponential backoff and time-of-day based cooldowns

### When to Use CooldownIntervalSpec

Use `CooldownIntervalSpec` when you need to:
- Prevent notifications from appearing too frequently
- Implement rate limiting for user actions
- Control banner or popup display frequency
- Enforce minimum time between retries
- Throttle API calls or expensive operations

## Quick Example

```swift
import SpecificationCore

// Set up context and record event
let provider = DefaultContextProvider.shared
provider.recordEvent("last_notification")

// Create 1-hour cooldown spec
let notificationCooldown = CooldownIntervalSpec(
    eventKey: "last_notification",
    hours: 1
)

// Use with property wrapper
@Satisfies(using: notificationCooldown)
var canShowNotification: Bool

if canShowNotification {
    showNotification()
    provider.recordEvent("last_notification")  // Reset cooldown
}
```

## Creating CooldownIntervalSpec

### Basic Creation

```swift
// Create with TimeInterval (seconds)
let cooldown1 = CooldownIntervalSpec(
    eventKey: "last_action",
    cooldownInterval: 3600  // 1 hour in seconds
)

// Or use time unit convenience initializers
let cooldown2 = CooldownIntervalSpec(
    eventKey: "last_action",
    seconds: 60
)
```

### Time Unit Initializers

```swift
// Seconds
let shortCooldown = CooldownIntervalSpec(
    eventKey: "button_click",
    seconds: 5
)

// Minutes
let mediumCooldown = CooldownIntervalSpec(
    eventKey: "form_submit",
    minutes: 15
)

// Hours
let longCooldown = CooldownIntervalSpec(
    eventKey: "daily_reminder",
    hours: 24
)

// Days
let veryLongCooldown = CooldownIntervalSpec(
    eventKey: "weekly_survey",
    days: 7
)
```

### Convenience Factories

```swift
// Common time periods
let hourly = CooldownIntervalSpec.hourly("api_call")
let daily = CooldownIntervalSpec.daily("notification")
let weekly = CooldownIntervalSpec.weekly("newsletter")
let monthly = CooldownIntervalSpec.monthly("report")

// Custom interval
let custom = CooldownIntervalSpec.custom(
    "custom_event",
    interval: 90  // 90 seconds
)
```

## How It Works

The specification checks if enough time has passed since the event:

```swift
let cooldown = CooldownIntervalSpec(eventKey: "last_shown", hours: 1)

// Event never occurred: satisfied ✅ (no cooldown needed)
// Event 30 minutes ago: NOT satisfied ❌ (still on cooldown)
// Event 1 hour ago: satisfied ✅ (cooldown expired)
// Event 2 hours ago: satisfied ✅ (cooldown long expired)
```

## Usage Examples

### Notification Throttling

```swift
let provider = DefaultContextProvider.shared

// Create notification cooldown (1 hour)
let notificationCooldown = CooldownIntervalSpec(
    eventKey: "last_notification_shown",
    hours: 1
)

@Satisfies(using: notificationCooldown)
var canShowNotification: Bool

func showImportantNotification(_ message: String) {
    guard canShowNotification else {
        print("Notification on cooldown")
        return
    }

    displayNotification(message)
    provider.recordEvent("last_notification_shown")
}
```

### Banner Display Control

```swift
// Show promotional banner maximum once per day
let bannerCooldown = CooldownIntervalSpec.daily("promo_banner_shown")

@Satisfies(using: bannerCooldown)
var shouldShowBanner: Bool

struct ContentView: View {
    var body: some View {
        VStack {
            if shouldShowBanner {
                PromoBanner()
                    .onTapGesture {
                        DefaultContextProvider.shared
                            .recordEvent("promo_banner_shown")
                    }
            }
            MainContent()
        }
    }
}
```

### Retry Logic

```swift
// Minimum 5 minutes between retry attempts
let retryCooldown = CooldownIntervalSpec(
    eventKey: "last_retry_attempt",
    minutes: 5
)

@Satisfies(using: retryCooldown)
var canRetry: Bool

func retryFailedOperation() async {
    guard canRetry else {
        showError("Please wait before retrying")
        return
    }

    await performOperation()
    DefaultContextProvider.shared.recordEvent("last_retry_attempt")
}
```

### API Rate Limiting

```swift
// Minimum 10 seconds between API calls
let apiCooldown = CooldownIntervalSpec(
    eventKey: "last_api_call",
    seconds: 10
)

@Satisfies(using: apiCooldown)
var canCallAPI: Bool

func fetchData() async throws -> Data {
    guard canCallAPI else {
        throw APIError.tooManyRequests
    }

    let data = try await performAPICall()
    DefaultContextProvider.shared.recordEvent("last_api_call")
    return data
}
```

## Utility Methods

### Remaining Cooldown Time

```swift
let cooldown = CooldownIntervalSpec(eventKey: "last_action", minutes: 30)
let context = DefaultContextProvider.shared.currentContext()

// Get remaining time in seconds
let remaining = cooldown.remainingCooldownTime(in: context)

if remaining > 0 {
    print("Wait \(Int(remaining)) seconds before next action")
} else {
    print("Action available now")
}
```

### Check if Cooldown is Active

```swift
let cooldown = CooldownIntervalSpec.hourly("feature_use")
let context = provider.currentContext()

if cooldown.isCooldownActive(in: context) {
    print("Feature is on cooldown")
} else {
    print("Feature is available")
}
```

### Next Allowed Time

```swift
let cooldown = CooldownIntervalSpec(eventKey: "survey_shown", days: 7)
let context = provider.currentContext()

if let nextTime = cooldown.nextAllowedTime(in: context) {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short

    print("Available again at: \(formatter.string(from: nextTime))")
} else {
    print("Available now")
}
```

## Advanced Patterns

### Exponential Backoff

Increase cooldown time with each occurrence:

```swift
// Base 60 seconds, doubles with each attempt
let backoffSpec = CooldownIntervalSpec.exponentialBackoff(
    eventKey: "failed_login",
    baseInterval: 60,  // 1 minute
    counterKey: "login_attempts",
    maxInterval: 3600  // Max 1 hour
)

// Attempt 1: 60 seconds
// Attempt 2: 120 seconds
// Attempt 3: 240 seconds
// Attempt 4: 480 seconds
// Attempt 5: 960 seconds
// Attempt 6+: 3600 seconds (capped)

@Satisfies(using: backoffSpec)
var canAttemptLogin: Bool
```

### Time-of-Day Based Cooldowns

Different cooldowns for day vs. night:

```swift
// 30 minutes during day, 2 hours at night
let timeBasedCooldown = CooldownIntervalSpec.timeOfDayBased(
    eventKey: "notification",
    daytimeInterval: .minutes(30),
    nighttimeInterval: .hours(2),
    daytimeHours: 8...22  // 8 AM to 10 PM
)

// Notification at 3 PM: 30-minute cooldown
// Notification at 11 PM: 2-hour cooldown
```

## Composition

Combine with other cooldowns or specifications:

### Multiple Cooldowns (AND)

```swift
// Both cooldowns must be satisfied
let strictCooldown = CooldownIntervalSpec.hourly("feature_a")
    .and(CooldownIntervalSpec.daily("feature_b"))

// Feature A: must be > 1 hour since last use
// Feature B: must be > 1 day since last use
// Both must be satisfied
```

### Multiple Cooldowns (OR)

```swift
// Either cooldown can be satisfied
let flexibleCooldown = CooldownIntervalSpec.weekly("method_a")
    .or(CooldownIntervalSpec.monthly("method_b"))

// Can proceed if EITHER weekly OR monthly cooldown expired
```

### With Other Specifications

```swift
// Cooldown AND feature flag
let gatedFeature = CooldownIntervalSpec.daily("premium_feature")
    .and(FeatureFlagSpec(flagKey: "premium_enabled"))

// Must pass cooldown AND have feature enabled
```

## Real-World Examples

### Survey Prompts

```swift
struct SurveyPromptManager {
    let provider = DefaultContextProvider.shared

    // Show survey once per month
    let surveyCooldown = CooldownIntervalSpec.monthly("survey_shown")

    // Also require minimum app usage
    let usageRequirement = TimeSinceEventSpec(
        eventKey: "app_first_launch",
        days: 7
    )

    var shouldShowSurvey: Bool {
        let context = provider.currentContext()
        return surveyCooldown.isSatisfiedBy(context) &&
               usageRequirement.isSatisfiedBy(context)
    }

    func showSurvey() {
        guard shouldShowSurvey else { return }

        presentSurveyModal()
        provider.recordEvent("survey_shown")
    }
}
```

### Push Notification Management

```swift
class NotificationManager {
    let provider = DefaultContextProvider.shared

    // Different cooldowns for different notification types
    let criticalCooldown = CooldownIntervalSpec(eventKey: "critical_alert", minutes: 5)
    let standardCooldown = CooldownIntervalSpec(eventKey: "standard_notif", hours: 1)
    let marketingCooldown = CooldownIntervalSpec(eventKey: "marketing_notif", days: 1)

    func canSend(notification: Notification) -> Bool {
        let context = provider.currentContext()

        switch notification.type {
        case .critical:
            return criticalCooldown.isSatisfiedBy(context)
        case .standard:
            return standardCooldown.isSatisfiedBy(context)
        case .marketing:
            return marketingCooldown.isSatisfiedBy(context)
        }
    }

    func send(_ notification: Notification) {
        guard canSend(notification: notification) else {
            print("Notification throttled")
            return
        }

        deliverNotification(notification)

        // Record event based on type
        let eventKey: String
        switch notification.type {
        case .critical: eventKey = "critical_alert"
        case .standard: eventKey = "standard_notif"
        case .marketing: eventKey = "marketing_notif"
        }

        provider.recordEvent(eventKey)
    }
}
```

### Feature Usage Throttling

```swift
class PremiumFeatureGate {
    let provider = DefaultContextProvider.shared

    // Premium users: 1-hour cooldown
    // Free users: 24-hour cooldown
    func getCooldown(for tier: UserTier) -> CooldownIntervalSpec {
        switch tier {
        case .premium:
            return .hourly("ai_generation")
        case .free:
            return .daily("ai_generation")
        }
    }

    func canUseFeature(user: User) -> Bool {
        let cooldown = getCooldown(for: user.tier)
        let context = provider.currentContext()
        return cooldown.isSatisfiedBy(context)
    }

    func useFeature(user: User) async throws -> Result {
        guard canUseFeature(user: user) else {
            let cooldown = getCooldown(for: user.tier)
            let remaining = cooldown.remainingCooldownTime(
                in: provider.currentContext()
            )

            throw FeatureError.onCooldown(
                remainingSeconds: Int(remaining)
            )
        }

        let result = try await performFeature()
        provider.recordEvent("ai_generation")
        return result
    }
}
```

## Testing

Use ``MockContextProvider`` to test cooldown behavior:

```swift
func testCooldownNotExpired() {
    // Event occurred 30 minutes ago
    let provider = MockContextProvider.cooldownScenario(
        eventKey: "last_action",
        timeSinceEvent: 1800  // 30 minutes
    )

    let spec = CooldownIntervalSpec(eventKey: "last_action", hours: 1)

    // Should be on cooldown (30 min < 1 hour)
    XCTAssertFalse(spec.isSatisfiedBy(provider.currentContext()))
}

func testCooldownExpired() {
    // Event occurred 2 hours ago
    let provider = MockContextProvider.cooldownScenario(
        eventKey: "last_action",
        timeSinceEvent: 7200  // 2 hours
    )

    let spec = CooldownIntervalSpec(eventKey: "last_action", hours: 1)

    // Should be available (2 hours > 1 hour)
    XCTAssertTrue(spec.isSatisfiedBy(provider.currentContext()))
}

func testNoEventRecorded() {
    // No event recorded
    let provider = MockContextProvider()

    let spec = CooldownIntervalSpec.hourly("never_happened")

    // Should be satisfied (no previous event)
    XCTAssertTrue(spec.isSatisfiedBy(provider.currentContext()))
}

func testRemainingTime() {
    let now = Date()
    let thirtyMinutesAgo = now.addingTimeInterval(-1800)

    let provider = MockContextProvider()
        .withCurrentDate(now)
        .withEvent("action", date: thirtyMinutesAgo)

    let spec = CooldownIntervalSpec(eventKey: "action", hours: 1)

    let remaining = spec.remainingCooldownTime(in: provider.currentContext())

    // Should have ~30 minutes remaining (1800 seconds)
    XCTAssertEqual(remaining, 1800, accuracy: 1.0)
}
```

## Best Practices

### Record Events Immediately After Actions

```swift
// ✅ Good - record event after action completes
if canShowNotification {
    showNotification()
    provider.recordEvent("last_notification")
}

// ❌ Avoid - recording before action
provider.recordEvent("last_notification")
showNotification()  // Might fail, but cooldown already started
```

### Use Appropriate Time Units

```swift
// ✅ Good - use readable time units
let hourly = CooldownIntervalSpec(eventKey: "api_call", hours: 1)
let daily = CooldownIntervalSpec(eventKey: "report", days: 1)

// ❌ Less readable - raw seconds
let hourly = CooldownIntervalSpec(eventKey: "api_call", seconds: 3600)
let daily = CooldownIntervalSpec(eventKey: "report", seconds: 86400)
```

### Provide User Feedback

```swift
// ✅ Good - inform user of remaining time
if !canPerformAction {
    let remaining = cooldown.remainingCooldownTime(in: context)
    let minutes = Int(remaining / 60)
    showAlert("Please wait \(minutes) minutes before trying again")
}

// ❌ Avoid - silent failure
if !canPerformAction {
    return  // User doesn't know why
}
```

### Use Consistent Event Keys

```swift
// ✅ Good - descriptive, consistent naming
"last_notification_shown"
"last_api_call_made"
"last_password_reset_attempt"

// ❌ Avoid - ambiguous or inconsistent
"notif"
"api"
"reset"
```

## Performance Considerations

- **Event Lookup**: O(1) dictionary access from context
- **Date Arithmetic**: Simple subtraction; very fast
- **No State Mutation**: Read-only evaluation
- **Missing Events**: Returns true (satisfied) if event not found
- **Utility Methods**: Calculate on-demand; no caching overhead

## Topics

### Creating Specifications

- ``init(eventKey:cooldownInterval:)``
- ``init(eventKey:seconds:)``
- ``init(eventKey:minutes:)``
- ``init(eventKey:hours:)``
- ``init(eventKey:days:)``

### Convenience Factories

- ``hourly(_:)``
- ``daily(_:)``
- ``weekly(_:)``
- ``monthly(_:)``
- ``custom(_:interval:)``

### Utility Methods

- ``remainingCooldownTime(in:)``
- ``isCooldownActive(in:)``
- ``nextAllowedTime(in:)``

### Advanced Patterns

- ``exponentialBackoff(eventKey:baseInterval:counterKey:maxInterval:)``
- ``timeOfDayBased(eventKey:daytimeInterval:nighttimeInterval:daytimeHours:)``

### Composition

- ``and(_:)``
- ``or(_:)``

### Properties

- ``eventKey``
- ``cooldownInterval``

## See Also

- <doc:TimeSinceEventSpec>
- <doc:MaxCountSpec>
- <doc:EvaluationContext>
- <doc:DefaultContextProvider>
