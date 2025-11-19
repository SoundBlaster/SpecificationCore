# ``SpecificationCore/EvaluationContext``

A context object that holds data needed for specification evaluation.

## Overview

`EvaluationContext` is a value type that serves as a container for all the information specifications might need to make their decisions. It provides structured storage for timestamps, counters, feature flags, events, user data, and segments.

### Key Benefits

- **Structured Data**: Organized storage for different types of runtime data
- **Value Semantics**: Immutable struct with copy-on-write behavior
- **Type Safety**: Strongly-typed access methods with safe defaults
- **Builder Pattern**: Convenient methods for creating modified copies
- **Platform Independent**: Works across all Swift platforms

### When to Use EvaluationContext

Use `EvaluationContext` when you need to:
- Provide runtime data to specifications
- Track counters, flags, and events for business logic
- Pass contextual information through specification evaluation
- Test specifications with controlled context scenarios
- Store user segments and feature toggles

## Quick Example

```swift
import SpecificationCore

// Create a context
let context = EvaluationContext(
    currentDate: Date(),
    flags: ["premium_features": true],
    counters: ["api_calls": 50],
    events: ["last_login": Date()]
)

// Access data
let hasPremium = context.flag(for: "premium_features")  // true
let callCount = context.counter(for: "api_calls")  // 50
let lastLogin = context.event(for: "last_login")  // Date?

// Use with specifications
struct FeatureFlagSpec: Specification {
    let flagKey: String

    func isSatisfiedBy(_ context: EvaluationContext) -> Bool {
        context.flag(for: flagKey)
    }
}

let spec = FeatureFlagSpec(flagKey: "premium_features")
spec.isSatisfiedBy(context)  // true
```

## Context Properties

### Timestamps

```swift
// Current date for time-based evaluations
let context = EvaluationContext(
    currentDate: Date(),
    launchDate: Date().addingTimeInterval(-3600)  // 1 hour ago
)

// Access timestamps
let now = context.currentDate
let launch = context.launchDate
let runtime = context.timeSinceLaunch  // 3600 seconds
```

###Counters

Store and retrieve integer counters:

```swift
let context = EvaluationContext(
    counters: [
        "login_attempts": 3,
        "api_calls_today": 150,
        "items_in_cart": 5
    ]
)

// Safe access with default value
let attempts = context.counter(for: "login_attempts")  // 3
let missing = context.counter(for: "nonexistent")  // 0 (default)

// Use with MaxCountSpec
let spec = MaxCountSpec(counterKey: "login_attempts", maximumCount: 5)
spec.isSatisfiedBy(context)  // true (3 < 5)
```

### Feature Flags

Store and retrieve boolean feature toggles:

```swift
let context = EvaluationContext(
    flags: [
        "dark_mode": true,
        "beta_features": false,
        "analytics_enabled": true
    ]
)

// Safe access with false default
let darkMode = context.flag(for: "dark_mode")  // true
let missing = context.flag(for: "nonexistent")  // false (default)

// Use with feature flag specs
if context.flag(for: "beta_features") {
    // Show beta UI
}
```

### Events

Store and retrieve event timestamps:

```swift
let lastNotification = Date().addingTimeInterval(-7200)  // 2 hours ago

let context = EvaluationContext(
    events: [
        "last_notification": lastNotification,
        "last_purchase": Date().addingTimeInterval(-86400),  // 1 day ago
        "registration_date": Date().addingTimeInterval(-604800)  // 1 week ago
    ]
)

// Access events
let eventDate = context.event(for: "last_notification")  // Date?

// Calculate time since event
if let timeSince = context.timeSinceEvent("last_notification") {
    print("Last notification was \(timeSince) seconds ago")  // 7200
}

// Use with time-based specs
let cooldown = CooldownIntervalSpec(
    eventKey: "last_notification",
    interval: 3600  // 1 hour cooldown
)
cooldown.isSatisfiedBy(context)  // true (7200 > 3600)
```

### User Data

Store arbitrary typed data:

