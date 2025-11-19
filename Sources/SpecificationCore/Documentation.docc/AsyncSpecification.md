# ``SpecificationCore/AsyncSpecification``

A protocol for specifications that require asynchronous evaluation.

## Overview

The `AsyncSpecification` protocol extends the Specification Pattern to support async operations such as network requests, database queries, file I/O, or any evaluation that needs to be performed asynchronously. It follows the same pattern as ``Specification`` but leverages Swift's async/await for non-blocking evaluation.

### Key Benefits

- **Non-Blocking Evaluation**: Perform expensive operations without blocking the calling thread
- **Error Handling**: Built-in support for throwing errors during evaluation
- **Async/Await Support**: Leverage Swift's modern concurrency features
- **Type Safety**: Generic associated type ensures compile-time correctness
- **Composability**: Works with standard specifications through bridging

### When to Use AsyncSpecification

Use `AsyncSpecification` when you need to:
- Query remote APIs or services
- Access databases or file systems
- Perform long-running computations
- Coordinate multiple async data sources
- Evaluate specifications that depend on I/O

## Quick Example

```swift
import SpecificationCore

struct User {
    let id: String
    let email: String
}

// Define an async specification
struct SubscriptionActiveSpec: AsyncSpecification {
    let apiClient: SubscriptionAPI

    func isSatisfiedBy(_ user: User) async throws -> Bool {
        let subscription = try await apiClient.fetchSubscription(userId: user.id)
        return subscription.isActive && !subscription.isExpired
    }
}

// Use the async specification
let spec = SubscriptionActiveSpec(apiClient: client)
let user = User(id: "123", email: "user@example.com")

do {
    let isActive = try await spec.isSatisfiedBy(user)
    if isActive {
        print("User has active subscription")
    }
} catch {
    print("Error checking subscription: \(error)")
}
```

## Bridging Synchronous Specifications

Convert any synchronous ``Specification`` to async using ``AnyAsyncSpecification``:

```swift
struct LocalUserSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.email.contains("@")
    }
}

// Bridge to async
let asyncSpec = AnyAsyncSpecification(LocalUserSpec())

let result = try await asyncSpec.isSatisfiedBy(user)  // Works in async context
```

## Using with Property Wrappers

Combine async specifications with the ``AsyncSatisfies`` property wrapper:

```swift
struct FeatureViewModel {
    let user: User

    @AsyncSatisfies(using: SubscriptionActiveSpec(apiClient: client))
    var hasActiveSubscription: Bool

    init(user: User) {
        self.user = user
        _hasActiveSubscription = AsyncSatisfies(
            using: SubscriptionActiveSpec(apiClient: client),
            with: user
        )
    }

    func checkAccess() async throws -> Bool {
        try await $hasActiveSubscription.evaluateAsync()
    }
}

let viewModel = FeatureViewModel(user: user)
let hasAccess = try await viewModel.checkAccess()
```

## Network-Based Specifications

Query remote APIs to evaluate specifications:

```swift
struct RemoteFeatureFlagSpec: AsyncSpecification {
    let flagKey: String
    let apiClient: FeatureFlagAPI

    func isSatisfiedBy(_ context: EvaluationContext) async throws -> Bool {
        let flags = try await apiClient.fetchFlags(userId: context.userId)
        return flags[flagKey] == true
    }
}

// Use with remote feature flags
let premiumFeaturesSpec = RemoteFeatureFlagSpec(
    flagKey: "premium_features",
    apiClient: client
)

if try await premiumFeaturesSpec.isSatisfiedBy(context) {
    // Enable premium features
}
```

## Database Query Specifications

Access databases asynchronously:

```swift
struct UserHasPurchasedSpec: AsyncSpecification {
    let database: Database
    let productId: String

    func isSatisfiedBy(_ user: User) async throws -> Bool {
        let purchases = try await database.fetchPurchases(userId: user.id)
        return purchases.contains { $0.productId == productId }
    }
}

// Check purchase history
let hasProVersion = UserHasPurchasedSpec(
    database: db,
    productId: "pro_version"
)

if try await hasProVersion.isSatisfiedBy(user) {
    // Grant pro features
}
```

## Coordinating Multiple Async Sources

Use async/let for concurrent evaluation:

```swift
struct EligibilityCheckSpec: AsyncSpecification {
    let userService: UserService
    let billingService: BillingService
    let complianceService: ComplianceService

    func isSatisfiedBy(_ user: User) async throws -> Bool {
        // Fetch all data concurrently
        async let profile = userService.fetchProfile(user.id)
        async let billing = billingService.checkStatus(user.id)
        async let compliance = complianceService.verifyUser(user.id)

        // Wait for all results
        let (userProfile, billingStatus, complianceStatus) =
            try await (profile, billing, compliance)

        // Evaluate combined criteria
        return userProfile.isVerified &&
               billingStatus.isGoodStanding &&
               complianceStatus.isCompliant
    }
}
```

## Type-Erased Async Specifications

Use ``AnyAsyncSpecification`` for flexibility:

```swift
// Store different async specs together
let asyncChecks: [AnyAsyncSpecification<User>] = [
    AnyAsyncSpecification(SubscriptionActiveSpec(apiClient: client)),
    AnyAsyncSpecification(UserHasPurchasedSpec(database: db, productId: "premium")),
    AnyAsyncSpecification { user in
        // Custom async logic
        try await customCheck(user)
    }
]

// Evaluate all checks
for check in asyncChecks {
    let result = try await check.isSatisfiedBy(user)
    print("Check result: \(result)")
}
```

## Creating from Closures

Create async specifications from closures:

```swift
let delayedSpec = AnyAsyncSpecification<User> { user in
    // Simulate network delay
    try await Task.sleep(nanoseconds: 100_000_000)  // 0.1 seconds
    return user.email.contains("@verified.com")
}

let isVerified = try await delayedSpec.isSatisfiedBy(user)
```

## Error Handling Patterns

### Try-Catch Pattern

```swift
do {
    let isEligible = try await spec.isSatisfiedBy(user)
    if isEligible {
        // Proceed with action
    }
} catch let error as NetworkError {
    print("Network error: \(error.localizedDescription)")
} catch {
    print("Unexpected error: \(error)")
}
```

### Optional Result Pattern

```swift
func evaluateSpec(_ user: User) async -> Bool {
    do {
        return try await spec.isSatisfiedBy(user)
    } catch {
        print("Error evaluating spec: \(error)")
        return false  // Safe default
    }
}
```

### Result Type Pattern

```swift
func evaluateSpec(_ user: User) async -> Result<Bool, Error> {
    do {
        let result = try await spec.isSatisfiedBy(user)
        return .success(result)
    } catch {
        return .failure(error)
    }
}

let result = await evaluateSpec(user)
switch result {
case .success(let isEligible):
    print("Eligible: \(isEligible)")
case .failure(let error):
    print("Error: \(error)")
}
```

## Timeout Handling

Add timeouts to async specification evaluation:

```swift
struct TimeoutAsyncSpec<S: AsyncSpecification>: AsyncSpecification {
    let wrapped: S
    let timeout: Duration

    func isSatisfiedBy(_ candidate: S.T) async throws -> Bool {
        try await withThrowingTaskGroup(of: Bool.self) { group in
            group.addTask {
                try await self.wrapped.isSatisfiedBy(candidate)
            }
            group.addTask {
                try await Task.sleep(for: self.timeout)
                throw TimeoutError()
            }

            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}

// Use with timeout
let timedSpec = TimeoutAsyncSpec(
    wrapped: RemoteFeatureFlagSpec(flagKey: "feature", apiClient: client),
    timeout: .seconds(5)
)
```

## Caching Async Results

Cache expensive async evaluations:

```swift
actor CachedAsyncSpec<S: AsyncSpecification>: AsyncSpecification where S.T: Hashable {
    let wrapped: S
    var cache: [S.T: Bool] = [:]

    init(_ spec: S) {
        self.wrapped = spec
    }

    func isSatisfiedBy(_ candidate: S.T) async throws -> Bool {
        if let cached = cache[candidate] {
            return cached
        }

        let result = try await wrapped.isSatisfiedBy(candidate)
        cache[candidate] = result
        return result
    }

    func clearCache() {
        cache.removeAll()
    }
}

// Use cached spec
let cachedSpec = CachedAsyncSpec(
    SubscriptionActiveSpec(apiClient: client)
)

let result1 = try await cachedSpec.isSatisfiedBy(user)  // Fetches from API
let result2 = try await cachedSpec.isSatisfiedBy(user)  // Returns cached value
```

## Best Practices

### Use Structured Concurrency

```swift
// ✅ Good - use async/let for concurrent operations
async let check1 = spec1.isSatisfiedBy(user)
async let check2 = spec2.isSatisfiedBy(user)
let (result1, result2) = try await (check1, check2)

// ❌ Avoid - sequential when could be concurrent
let result1 = try await spec1.isSatisfiedBy(user)
let result2 = try await spec2.isSatisfiedBy(user)
```

### Handle Errors Appropriately

```swift
// ✅ Good - specific error handling
do {
    return try await spec.isSatisfiedBy(user)
} catch is NetworkError {
    return false  // Safe default for network errors
} catch is DatabaseError {
    throw  // Propagate database errors
}

// ❌ Avoid - swallowing all errors silently
let result = (try? await spec.isSatisfiedBy(user)) ?? false
```

### Provide Cancellation Support

```swift
// ✅ Good - check for cancellation
func isSatisfiedBy(_ user: User) async throws -> Bool {
    try Task.checkCancellation()

    let data = try await fetchData(for: user)

    try Task.checkCancellation()

    return processData(data)
}
```

## Performance Considerations

- **Concurrent Evaluation**: Use async/let to evaluate multiple async specs concurrently
- **Caching**: Cache results of expensive async operations when appropriate
- **Timeouts**: Add timeouts to prevent indefinite waiting
- **Cancellation**: Support task cancellation for long-running operations
- **Resource Management**: Clean up resources properly in async contexts

## Topics

### Essential Protocol

- ``isSatisfiedBy(_:)``

### Type Erasure

- ``AnyAsyncSpecification``

### Property Wrappers

- ``AsyncSatisfies``

### Bridging

- ``AnyAsyncSpecification/init(_:)`` (from Specification)

### Related Protocols

- ``Specification``

## See Also

- <doc:Specification>
- ``AsyncSatisfies``
- ``AnyAsyncSpecification``
