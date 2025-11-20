# ``SpecificationCore/AsyncSatisfies``

A property wrapper for asynchronously evaluating specifications with async context providers and async specifications.

## Overview

`@AsyncSatisfies` is designed for scenarios where specification evaluation requires asynchronous operations like network requests, database queries, or file I/O. Unlike ``Satisfies``, this wrapper requires explicit async evaluation through the projected value rather than providing automatic evaluation.

### Key Benefits

- **Async Context Support**: Works with context providers that provide async context
- **Async Specifications**: Supports both sync and async specification evaluation
- **Lazy Evaluation**: Only evaluates when explicitly requested
- **Error Handling**: Propagates errors from async operations
- **Flexible Usage**: Works with regular specifications or async-specific ones
- **Thread-Safe**: Safe to call from any thread

### When to Use @AsyncSatisfies

Use `@AsyncSatisfies` when you need to:
- Evaluate specifications with network-based context or data
- Perform database queries during specification evaluation
- Handle file I/O or other async operations
- Work with remote configuration or feature flags
- Integrate with async-first APIs or services

## Quick Example

```swift
import SpecificationCore

@AsyncSatisfies(
    provider: networkProvider,
    using: RemoteFeatureFlagSpec(flagKey: "premium_features")
)
var hasPremiumAccess: Bool?

// Evaluate asynchronously when needed
func checkAccess() async {
    do {
        let hasAccess = try await $hasPremiumAccess.evaluate()
        if hasAccess {
            showPremiumFeatures()
        }
    } catch {
        handleNetworkError(error)
    }
}
```

## Creating @AsyncSatisfies

### With Async Specification

```swift
struct RemoteConfigSpec: AsyncSpecification {
    typealias T = NetworkContext
    let featureKey: String

    func isSatisfiedBy(_ context: NetworkContext) async throws -> Bool {
        let config = try await context.apiClient.fetchRemoteConfig()
        return config.features[featureKey] == true
    }
}

@AsyncSatisfies(
    provider: networkContextProvider,
    using: RemoteConfigSpec(featureKey: "new_ui")
)
var shouldShowNewUI: Bool?

// Evaluate
let enabled = try await $shouldShowNewUI.evaluate()
```

### With Regular Specification

```swift
// Use regular (synchronous) specifications with async wrapper
@AsyncSatisfies(
    provider: asyncProvider,
    using: MaxCountSpec(counterKey: "api_calls", maximumCount: 100)
)
var canMakeAPICall: Bool?

// This uses async context fetching but sync specification evaluation
let allowed = try await $canMakeAPICall.evaluate()
```

### With Async Predicate

```swift
@AsyncSatisfies(provider: apiProvider, predicate: { context in
    let userProfile = try await context.apiClient.fetchUserProfile()
    let billingInfo = try await context.apiClient.fetchBillingInfo()

    return userProfile.isVerified && billingInfo.isGoodStanding
})
var isEligibleUser: Bool?
```

## How It Works

The wrapper requires explicit async evaluation through the projected value:

```swift
@AsyncSatisfies(provider: asyncProvider, using: SomeSpec())
var isConditionMet: Bool?

// wrappedValue is always nil (no automatic evaluation)
print(isConditionMet)  // nil

// Use projected value to evaluate asynchronously
let result = try await $isConditionMet.evaluate()
print(result)  // true or false
```

## Usage Examples

### Network-Based Feature Flags

```swift
struct NetworkContext {
    let apiClient: APIClient
    let userId: String
}

struct RemoteFeatureFlagSpec: AsyncSpecification {
    typealias T = NetworkContext
    let flagKey: String

    func isSatisfiedBy(_ context: NetworkContext) async throws -> Bool {
        let response = try await context.apiClient.get(
            "/feature-flags/\(context.userId)"
        )
        return response.flags[flagKey] as? Bool ?? false
    }
}

@AsyncSatisfies(
    provider: networkProvider,
    using: RemoteFeatureFlagSpec(flagKey: "experimental_features")
)
var hasExperimentalFeatures: Bool?

func loadFeatures() async {
    do {
        let enabled = try await $hasExperimentalFeatures.evaluate()
        if enabled {
            loadExperimentalFeatures()
        } else {
            loadStandardFeatures()
        }
    } catch {
        // Fall back to local configuration
        loadStandardFeatures()
        logError("Failed to fetch remote config: \(error)")
    }
}
```

### Database User Validation

```swift
struct DatabaseContext {
    let database: Database
    let userId: UUID
}

struct ActiveUserSpec: AsyncSpecification {
    typealias T = DatabaseContext

    func isSatisfiedBy(_ context: DatabaseContext) async throws -> Bool {
        let user = try await context.database.fetchUser(context.userId)
        return user.isActive &&
               user.hasValidSubscription &&
               !user.isBanned
    }
}

@AsyncSatisfies(
    provider: databaseProvider,
    using: ActiveUserSpec()
)
var isActiveUser: Bool?

func checkUserStatus() async throws {
    let isActive = try await $isActiveUser.evaluate()

    if isActive {
        grantAccess()
    } else {
        denyAccess()
    }
}
```