```swift
struct UserProfile {
    let tier: String
    let verified: Bool
}

let profile = UserProfile(tier: "premium", verified: true)

let context = EvaluationContext(
    userData: [
        "user_profile": profile,
        "user_id": "123456",
        "subscription_end": Date().addingTimeInterval(2592000)  // 30 days
    ]
)

// Type-safe access
let userProfile = context.userData(for: "user_profile", as: UserProfile.self)
let userId = context.userData(for: "user_id", as: String.self)
let endDate = context.userData(for: "subscription_end", as: Date.self)

// Use in custom specifications
struct ProfileSpec: Specification {
    func isSatisfiedBy(_ context: EvaluationContext) -> Bool {
        guard let profile = context.userData(for: "user_profile", as: UserProfile.self) else {
            return false
        }
        return profile.tier == "premium" && profile.verified
    }
}
```

### Segments

Store user segments as a set:

```swift
let context = EvaluationContext(
    segments: ["vip", "beta_tester", "early_adopter"]
)

// Check segment membership
let isVIP = context.segments.contains("vip")  // true
let isBeta = context.segments.contains("beta_tester")  // true
let isAdmin = context.segments.contains("admin")  // false

// Use with segment-based specs
struct SegmentSpec: Specification {
    let requiredSegment: String

    func isSatisfiedBy(_ context: EvaluationContext) -> Bool {
        context.segments.contains(requiredSegment)
    }
}
```

## Builder Pattern

Create modified copies of contexts:

```swift
// Start with a base context
let base = EvaluationContext(
    flags: ["feature_a": true],
    counters: ["count": 10]
)

// Create variations using builder methods
let updated = base
    .withFlags(["feature_a": true, "feature_b": true])  // Add more flags
    .withCounters(["count": 11])  // Update counters
    .withCurrentDate(Date())  // Update timestamp

// Each method returns a new context (value semantics)
print(base.counters["count"])  // 10 (unchanged)
print(updated.counters["count"])  // 11 (modified)
```

### Individual Builder Methods

```swift
let context = EvaluationContext()

// Build step by step
let configured = context
    .withFlags(["premium": true, "trial": false])
    .withCounters(["logins": 5])
    .withEvents(["last_action": Date()])
    .withUserData(["user_id": "abc123"])
    .withCurrentDate(Date())

// All builder methods return new contexts
```

## Working with DefaultContextProvider

`EvaluationContext` is typically created by ``DefaultContextProvider``:

```swift
let provider = DefaultContextProvider.shared

// Configure provider state
provider.setFlag("dark_mode", to: true)
provider.setCounter("app_launches", to: 1)
provider.recordEvent("first_launch")

// Get context from provider
let context = provider.currentContext()

// Context contains all configured data
let darkModeEnabled = context.flag(for: "dark_mode")  // true
let launches = context.counter(for: "app_launches")  // 1
let firstLaunch = context.event(for: "first_launch")  // Date
```

## Testing with EvaluationContext

Create test contexts with specific scenarios:

```swift
// Test counter limits
let limitContext = EvaluationContext(
    counters: ["attempts": 5]
)

let limitSpec = MaxCountSpec(counterKey: "attempts", maximumCount: 3)
XCTAssertFalse(limitSpec.isSatisfiedBy(limitContext))  // 5 > 3

// Test cooldown periods
let cooldownContext = EvaluationContext(
    currentDate: Date(),
    events: ["last_action": Date().addingTimeInterval(-1800)]  // 30 min ago
)

let cooldownSpec = CooldownIntervalSpec(
    eventKey: "last_action",
    interval: 3600  // 1 hour
)
XCTAssertFalse(cooldownSpec.isSatisfiedBy(cooldownContext))  // 1800 < 3600

// Test feature flags
let flagContext = EvaluationContext(
    flags: ["new_ui": false]
)

let flagSpec = FeatureFlagSpec(flagKey: "new_ui")
XCTAssertFalse(flagSpec.isSatisfiedBy(flagContext))
```

## Time-Based Evaluations

Use context timestamps for time-dependent logic:

```swift
let context = EvaluationContext(
    currentDate: Date(),
    launchDate: Date().addingTimeInterval(-120)  // 2 minutes ago
)

// Check runtime
if context.timeSinceLaunch > 60 {
    print("App running for more than 1 minute")
}

// Use calendar for date logic
let calendar = context.calendar
let hour = calendar.component(.hour, from: context.currentDate)

if hour >= 22 || hour < 6 {
    print("Night time")
}

// Time zone awareness
let timeZone = context.timeZone
print("Current timezone: \(timeZone.identifier)")
```

## Combining Context Data

Combine different context types in specifications:

```swift
struct ComplexEligibilitySpec: Specification {
    func isSatisfiedBy(_ context: EvaluationContext) -> Bool {
        // Check multiple context aspects
        let hasPremium = context.flag(for: "premium_user")
        let withinLimit = context.counter(for: "api_calls") < 1000

        guard let lastUse = context.event(for: "last_api_call"),
              let timeSince = context.timeSinceEvent("last_api_call") else {
            return false
        }

        let notOnCooldown = timeSince > 60  // 1 minute

        return hasPremium && withinLimit && notOnCooldown
    }
}
```

## Best Practices

### Use Appropriate Storage Types

```swift
// ✅ Good - use the right storage type
let context = EvaluationContext(
    flags: ["is_enabled": true],           // Boolean → flags
    counters: ["count": 42],               // Integer → counters
    events: ["timestamp": Date()],         // Date → events
    userData: ["object": customData]       // Other types → userData
)

// ❌ Avoid - misusing storage types
let bad = EvaluationContext(
    userData: [
        "is_enabled": true,  // Should be a flag
        "count": 42          // Should be a counter
    ]
)
```

### Provide Sensible Defaults

```swift
// ✅ Good - handle missing data gracefully
let count = context.counter(for: "attempts")  // Returns 0 if missing
let hasFlag = context.flag(for: "feature")    // Returns false if missing

// ❌ Avoid - assuming data exists
let userData = context.userData["key"]!  // Crashes if missing
```

### Use Builder Pattern for Test Contexts

```swift
// ✅ Good - clear test setup
func testPremiumFeatures() {
    let context = EvaluationContext()
        .withFlags(["premium": true])
        .withCounters(["usage": 5])

    XCTAssertTrue(premiumSpec.isSatisfiedBy(context))
}

// ❌ Verbose - manual construction
func testPremiumFeatures() {
    let context = EvaluationContext(
        currentDate: Date(),
        launchDate: Date(),
        userData: [:],
        counters: ["usage": 5],
        events: [:],
        flags: ["premium": true],
        segments: []
    )
}
```

## Performance Considerations

- **Value Semantics**: Context is a struct; copying is efficient via copy-on-write
- **Immutability**: Contexts are immutable; modifications create new instances
- **Safe Defaults**: Missing data returns safe defaults (0, false, nil) without overhead
- **Dictionary Lookups**: Data access is O(1) but incurs dictionary overhead
- **Builder Methods**: Each builder method creates a new context; chain wisely

## Topics

### Creating Contexts

- ``init(currentDate:launchDate:userData:counters:events:flags:segments:)``

### Properties

- ``currentDate``
- ``launchDate``
- ``userData``
- ``counters``
- ``events``
- ``flags``
- ``segments``

### Convenience Properties

- ``timeSinceLaunch``
- ``calendar``
- ``timeZone``

### Data Access

- ``counter(for:)``
- ``event(for:)``
- ``flag(for:)``
- ``userData(for:as:)``
- ``timeSinceEvent(_:)``

### Builder Methods

- ``withUserData(_:)``
- ``withCounters(_:)``
- ``withEvents(_:)``
- ``withFlags(_:)``
- ``withCurrentDate(_:)``

### Related Types

- ``DefaultContextProvider``
- ``MockContextProvider``
- ``ContextProviding``

## See Also

- <doc:DefaultContextProvider>
- <doc:MockContextProvider>
- <doc:ContextProviding>
