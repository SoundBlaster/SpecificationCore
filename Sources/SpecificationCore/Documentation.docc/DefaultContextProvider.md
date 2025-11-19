# ``SpecificationCore/DefaultContextProvider``

A thread-safe context provider that maintains application-wide state for specification evaluation.

## Overview

`DefaultContextProvider` is the primary context provider in SpecificationCore, designed to manage counters, feature flags, events, and user data that specifications use for evaluation. It provides a shared singleton instance and supports reactive updates through Combine publishers.

### Key Features

- **Thread-Safe**: All operations protected by locks for concurrent access
- **Reactive Updates**: Publishes changes via Combine when state mutates
- **Flexible Storage**: Supports counters, flags, events, and arbitrary user data
- **Singleton Pattern**: Provides a shared instance for application-wide state
- **Async Support**: Both sync and async context access methods

### When to Use DefaultContextProvider

Use `DefaultContextProvider` when you need to:
- Maintain application-wide specification context
- Track counters, events, and feature flags
- Provide dynamic context to specifications at runtime
- Enable reactive specification evaluation in SwiftUI
- Share context state across your application

## Quick Example

```swift
import SpecificationCore

// Use the shared instance
let provider = DefaultContextProvider.shared

// Configure state
provider.setFlag("premium_features", to: true)
provider.setCounter("api_calls", to: 50)
provider.recordEvent("last_login")

// Get context for specifications
let context = provider.currentContext()

// Use with specifications
@Satisfies(using: FeatureFlagSpec(flagKey: "premium_features"))
var showPremiumFeatures: Bool
```

## Shared Singleton

Access the application-wide shared instance:

```swift
// Shared instance available throughout the app
let provider = DefaultContextProvider.shared

// Configure once, use everywhere
provider.setFlag("dark_mode", to: true)
provider.setCounter("app_launches", to: 1)

// All specifications use the same shared state
@Satisfies(using: FeatureFlagSpec(flagKey: "dark_mode"))
var useDarkMode: Bool  // Reads from shared instance
```

## Custom Instances

Create isolated instances for testing or module-specific state:

```swift
// Create a separate instance
let testProvider = DefaultContextProvider()
testProvider.setFlag("test_mode", to: true)

// Use in specific contexts
class FeatureService {
    let contextProvider: DefaultContextProvider

    init(contextProvider: DefaultContextProvider = .shared) {
        self.contextProvider = contextProvider
    }

    func checkFeature() -> Bool {
        let context = contextProvider.currentContext()
        return context.flag(for: "feature_enabled")
    }
}

// Production uses shared
let prodService = FeatureService()

// Tests use isolated instance
let testService = FeatureService(contextProvider: testProvider)
```

## Counter Management

Track and manipulate integer counters:

### Setting Counters

```swift
let provider = DefaultContextProvider.shared

// Set counter to specific value
provider.setCounter("login_attempts", to: 3)
provider.setCounter("api_calls_today", to: 100)
provider.setCounter("items_viewed", to: 0)
```

### Incrementing Counters

```swift
// Increment by 1 (default)
provider.incrementCounter("page_views")

// Increment by specific amount
provider.incrementCounter("api_calls", by: 10)

// Get the new value
let newCount = provider.incrementCounter("clicks", by: 1)
print("New click count: \(newCount)")
```

### Decrementing Counters

```swift
// Decrement by 1 (default)
provider.decrementCounter("remaining_tries")

// Decrement by specific amount
provider.decrementCounter("credits", by: 5)

// Counters never go below zero
provider.setCounter("balance", to: 3)
provider.decrementCounter("balance", by: 10)  // Result: 0, not -7
```

### Reading and Resetting

```swift
// Read current value
let currentCount = provider.getCounter("attempts")  // Returns 0 if not found

// Reset to zero
provider.resetCounter("daily_actions")

// Clear all counters
provider.clearCounters()
```

### Using with Specifications

