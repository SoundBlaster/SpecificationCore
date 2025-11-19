# ``SpecificationCore/ContextProviding``

A protocol for types that provide evaluation context to specifications.

## Overview

The `ContextProviding` protocol abstracts context creation and retrieval for specification evaluation. This enables dependency injection, testing with mock contexts, and dynamic context management without tightly coupling specifications to specific context implementations.

### Key Benefits

- **Dependency Injection**: Inject different context providers for production vs testing
- **Abstraction**: Decouple specifications from context storage mechanisms
- **Testability**: Easily provide mock contexts for unit testing
- **Flexibility**: Switch context providers without changing specification code
- **Async Support**: Built-in async context retrieval methods

### When to Use ContextProviding

Use `ContextProviding` when you need to:
- Provide runtime context to specifications (feature flags, counters, timestamps)
- Support different context sources (memory, database, network)
- Enable dependency injection for testability
- Create reusable context infrastructure
- Abstract context retrieval mechanisms

## Quick Example

```swift
import SpecificationCore

// Define your context type
struct AppContext {
    let userId: String
    let featureFlags: [String: Bool]
    let sessionStart: Date
}

// Create a context provider
struct AppContextProvider: ContextProviding {
    func currentContext() -> AppContext {
        AppContext(
            userId: UserSession.current.userId,
            featureFlags: FeatureFlagManager.shared.allFlags(),
            sessionStart: UserSession.current.startTime
        )
    }
}

// Use with specifications
let provider = AppContextProvider()
let context = provider.currentContext()

// Specifications can now use this context
let spec = FeatureFlagSpec(flagKey: "new_ui")
let isEnabled = spec.isSatisfiedBy(context)
```

## Built-in Context: EvaluationContext

SpecificationCore provides ``EvaluationContext`` as a standard context type:

```swift
// Use the default context provider
let provider = DefaultContextProvider.shared

// Set some context data
provider.setFlag("premium_user", value: true)
provider.setCounter("login_attempts", value: 3)
provider.recordEvent("last_login")

// Get current context
let context = provider.currentContext()

// Use with specifications
let spec = MaxCountSpec(
    counterKey: "login_attempts",
    maximumCount: 5
)
let canRetry = spec.isSatisfiedBy(context)
```

## Generic Context Provider

Create context providers from closures:

```swift
// Simple closure-based provider
let provider = GenericContextProvider {
    EvaluationContext(userId: UserSession.currentUserId)
}

let context = provider.currentContext()
```

## Static Context Provider

Provide a fixed context for testing or simple use cases:

```swift
// Create a static context for testing
let testContext = EvaluationContext(userId: "test-user-123")
let provider = StaticContextProvider(testContext)

// Always returns the same context
let context1 = provider.currentContext()
let context2 = provider.currentContext()
// context1 === context2 (same instance)
```

## Async Context Retrieval

Context providers support async retrieval for remote or database-backed contexts:

```swift
struct RemoteContextProvider: ContextProviding {
    let apiClient: APIClient

    func currentContext() -> EvaluationContext {
        // Synchronous fallback
        EvaluationContext(userId: "default")
    }

    func currentContextAsync() async throws -> EvaluationContext {
        let userData = try await apiClient.fetchUserData()
        return EvaluationContext(
            userId: userData.id,
            flags: userData.featureFlags,
            counters: userData.usageCounters
        )
    }
}

// Use async retrieval
let provider = RemoteContextProvider(apiClient: client)
let context = try await provider.currentContextAsync()
```

## Creating Specifications with Providers

Use context providers to create specifications:

```swift
let provider = DefaultContextProvider.shared

// Create a specification using the provider
let spec = provider.predicate { context, user in
    context.flag(for: "premium_users_only") == true &&
    user.subscriptionTier == "premium"
}

// Or create a more complex specification
let dynamicSpec = provider.specification { context in
    if context.flag(for: "use_new_rules") == true {
        return AnySpecification(NewEligibilityRules())
    } else {
        return AnySpecification(LegacyEligibilityRules())
    }
}
```

## Testing with Mock Providers

Create mock providers for unit testing:

```swift
// Use the built-in mock provider
let mockProvider = MockContextProvider()
mockProvider.setFlag("test_feature", value: true)
mockProvider.setCounter("attempts", value: 2)

// Inject into your code
class UserService {
    let contextProvider: any ContextProviding

    init(contextProvider: any ContextProviding = DefaultContextProvider.shared) {
        self.contextProvider = contextProvider
    }

    func checkEligibility(_ user: User) -> Bool {
        let context = contextProvider.currentContext()
        let spec = EligibilitySpec()
        return spec.isSatisfiedBy((user, context))
    }
}

// Test with mock provider
let service = UserService(contextProvider: mockProvider)
let isEligible = service.checkEligibility(testUser)
```

## Custom Context Types

Create custom context types for domain-specific needs:

```swift
struct OrderContext {
    let orderId: String
    let customerId: String
    let orderTotal: Decimal
    let createdAt: Date
    let items: [OrderItem]
}

struct OrderContextProvider: ContextProviding {
    let database: Database

    func currentContext() -> OrderContext {
        // Fetch current order context
        let orderId = CurrentOrderSession.orderId
        let order = database.fetchOrder(orderId)

        return OrderContext(
            orderId: order.id,
            customerId: order.customerId,
            orderTotal: order.total,
            createdAt: order.createdAt,
            items: order.items
        )
    }
}

// Use with order-specific specifications
struct MinimumOrderSpec: Specification {
    let minimumTotal: Decimal

    func isSatisfiedBy(_ context: OrderContext) -> Bool {
        context.orderTotal >= minimumTotal
    }
}

let provider = OrderContextProvider(database: db)
let context = provider.currentContext()
let meetsMinimum = MinimumOrderSpec(minimumTotal: 50.00).isSatisfiedBy(context)
```

