# ``SpecificationCore/MockContextProvider``

A mock context provider designed for unit testing specifications.

## Overview

`MockContextProvider` allows you to set up specific context scenarios and verify that specifications behave correctly under controlled conditions. It provides builder-style configuration, request tracking, and pre-configured test scenarios.

### Key Features

- **Controllable Context**: Set exact context state for testing
- **Request Tracking**: Monitor how many times context is requested
- **Builder Pattern**: Fluent interface for configuration
- **Test Scenarios**: Pre-configured helpers for common test cases
- **Verification**: Built-in methods to assert expected behavior

### When to Use MockContextProvider

Use `MockContextProvider` when you need to:
- Unit test specifications with controlled context
- Verify specification behavior under specific conditions
- Test edge cases and boundary conditions
- Track context access in tests
- Create reproducible test scenarios

## Quick Example

```swift
import SpecificationCore
import XCTest

class FeatureSpecTests: XCTestCase {
    func testPremiumFeature() {
        // Create mock provider with specific state
        let provider = MockContextProvider()
            .withFlag("premium", value: true)
            .withCounter("usage", value: 5)

        let context = provider.currentContext()

        // Test specification
        let spec = PremiumFeatureSpec()
        XCTAssertTrue(spec.isSatisfiedBy(context))
    }
}
```

## Creating Mock Providers

### Default Initialization

```swift
// Empty context
let provider = MockContextProvider()

// With specific context
let context = EvaluationContext(
    flags: ["test_mode": true],
    counters: ["attempts": 3]
)
let provider = MockContextProvider(context: context)

// With builder parameters
let provider = MockContextProvider(
    currentDate: Date(),
    flags: ["premium": true],
    counters: ["usage": 10]
)
```

### Setting Initial Context

```swift
// Configure after creation
let provider = MockContextProvider()

let testContext = EvaluationContext(
    flags: ["feature_enabled": true],
    counters: ["api_calls": 50]
)

provider.setContext(testContext)
```

## Builder Pattern

Chain configuration methods for fluent setup:

### Adding Flags

```swift
let provider = MockContextProvider()
    .withFlag("premium", value: true)
    .withFlag("beta_tester", value: true)
    .withFlag("analytics", value: false)

// Or set multiple at once
let provider2 = MockContextProvider()
    .withFlags([
        "premium": true,
        "beta": true
    ])
```

### Adding Counters

```swift
let provider = MockContextProvider()
    .withCounter("login_attempts", value: 3)
    .withCounter("api_calls", value: 100)
    .withCounter("page_views", value: 50)

// Or set multiple at once
let provider2 = MockContextProvider()
    .withCounters([
        "attempts": 3,
        "calls": 100
    ])
```

### Adding Events

```swift
let lastLogin = Date().addingTimeInterval(-3600)  // 1 hour ago
let lastPurchase = Date().addingTimeInterval(-86400)  // 1 day ago

let provider = MockContextProvider()
    .withEvent("last_login", date: lastLogin)
    .withEvent("last_purchase", date: lastPurchase)

// Or set multiple at once
let provider2 = MockContextProvider()
    .withEvents([
        "last_login": lastLogin,
        "last_purchase": lastPurchase
    ])
```

### Adding User Data

```swift
struct UserProfile {
    let tier: String
    let verified: Bool
}

let profile = UserProfile(tier: "premium", verified: true)

let provider = MockContextProvider()
    .withUserData([
        "user_profile": profile,
        "user_id": "test-123"
    ])
```

### Setting Timestamps

```swift
let testDate = Date(timeIntervalSince1970: 1640000000)

let provider = MockContextProvider()
    .withCurrentDate(testDate)
```

## Request Tracking

Monitor context access in tests:

```swift
let provider = MockContextProvider()
    .withFlag("feature", value: true)

// Track requests
XCTAssertEqual(provider.contextRequestCount, 0)

let context1 = provider.currentContext()
XCTAssertEqual(provider.contextRequestCount, 1)

let context2 = provider.currentContext()
XCTAssertEqual(provider.contextRequestCount, 2)

// Verify expected count
XCTAssertTrue(provider.verifyContextRequestCount(2))

// Reset tracking
provider.resetRequestCount()
XCTAssertEqual(provider.contextRequestCount, 0)
```

### Request Callbacks

Get notified when context is requested:

```swift
var requestLog: [Date] = []

let provider = MockContextProvider()
provider.onContextRequested = {
    requestLog.append(Date())
}

// Each request triggers callback
provider.currentContext()
provider.currentContext()

XCTAssertEqual(requestLog.count, 2)
```

## Pre-Configured Test Scenarios

Use helper methods for common test cases:

### Launch Delay Scenarios

Test time-since-launch behavior:

```swift
// Simulate app running for 5 minutes
let provider = MockContextProvider.launchDelayScenario(
    timeSinceLaunch: 300  // seconds
)

let context = provider.currentContext()
XCTAssertEqual(context.timeSinceLaunch, 300)

// Use with time-based specs
let spec = MinimumRuntimeSpec(minimumSeconds: 60)
XCTAssertTrue(spec.isSatisfiedBy(context))
```

### Counter Scenarios

Test counter-based specifications:

```swift
// Setup specific counter value
let provider = MockContextProvider.counterScenario(
    counterKey: "api_calls",
    counterValue: 95
)

let context = provider.currentContext()
XCTAssertEqual(context.counter(for: "api_calls"), 95)

// Test with MaxCountSpec
let spec = MaxCountSpec(counterKey: "api_calls", maximumCount: 100)
XCTAssertTrue(spec.isSatisfiedBy(context))  // 95 < 100
```

### Cooldown Scenarios

Test cooldown and time-based specs:

```swift
// Simulate event that occurred 30 minutes ago
let provider = MockContextProvider.cooldownScenario(
    eventKey: "last_notification",
    timeSinceEvent: 1800  // 30 minutes in seconds
)

let context = provider.currentContext()
let timeSince = context.timeSinceEvent("last_notification")
XCTAssertEqual(timeSince, 1800)

// Test cooldown spec
let spec = CooldownIntervalSpec(
    eventKey: "last_notification",
    interval: 3600  // 1 hour cooldown
)
XCTAssertFalse(spec.isSatisfiedBy(context))  // 1800 < 3600
```

## Testing Specifications

### Basic Specification Testing

```swift
func testAdultUserSpec() {
    // Setup context
    let provider = MockContextProvider()
        .withFlag("adult_verified", value: true)

    let context = provider.currentContext()

    // Test spec
    let spec = AdultVerificationSpec()
    XCTAssertTrue(spec.isSatisfiedBy(context))
}
```

### Testing Edge Cases

```swift
func testMaxCountBoundary() {
    // Test exactly at limit
    let atLimit = MockContextProvider()
        .withCounter("attempts", value: 5)

    let spec = MaxCountSpec(counterKey: "attempts", maximumCount: 5)
    XCTAssertTrue(spec.isSatisfiedBy(atLimit.currentContext()))

    // Test over limit
    let overLimit = MockContextProvider()
        .withCounter("attempts", value: 6)

    XCTAssertFalse(spec.isSatisfiedBy(overLimit.currentContext()))
}
```

### Testing Multiple Conditions

```swift
func testComplexEligibility() {
    let provider = MockContextProvider()
        .withFlag("premium", value: true)
        .withCounter("usage", value: 10)
        .withEvent("last_action", date: Date().addingTimeInterval(-7200))

    let context = provider.currentContext()

    let spec = EligibilitySpec()
    XCTAssertTrue(spec.isSatisfiedBy(context))
}
```

## Testing with Property Wrappers

Test property wrapper behavior:

```swift
func testSatisfiesWrapper() {
    let provider = MockContextProvider()
        .withFlag("feature_enabled", value: true)

    struct ViewModel {
        let context: EvaluationContext

        @Satisfies(using: FeatureFlagSpec(flagKey: "feature_enabled"))
        var isEnabled: Bool

        init(context: EvaluationContext) {
            self.context = context
            _isEnabled = Satisfies(
                using: FeatureFlagSpec(flagKey: "feature_enabled"),
                with: context
            )
        }
    }

    let viewModel = ViewModel(context: provider.currentContext())
    XCTAssertTrue(viewModel.isEnabled)
}
```

## Testing Decision Specs

Test specifications that return typed results:

```swift
func testDiscountDecision() {
    let provider = MockContextProvider()
        .withFlag("is_premium", value: true)

    let context = provider.currentContext()

    struct DiscountSpec: DecisionSpec {
        func decide(_ context: EvaluationContext) -> String? {
            context.flag(for: "is_premium") ? "PREMIUM20" : nil
        }
    }

    let spec = DiscountSpec()
    let discount = spec.decide(context)

    XCTAssertEqual(discount, "PREMIUM20")
}
```

## Parameterized Testing

Use mock providers for data-driven tests:

```swift
func testCounterLimits() {
    let testCases: [(count: Int, shouldPass: Bool)] = [
        (0, true),
        (5, true),
        (10, true),
        (11, false),
        (100, false)
    ]

    let spec = MaxCountSpec(counterKey: "attempts", maximumCount: 10)

    for testCase in testCases {
        let provider = MockContextProvider()
            .withCounter("attempts", value: testCase.count)

        let result = spec.isSatisfiedBy(provider.currentContext())

        XCTAssertEqual(
            result,
            testCase.shouldPass,
            "Failed for count: \(testCase.count)"
        )
    }
}
```

## Testing Time-Based Logic

Control time for deterministic tests:

```swift
func testDateRange() {
    let startDate = Date(timeIntervalSince1970: 1640000000)
    let endDate = startDate.addingTimeInterval(86400)  // +1 day

    // Test within range
    let withinRange = MockContextProvider()
        .withCurrentDate(startDate.addingTimeInterval(43200))  // Midpoint

    let spec = DateRangeSpec(start: startDate, end: endDate)
    XCTAssertTrue(spec.isSatisfiedBy(withinRange.currentContext()))

    // Test outside range
    let outsideRange = MockContextProvider()
        .withCurrentDate(endDate.addingTimeInterval(1))  // Past end

    XCTAssertFalse(spec.isSatisfiedBy(outsideRange.currentContext()))
}
```

## Testing Composition

Test complex specification compositions:

```swift
func testComposedSpecs() {
    let provider = MockContextProvider()
        .withFlag("premium", value: true)
        .withCounter("usage", value: 5)
        .withEvent("last_action", date: Date().addingTimeInterval(-7200))

    let premiumSpec = FeatureFlagSpec(flagKey: "premium")
    let usageSpec = MaxCountSpec(counterKey: "usage", maximumCount: 10)
    let cooldownSpec = CooldownIntervalSpec(
        eventKey: "last_action",
        interval: 3600
    )

    // Test individual specs
    let context = provider.currentContext()
    XCTAssertTrue(premiumSpec.isSatisfiedBy(context))
    XCTAssertTrue(usageSpec.isSatisfiedBy(context))
    XCTAssertTrue(cooldownSpec.isSatisfiedBy(context))

    // Test composition
    let combined = premiumSpec && usageSpec && cooldownSpec
    XCTAssertTrue(combined.isSatisfiedBy(context))
}
```

## Verifying Behavior

Verify specifications handle various scenarios:

```swift
func testSpecHandlesMissingData() {
    // Empty context - no flags, counters, or events
    let empty = MockContextProvider()

    let context = empty.currentContext()

    // Verify spec handles missing data gracefully
    let spec = FeatureFlagSpec(flagKey: "nonexistent")
    XCTAssertFalse(spec.isSatisfiedBy(context))  // Should default to false

    let counterSpec = MaxCountSpec(counterKey: "missing", maximumCount: 10)
    XCTAssertTrue(counterSpec.isSatisfiedBy(context))  // 0 < 10
}
```