```swift
// Track API call limits
provider.setCounter("api_calls", to: 50)

@Satisfies(using: MaxCountSpec(counterKey: "api_calls", maximumCount: 100))
var canMakeAPICall: Bool

if canMakeAPICall {
    makeAPICall()
    provider.incrementCounter("api_calls")
}
```

## Feature Flag Management

Manage boolean feature toggles:

### Setting Flags

```swift
let provider = DefaultContextProvider.shared

// Enable/disable features
provider.setFlag("dark_mode", to: true)
provider.setFlag("experimental_ui", to: false)
provider.setFlag("analytics_enabled", to: true)
```

### Toggling Flags

```swift
// Toggle between true/false
let newValue = provider.toggleFlag("debug_mode")
print("Debug mode is now: \(newValue)")

// Toggle returns the new value
provider.setFlag("feature_a", to: false)
provider.toggleFlag("feature_a")  // Returns true
```

### Reading Flags

```swift
// Read current value (false if not found)
let isDarkMode = provider.getFlag("dark_mode")

// Clear all flags
provider.clearFlags()
```

### Using with Specifications

```swift
// Configure feature flags
provider.setFlag("premium_features", to: true)

@Satisfies(using: FeatureFlagSpec(flagKey: "premium_features"))
var showPremiumUI: Bool

if showPremiumUI {
    // Render premium interface
}
```

## Event Tracking

Record and retrieve event timestamps:

### Recording Events

```swift
let provider = DefaultContextProvider.shared

// Record event with current timestamp
provider.recordEvent("user_logged_in")
provider.recordEvent("tutorial_completed")
provider.recordEvent("notification_shown")

// Record event with specific timestamp
let customDate = Date().addingTimeInterval(-3600)  // 1 hour ago
provider.recordEvent("last_purchase", at: customDate)
```

### Reading Events

```swift
// Get event timestamp
if let lastLogin = provider.getEvent("user_logged_in") {
    print("Last login: \(lastLogin)")
}

// Remove an event
provider.removeEvent("temporary_flag")

// Clear all events
provider.clearEvents()
```

### Using with Time-Based Specifications

```swift
// Record when notification was shown
provider.recordEvent("last_notification")

// Cooldown spec ensures minimum time between notifications
@Satisfies(using: CooldownIntervalSpec(
    eventKey: "last_notification",
    interval: 3600  // 1 hour cooldown
))
var canShowNotification: Bool

if canShowNotification {
    showNotification()
    provider.recordEvent("last_notification")
}
```

## User Data Storage

Store arbitrary typed data:

### Setting User Data

```swift
let provider = DefaultContextProvider.shared

// Store different types
provider.setUserData("user_id", to: "abc123")
provider.setUserData("subscription_tier", to: "premium")
provider.setUserData("onboarding_completed", to: true)

// Store custom objects
struct UserProfile {
    let name: String
    let age: Int
}

let profile = UserProfile(name: "Alice", age: 30)
provider.setUserData("user_profile", to: profile)
```

### Reading User Data

```swift
// Type-safe retrieval
let userId = provider.getUserData("user_id", as: String.self)
let tier = provider.getUserData("subscription_tier", as: String.self)
let profile = provider.getUserData("user_profile", as: UserProfile.self)

// Remove user data
provider.removeUserData("temporary_data")

// Clear all user data
provider.clearUserData()
```

### Using in Specifications

```swift
provider.setUserData("subscription_tier", to: "premium")

struct TierSpec: Specification {
    func isSatisfiedBy(_ context: EvaluationContext) -> Bool {
        let tier = context.userData(for: "subscription_tier", as: String.self)
        return tier == "premium"
    }
}
```

## Custom Context Providers

Register dynamic context providers:

```swift
let provider = DefaultContextProvider.shared

// Register a provider for dynamic data
provider.register(contextKey: "current_user_id") {
    UserSession.current.userId
}

provider.register(contextKey: "is_online") {
    NetworkMonitor.shared.isConnected
}

// Unregister when no longer needed
provider.unregister(contextKey: "current_user_id")

// Values are fetched fresh each time context is requested
let context = provider.currentContext()
let userId = context.userData(for: "current_user_id", as: String.self)
```

## Bulk Operations

Manage all state at once:

```swift
let provider = DefaultContextProvider.shared

// Clear everything
provider.clearAll()

// Clear specific categories
provider.clearCounters()
provider.clearFlags()
provider.clearEvents()
provider.clearUserData()
```

## Thread Safety

All operations are thread-safe:

```swift
let provider = DefaultContextProvider.shared

// Safe to call from any queue
DispatchQueue.global().async {
    provider.incrementCounter("background_task")
}

DispatchQueue.main.async {
    provider.setFlag("ui_ready", to: true)
}

// Concurrent reads and writes are protected
Task.detached {
    provider.recordEvent("async_operation")
}
```

## Reactive Updates with Combine

Subscribe to context changes:

```swift
#if canImport(Combine)
import Combine

let provider = DefaultContextProvider.shared

// Subscribe to all context updates
let cancellable = provider.contextUpdates
    .sink {
        print("Context was updated")
        // Refresh UI or re-evaluate specifications
    }

// Provider conforms to ContextUpdatesProviding
// Updates are published whenever state changes
provider.setFlag("feature", to: true)  // Triggers update
provider.incrementCounter("count")      // Triggers update
```

## Async Context Stream

Use async/await with context updates:

```swift
let provider = DefaultContextProvider.shared

Task {
    for await _ in provider.contextStream {
        print("Context updated")
        // Async handling of context changes
    }
}

// Updates stream when state changes
provider.recordEvent("user_action")
```

## Creating Specifications

Build specifications using the provider:

### Context-Aware Predicates

```swift
let provider = DefaultContextProvider.shared

let spec = provider.contextualPredicate { context, user in
    context.flag(for: "premium_enabled") &&
    user.subscriptionTier == "premium"
}

// Use the specification
let isEligible = spec.isSatisfiedBy(user)
```

### Dynamic Specifications

```swift
let provider = DefaultContextProvider.shared

let dynamicSpec = provider.specification { context in
    if context.flag(for: "use_new_rules") {
        return AnySpecification(NewEligibilityRules())
    } else {
        return AnySpecification(LegacyEligibilityRules())
    }
}
```

## Testing with DefaultContextProvider

Use separate instances for isolated testing:

```swift
class FeatureTests: XCTestCase {
    var provider: DefaultContextProvider!

    override func setUp() {
        super.setUp()
        provider = DefaultContextProvider()  // Fresh instance
    }

    override func tearDown() {
        provider.clearAll()
        super.tearDown()
    }

    func testFeatureEligibility() {
        // Configure test scenario
        provider.setFlag("premium", to: true)
        provider.setCounter("usage", to: 5)

        let context = provider.currentContext()

        // Test specification
        XCTAssertTrue(eligibilitySpec.isSatisfiedBy(context))
    }
}
```

## Real-World Examples

### API Rate Limiting

```swift
let provider = DefaultContextProvider.shared

// Track API calls
provider.setCounter("api_calls_today", to: 0)

@Satisfies(using: MaxCountSpec(
    counterKey: "api_calls_today",
    maximumCount: 1000
))
var canMakeAPICall: Bool

func makeAPIRequest() async throws -> Response {
    guard canMakeAPICall else {
        throw APIError.rateLimitExceeded
    }

    let response = try await performRequest()
    provider.incrementCounter("api_calls_today")
    return response
}

// Reset daily limit
func resetDailyLimits() {
    provider.resetCounter("api_calls_today")
}
```

### Notification Cooldowns