### API Rate Limit Check

```swift
struct RateLimitContext {
    let apiClient: APIClient
    let accountId: String
}

struct RateLimitSpec: AsyncSpecification {
    typealias T = RateLimitContext

    func isSatisfiedBy(_ context: RateLimitContext) async throws -> Bool {
        let limits = try await context.apiClient.getRateLimits(
            accountId: context.accountId
        )
        return limits.remainingRequests > 0
    }
}

@AsyncSatisfies(
    provider: rateLimitProvider,
    using: RateLimitSpec()
)
var canMakeRequest: Bool?

func performAPICall() async throws {
    let allowed = try await $canMakeRequest.evaluate()

    guard allowed else {
        throw APIError.rateLimitExceeded
    }

    let response = try await makeAPICall()
    return response
}
```

### File-Based Configuration

```swift
struct FileContext {
    let configPath: String
}

struct ConfigurationValidSpec: AsyncSpecification {
    typealias T = FileContext

    func isSatisfiedBy(_ context: FileContext) async throws -> Bool {
        let data = try await FileManager.default.readFile(at: context.configPath)
        let config = try JSONDecoder().decode(Configuration.self, from: data)
        return config.isValid && config.version >= requiredVersion
    }
}

@AsyncSatisfies(
    provider: fileProvider,
    using: ConfigurationValidSpec()
)
var hasValidConfiguration: Bool?

func loadApp() async {
    do {
        let isValid = try await $hasValidConfiguration.evaluate()

        if isValid {
            startApp()
        } else {
            showConfigurationError()
        }
    } catch {
        useDefaultConfiguration()
    }
}
```

## Real-World Examples

### Remote Configuration Manager

```swift
class RemoteConfigManager {
    struct RemoteContext {
        let apiClient: APIClient
        let deviceId: String
        let appVersion: String
    }

    struct FeatureEnabledSpec: AsyncSpecification {
        typealias T = RemoteContext
        let feature: String

        func isSatisfiedBy(_ context: RemoteContext) async throws -> Bool {
            let config = try await context.apiClient.fetchConfig(
                deviceId: context.deviceId,
                appVersion: context.appVersion
            )

            // Check if feature is enabled with rollout percentage
            guard let featureConfig = config.features[feature] else {
                return false
            }

            if featureConfig.rolloutPercentage >= 100 {
                return true
            }

            // Use device ID for consistent rollout
            let hash = context.deviceId.hashValue
            let bucket = abs(hash % 100)
            return bucket < featureConfig.rolloutPercentage
        }
    }

    @AsyncSatisfies(
        provider: remoteProvider,
        using: FeatureEnabledSpec(feature: "new_payment_flow")
    )
    var useNewPaymentFlow: Bool?

    @AsyncSatisfies(
        provider: remoteProvider,
        using: FeatureEnabledSpec(feature: "enhanced_analytics")
    )
    var enableEnhancedAnalytics: Bool?

    func configureApp() async {
        do {
            async let paymentFlow = $useNewPaymentFlow.evaluate()
            async let analytics = $enableEnhancedAnalytics.evaluate()

            let (useNew, enhancedAnalytics) = try await (paymentFlow, analytics)

            if useNew {
                configureNewPaymentFlow()
            }

            if enhancedAnalytics {
                enableDetailedAnalytics()
            }
        } catch {
            // Use default configuration
            useDefaultConfiguration()
            logError("Remote config failed: \(error)")
        }
    }
}
```

### Subscription Verification System

```swift
class SubscriptionVerifier {
    struct VerificationContext {
        let apiClient: APIClient
        let receiptData: Data
        let userId: String
    }

    struct ActiveSubscriptionSpec: AsyncSpecification {
        typealias T = VerificationContext

        func isSatisfiedBy(_ context: VerificationContext) async throws -> Bool {
            // Verify with App Store
            let verification = try await context.apiClient.verifyReceipt(
                receiptData: context.receiptData
            )

            guard verification.status == .valid else {
                return false
            }

            // Check subscription status in backend
            let subscription = try await context.apiClient.getSubscription(
                userId: context.userId
            )

            return subscription.isActive &&
                   subscription.expirationDate > Date() &&
                   !subscription.isCancelled
        }
    }

    @AsyncSatisfies(
        provider: verificationProvider,
        using: ActiveSubscriptionSpec()
    )
    var hasActiveSubscription: Bool?

    func checkSubscriptionStatus() async -> SubscriptionStatus {
        do {
            let isActive = try await $hasActiveSubscription.evaluate()

            if isActive {
                return .active
            } else {
                return .expired
            }
        } catch let error as VerificationError {
            switch error {
            case .networkError:
                return .verificationFailed(retryable: true)
            case .invalidReceipt:
                return .invalid
            case .serverError:
                return .verificationFailed(retryable: true)
            }
        } catch {
            return .unknown
        }
    }
}
```