## Integration Testing

Use mock providers for integration tests:

```swift
func testFeatureService() {
    // Setup mock provider
    let provider = MockContextProvider()
        .withFlag("feature_a", value: true)
        .withFlag("feature_b", value: false)

    // Inject into service
    let service = FeatureService(contextProvider: provider)

    // Test service behavior
    XCTAssertTrue(service.isFeatureAEnabled())
    XCTAssertFalse(service.isFeatureBEnabled())

    // Verify context was accessed
    XCTAssertEqual(provider.contextRequestCount, 2)
}
```

## Best Practices

### Create Fresh Providers for Each Test

```swift
// ✅ Good - isolated test state
class SpecTests: XCTestCase {
    func testScenario1() {
        let provider = MockContextProvider()
            .withFlag("test", value: true)
        // Test with this provider
    }

    func testScenario2() {
        let provider = MockContextProvider()
            .withFlag("test", value: false)
        // Test with this provider
    }
}

// ❌ Avoid - shared state between tests
class SpecTests: XCTestCase {
    let provider = MockContextProvider()  // Shared!

    func testScenario1() {
        provider.withFlag("test", value: true)
        // State leaks to testScenario2
    }
}
```

### Use Named Test Scenarios

```swift
// ✅ Good - clear test intent
func testPremiumUserWithHighUsage() {
    let provider = MockContextProvider()
        .withFlag("premium", value: true)
        .withCounter("usage", value: 95)

    // Test logic
}

// ❌ Avoid - unclear scenario
func testSpec() {
    let provider = MockContextProvider()
        .withFlag("f1", value: true)
        .withCounter("c1", value: 95)
}
```

### Verify Request Counts When Relevant

```swift
// ✅ Good - verify lazy evaluation
func testLazyEvaluation() {
    let provider = MockContextProvider()
        .withFlag("feature", value: false)

    let spec = FeatureFlagSpec(flagKey: "feature")

    // Should not request context until evaluation
    XCTAssertEqual(provider.contextRequestCount, 0)

    spec.isSatisfiedBy(provider.currentContext())

    // Now should have requested context
    XCTAssertEqual(provider.contextRequestCount, 1)
}
```

## Performance Considerations

- **Lightweight**: Mock providers have minimal overhead
- **No Thread Safety**: Not thread-safe; use separate providers for concurrent tests
- **Request Tracking**: Minimal overhead; safe to use in all tests
- **Builder Pattern**: Each builder method creates a new context; efficient for testing

## Topics

### Creating Providers

- ``init()``
- ``init(context:)``
- ``init(currentDate:launchDate:userData:counters:events:flags:)``

### Context Management

- ``mockContext``
- ``setContext(_:)``
- ``currentContext()``

### Request Tracking

- ``contextRequestCount``
- ``onContextRequested``
- ``resetRequestCount()``
- ``verifyContextRequestCount(_:)``

### Builder Methods

- ``withCurrentDate(_:)``
- ``withCounters(_:)``
- ``withEvents(_:)``
- ``withFlags(_:)``
- ``withUserData(_:)``
- ``withCounter(_:value:)``
- ``withEvent(_:date:)``
- ``withFlag(_:value:)``

### Test Scenarios

- ``launchDelayScenario(timeSinceLaunch:currentDate:)``
- ``counterScenario(counterKey:counterValue:)``
- ``cooldownScenario(eventKey:timeSinceEvent:currentDate:)``

### Related Types

- ``EvaluationContext``
- ``DefaultContextProvider``
- ``ContextProviding``

## See Also

- <doc:EvaluationContext>
- <doc:DefaultContextProvider>
- <doc:ContextProviding>