## Environment-Specific Providers

Create different providers for different environments:

```swift
protocol AppContextProviding: ContextProviding where Context == EvaluationContext {}

struct ProductionContextProvider: AppContextProviding {
    func currentContext() -> EvaluationContext {
        EvaluationContext(
            userId: UserDefaults.standard.string(forKey: "userId") ?? "",
            flags: RemoteConfigManager.shared.flags,
            counters: AnalyticsManager.shared.counters
        )
    }
}

struct StagingContextProvider: AppContextProviding {
    func currentContext() -> EvaluationContext {
        EvaluationContext(
            userId: "staging-user",
            flags: ["all_features": true],  // Enable all features in staging
            counters: [:]
        )
    }
}

// Configure based on environment
#if DEBUG
let contextProvider: any AppContextProviding = StagingContextProvider()
#else
let contextProvider: any AppContextProviding = ProductionContextProvider()
#endif
```

## Thread-Safe Providers

Ensure thread safety when context can be accessed concurrently:

```swift
actor ThreadSafeContextProvider: ContextProviding {
    private var cachedContext: EvaluationContext?
    private let refreshInterval: TimeInterval

    init(refreshInterval: TimeInterval = 60) {
        self.refreshInterval = refreshInterval
    }

    func currentContext() -> EvaluationContext {
        // Note: Actor-isolated, must be called with await in async context
        if let cached = cachedContext {
            return cached
        }

        let context = buildContext()
        cachedContext = context
        return context
    }

    private func buildContext() -> EvaluationContext {
        EvaluationContext(
            userId: fetchUserId(),
            flags: fetchFlags(),
            counters: fetchCounters()
        )
    }
}
```

## Scoped Context Providers

Create context providers for specific scopes:

```swift
struct ScopedContextProvider: ContextProviding {
    let scope: String
    let baseProvider: DefaultContextProvider

    func currentContext() -> EvaluationContext {
        var context = baseProvider.currentContext()

        // Add scope-specific data
        context.metadata["scope"] = scope
        context.metadata["scope_timestamp"] = Date()

        return context
    }
}

// Use for different parts of your app
let checkoutProvider = ScopedContextProvider(
    scope: "checkout",
    baseProvider: .shared
)

let profileProvider = ScopedContextProvider(
    scope: "profile",
    baseProvider: .shared
)
```

## Combining Multiple Providers

Merge contexts from multiple providers:

```swift
struct CompositeProvider: ContextProviding {
    let providers: [any ContextProviding<EvaluationContext>]

    func currentContext() -> EvaluationContext {
        var merged = EvaluationContext()

        for provider in providers {
            let context = provider.currentContext()
            merged.merge(with: context)
        }

        return merged
    }
}

// Combine user, feature, and analytics contexts
let provider = CompositeProvider(providers: [
    UserContextProvider(),
    FeatureFlagProvider(),
    AnalyticsProvider()
])
```

## Best Practices

### Use Dependency Injection

```swift
// ✅ Good - inject provider for testability
class FeatureService {
    let contextProvider: any ContextProviding

    init(contextProvider: any ContextProviding = DefaultContextProvider.shared) {
        self.contextProvider = contextProvider
    }
}

// ❌ Avoid - hard-coded provider
class FeatureService {
    func checkFeature() {
        let context = DefaultContextProvider.shared.currentContext()  // Hard to test
    }
}
```

### Provide Default Implementations

```swift
// ✅ Good - default parameter for production use
init(contextProvider: any ContextProviding = DefaultContextProvider.shared) {
    self.contextProvider = contextProvider
}

// Easy to use in production
let service = FeatureService()  // Uses default

// Easy to test
let service = FeatureService(contextProvider: mockProvider)
```

### Cache Contexts When Appropriate

```swift
// ✅ Good - cache expensive context creation
class CachingProvider: ContextProviding {
    private var cache: EvaluationContext?
    private var cacheTime: Date?
    private let cacheTimeout: TimeInterval = 60

    func currentContext() -> EvaluationContext {
        if let cached = cache,
           let time = cacheTime,
           Date().timeIntervalSince(time) < cacheTimeout {
            return cached
        }

        let context = buildExpensiveContext()
        cache = context
        cacheTime = Date()
        return context
    }
}
```

## Performance Considerations

- **Lazy Context Creation**: Don't create context until needed
- **Caching**: Cache contexts when creation is expensive
- **Thread Safety**: Ensure providers are thread-safe if used concurrently
- **Async Methods**: Use async methods for I/O-bound context creation
- **Resource Cleanup**: Clean up resources in context providers when appropriate

## Topics

### Essential Protocol

- ``currentContext()``
- ``currentContextAsync()``

### Generic Providers

- ``GenericContextProvider``
- ``StaticContextProvider``

### Factory Functions

- ``contextProvider(_:)``
- ``staticContext(_:)``

### Creating Specifications

- ``specification(_:)``
- ``predicate(_:)``

### Standard Context

- ``EvaluationContext``
- ``DefaultContextProvider``
- ``MockContextProvider``

### Related Concepts

- ``Specification``
- ``AutoContext``

## See Also

- <doc:EvaluationContext>
- <doc:DefaultContextProvider>
- <doc:MockContextProvider>
- ``AutoContext``