### Multi-Service Eligibility Check

```swift
class EligibilityChecker {
    struct ServiceContext {
        let userService: UserService
        let billingService: BillingService
        let complianceService: ComplianceService
        let userId: UUID
    }

    struct FullAccessSpec: AsyncSpecification {
        typealias T = ServiceContext

        func isSatisfiedBy(_ context: ServiceContext) async throws -> Bool {
            // Fetch data from multiple services in parallel
            async let user = context.userService.fetchUser(context.userId)
            async let billing = context.billingService.getBillingStatus(context.userId)
            async let compliance = context.complianceService.checkCompliance(context.userId)

            let (userData, billingData, complianceData) = try await (user, billing, compliance)

            // Check all conditions
            return userData.isVerified &&
                   userData.accountStatus == .active &&
                   billingData.isGoodStanding &&
                   billingData.hasActivePaymentMethod &&
                   complianceData.isCompliant &&
                   !complianceData.hasRestrictions
        }
    }

    @AsyncSatisfies(
        provider: serviceProvider,
        using: FullAccessSpec()
    )
    var hasFullAccess: Bool?

    func determineAccessLevel() async -> AccessLevel {
        do {
            let hasAccess = try await $hasFullAccess.evaluate()

            if hasAccess {
                return .full
            } else {
                return .restricted
            }
        } catch {
            // Conservative fallback
            return .denied
        }
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI

struct PremiumContentView: View {
    @AsyncSatisfies(
        provider: networkProvider,
        using: PremiumAccessSpec()
    )
    var hasPremiumAccess: Bool?

    @State private var accessStatus: AccessStatus = .checking
    @State private var showError = false
    @State private var errorMessage = ""

    enum AccessStatus {
        case checking
        case granted
        case denied
    }

    var body: some View {
        Group {
            switch accessStatus {
            case .checking:
                ProgressView("Verifying access...")

            case .granted:
                PremiumContentUI()

            case .denied:
                AccessDeniedView()
                    .button("Upgrade") {
                        showUpgradeFlow()
                    }
            }
        }
        .task {
            await checkAccess()
        }
        .alert("Error", isPresented: $showError) {
            Button("Retry") {
                Task { await checkAccess() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    func checkAccess() async {
        accessStatus = .checking

        do {
            let hasAccess = try await withTimeout(seconds: 10) {
                try await $hasPremiumAccess.evaluate()
            }

            accessStatus = hasAccess ? .granted : .denied
        } catch {
            errorMessage = error.localizedDescription
            showError = true
            accessStatus = .denied
        }
    }
}
```

## Error Handling

Handle errors from async evaluation:

```swift
@AsyncSatisfies(provider: networkProvider, using: RemoteSpec())
var isEnabled: Bool?

func checkFeature() async {
    do {
        let enabled = try await $isEnabled.evaluate()
        // Handle result
    } catch let error as NetworkError {
        switch error {
        case .timeout:
            // Retry or use cached value
            useCachedValue()
        case .serverError:
            // Show error to user
            showErrorMessage()
        case .noConnection:
            // Offline mode
            enterOfflineMode()
        }
    } catch {
        // Handle unexpected errors
        logError(error)
        useDefaultBehavior()
    }
}
```

## Timeout Handling

Add timeouts to async evaluation:

```swift
@AsyncSatisfies(provider: apiProvider, using: SlowAPISpec())
var shouldEnable: Bool?

func checkWithTimeout() async {
    do {
        let result = try await withTimeout(seconds: 5) {
            try await $shouldEnable.evaluate()
        }

        if result {
            enableFeature()
        }
    } catch is TimeoutError {
        // Use default on timeout
        useDefaultValue()
    } catch {
        handleError(error)
    }
}

// Helper function
func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw TimeoutError()
        }

        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}
```

## Testing

Test async evaluation with ``MockContextProvider``:

```swift
func testAsyncEvaluation() async throws {
    let provider = MockContextProvider()
        .withFlag("remote_feature", value: true)

    @AsyncSatisfies(
        provider: provider,
        using: FeatureFlagSpec(flagKey: "remote_feature")
    )
    var isEnabled: Bool?

    // wrappedValue is always nil
    XCTAssertNil(isEnabled)

    // Evaluate asynchronously
    let result = try await $isEnabled.evaluate()
    XCTAssertTrue(result)

    // Update context
    provider.setFlag("remote_feature", to: false)
    let updatedResult = try await $isEnabled.evaluate()
    XCTAssertFalse(updatedResult)
}

func testAsyncSpecification() async throws {
    struct MockAsyncSpec: AsyncSpecification {
        typealias T = EvaluationContext
        let delay: TimeInterval
        let result: Bool

        func isSatisfiedBy(_ context: EvaluationContext) async throws -> Bool {
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            return result
        }
    }

    let provider = MockContextProvider()
    let spec = MockAsyncSpec(delay: 0.1, result: true)

    @AsyncSatisfies(provider: provider, using: spec)
    var condition: Bool?

    let start = Date()
    let result = try await $condition.evaluate()
    let duration = Date().timeIntervalSince(start)

    XCTAssertTrue(result)
    XCTAssertGreaterThan(duration, 0.1)
}

func testErrorPropagation() async {
    struct FailingSpec: AsyncSpecification {
        typealias T = EvaluationContext

        func isSatisfiedBy(_ context: EvaluationContext) async throws -> Bool {
            throw TestError.failed
        }
    }

    let provider = MockContextProvider()

    @AsyncSatisfies(provider: provider, using: FailingSpec())
    var condition: Bool?

    do {
        _ = try await $condition.evaluate()
        XCTFail("Should have thrown error")
    } catch is TestError {
        // Expected
    } catch {
        XCTFail("Wrong error type")
    }
}
```

## Best Practices

### Use Appropriate Timeouts

```swift
// ✅ Good - timeout for network operations
@AsyncSatisfies(provider: networkProvider, using: RemoteSpec())
var isEnabled: Bool?

func check() async {
    do {
        let result = try await withTimeout(seconds: 10) {
            try await $isEnabled.evaluate()
        }
    } catch {
        // Handle timeout
    }
}

// ❌ Avoid - no timeout on network operations
let result = try await $isEnabled.evaluate()  // Could hang indefinitely
```

### Provide Fallback Behavior

```swift
// ✅ Good - fallback on error
@AsyncSatisfies(provider: apiProvider, using: RemoteConfigSpec())
var useNewFeature: Bool?

func configureFeature() async {
    do {
        let enabled = try await $useNewFeature.evaluate()
        if enabled {
            enableNewFeature()
        }
    } catch {
        // Use safe default
        useStableFeature()
        logError(error)
    }
}
```

### Cache Results When Appropriate

```swift
// ✅ Good - cache for expensive operations
class ConfigManager {
    @AsyncSatisfies(provider: networkProvider, using: ConfigSpec())
    var isFeatureEnabled: Bool?

    private var cachedResult: Bool?
    private var lastFetch: Date?
    private let cacheTimeout: TimeInterval = 300  // 5 minutes

    func checkFeature() async throws -> Bool {
        // Use cache if valid
        if let cached = cachedResult,
           let lastFetch = lastFetch,
           Date().timeIntervalSince(lastFetch) < cacheTimeout {
            return cached
        }

        // Fetch fresh value
        let result = try await $isFeatureEnabled.evaluate()
        cachedResult = result
        lastFetch = Date()
        return result
    }
}
```

### Handle Errors Gracefully

```swift
// ✅ Good - specific error handling
func checkAccess() async -> AccessLevel {
    do {
        let hasAccess = try await $premiumAccess.evaluate()
        return hasAccess ? .premium : .free
    } catch is NetworkError {
        // Network issues - use cached or safe default
        return .free
    } catch is AuthenticationError {
        // Auth issues - require re-login
        return .requiresAuth
    } catch {
        // Unknown errors - safe default
        logError(error)
        return .free
    }
}
```

## Performance Considerations

- **Async Overhead**: Async context fetching and evaluation has inherent overhead
- **No Automatic Evaluation**: No performance cost unless explicitly evaluated
- **No Caching**: Context fetched fresh on each `evaluate()` call
- **Network Latency**: Network-based specs may have significant latency
- **Error Handling Cost**: Minimal overhead for error propagation
- **Threading**: Async evaluation can run on any thread, managed by Swift concurrency

Consider caching at the provider or application level for frequently accessed async values.

## Topics

### Creating Property Wrappers

- ``init(provider:using:)-29rld``
- ``init(provider:predicate:)``
- ``init(provider:using:)-8c1q7``

### Async Evaluation

- ``Projection``
- ``Projection/evaluate()``
- ``projectedValue``

### Property Values

- ``wrappedValue``

### Related Types

- ``AsyncSpecification``
- ``AnyAsyncSpecification``
- ``Specification``
- ``EvaluationContext``
- ``ContextProviding``

## See Also

- <doc:Satisfies>
- <doc:AsyncSpecification>
- <doc:Specification>
- <doc:EvaluationContext>
- <doc:ContextProviding>