```swift
let provider = DefaultContextProvider.shared

@Satisfies(using: CooldownIntervalSpec(
    eventKey: "last_notification",
    interval: 3600  // 1 hour
))
var canShowNotification: Bool

func showImportantNotification() {
    guard canShowNotification else {
        print("Too soon since last notification")
        return
    }

    displayNotification()
    provider.recordEvent("last_notification")
}
```

### Feature Rollout

```swift
let provider = DefaultContextProvider.shared

// Configure feature flags based on user segment
func configureFeatureFlags(for user: User) {
    if user.isBetaTester {
        provider.setFlag("new_ui", to: true)
        provider.setFlag("experimental_features", to: true)
    } else {
        provider.setFlag("new_ui", to: false)
        provider.setFlag("experimental_features", to: false)
    }
}

// Use throughout the app
@Satisfies(using: FeatureFlagSpec(flagKey: "new_ui"))
var useNewUI: Bool
```

## Best Practices

### Use Shared Instance for Application State

```swift
// ✅ Good - shared state across app
let provider = DefaultContextProvider.shared
provider.setFlag("dark_mode", to: true)

// ❌ Avoid - creating multiple instances fragments state
let provider1 = DefaultContextProvider()
let provider2 = DefaultContextProvider()  // Different state!
```

### Inject Provider for Testability

```swift
// ✅ Good - dependency injection
class FeatureService {
    let provider: DefaultContextProvider

    init(provider: DefaultContextProvider = .shared) {
        self.provider = provider
    }
}

// Easy to test
let testService = FeatureService(provider: DefaultContextProvider())

// ❌ Avoid - hard-coded dependency
class FeatureService {
    func check() {
        let context = DefaultContextProvider.shared.currentContext()  // Hard to test
    }
}
```

### Clear Test State

```swift
// ✅ Good - clean slate for each test
override func setUp() {
    provider = DefaultContextProvider()
}

override func tearDown() {
    provider.clearAll()
}

// ❌ Avoid - state leaks between tests
func testA() {
    provider.setFlag("test", to: true)  // Not cleared
}

func testB() {
    // Might fail if testA ran first
}
```

## Performance Considerations

- **Thread Safety Overhead**: Locks add minimal overhead; optimized for concurrent access
- **Reactive Updates**: Combine publishers add memory overhead; only subscribe when needed
- **Context Creation**: `currentContext()` creates a new struct each time; cheap operation
- **Dictionary Storage**: O(1) lookups but with dictionary overhead
- **Bulk Clears**: More efficient than removing items one by one

## Topics

### Shared Instance

- ``shared``

### Creating Providers

- ``init(launchDate:)``

### Counter Management

- ``setCounter(_:to:)``
- ``incrementCounter(_:by:)``
- ``decrementCounter(_:by:)``
- ``getCounter(_:)``
- ``resetCounter(_:)``

### Flag Management

- ``setFlag(_:to:)``
- ``toggleFlag(_:)``
- ``getFlag(_:)``

### Event Management

- ``recordEvent(_:)``
- ``recordEvent(_:at:)``
- ``getEvent(_:)``
- ``removeEvent(_:)``

### User Data Management

- ``setUserData(_:to:)``
- ``getUserData(_:as:)``
- ``removeUserData(_:)``

### Bulk Operations

- ``clearAll()``
- ``clearCounters()``
- ``clearFlags()``
- ``clearEvents()``
- ``clearUserData()``

### Context Registration

- ``register(contextKey:provider:)``
- ``unregister(contextKey:)``

### Creating Specifications

- ``specification(_:)``
- ``contextualPredicate(_:)``

### Context Provider Protocol

- ``currentContext()``

### Reactive Updates

- ``objectWillChange``
- ``contextUpdates``
- ``contextStream``

### Related Types

- ``EvaluationContext``
- ``MockContextProvider``
- ``ContextProviding``

## See Also

- <doc:EvaluationContext>
- <doc:MockContextProvider>
- <doc:ContextProviding>
