import Foundation

/// A protocol for specifications that require asynchronous evaluation.
///
/// `AsyncSpecification` extends the specification pattern to support async operations
/// such as network requests, database queries, file I/O, or any evaluation that
/// needs to be performed asynchronously. This protocol follows the same pattern
/// as `Specification` but allows for async/await and error handling.
///
/// ## Usage Examples
///
/// ### Network-Based Specification
/// ```swift
/// struct RemoteFeatureFlagSpec: AsyncSpecification {
///     typealias T = EvaluationContext
///
///     let flagKey: String
///     let apiClient: APIClient
///
///     func isSatisfiedBy(_ context: EvaluationContext) async throws -> Bool {
///         let flags = try await apiClient.fetchFeatureFlags(for: context.userId)
///         return flags[flagKey] == true
///     }
/// }
///
/// @AsyncSatisfies(using: RemoteFeatureFlagSpec(flagKey: "premium_features", apiClient: client))
/// var hasPremiumFeatures: Bool
///
/// let isEligible = try await $hasPremiumFeatures.evaluateAsync()
/// ```
///
/// ### Database Query Specification
/// ```swift
/// struct UserSubscriptionSpec: AsyncSpecification {
///     typealias T = EvaluationContext
///
///     let database: Database
///
///     func isSatisfiedBy(_ context: EvaluationContext) async throws -> Bool {
///         let subscription = try await database.fetchSubscription(userId: context.userId)
///         return subscription?.isActive == true && !subscription.isExpired
///     }
/// }
/// ```
///
/// ### Complex Async Logic with Multiple Sources
/// ```swift
/// struct EligibilityCheckSpec: AsyncSpecification {
///     typealias T = EvaluationContext
///
///     let userService: UserService
///     let billingService: BillingService
///
///     func isSatisfiedBy(_ context: EvaluationContext) async throws -> Bool {
///         async let userProfile = userService.fetchProfile(context.userId)
///         async let billingStatus = billingService.checkStatus(context.userId)
///
///         let (profile, billing) = try await (userProfile, billingStatus)
///
///         return profile.isVerified && billing.isGoodStanding
///     }
/// }
/// ```
public protocol AsyncSpecification {
    /// The type of candidate that this specification evaluates
    associatedtype T

    /// Asynchronously determines whether the given candidate satisfies this specification
    /// - Parameter candidate: The candidate to evaluate
    /// - Returns: `true` if the candidate satisfies the specification, `false` otherwise
    /// - Throws: Any error that occurs during evaluation
    func isSatisfiedBy(_ candidate: T) async throws -> Bool
}

// MARK: - Composition

public extension AsyncSpecification {
    /// Creates an asynchronous specification that requires both specifications to be satisfied.
    func andAsync<Other: AsyncSpecification>(_ other: Other) -> AsyncAndSpecification<Self, Other>
        where Other.T == T
    {
        AsyncAndSpecification(left: self, right: other)
    }

    /// Creates an asynchronous specification that is satisfied when either specification is satisfied.
    func orAsync<Other: AsyncSpecification>(_ other: Other) -> AsyncOrSpecification<Self, Other>
        where Other.T == T
    {
        AsyncOrSpecification(left: self, right: other)
    }

    /// Creates an asynchronous specification that negates this specification.
    func notAsync() -> AsyncNotSpecification<Self> {
        AsyncNotSpecification(wrapped: self)
    }

    /// Returns the given result when this asynchronous specification is satisfied.
    func returningAsync<Result>(_ result: Result) -> AsyncBooleanDecisionAdapter<Self, Result> {
        AsyncBooleanDecisionAdapter(specification: self, result: result)
    }
}

/// An asynchronous specification that combines two specifications using logical AND.
public struct AsyncAndSpecification<Left: AsyncSpecification, Right: AsyncSpecification>: AsyncSpecification
    where Left.T == Right.T
{
    public typealias T = Left.T

    private let left: Left
    private let right: Right

    init(left: Left, right: Right) {
        self.left = left
        self.right = right
    }

    public func isSatisfiedBy(_ candidate: T) async throws -> Bool {
        #if Tracing
            return try await SpecificationTraceRuntime.withBoolean("ASYNC AND") {
                try Task.checkCancellation()
                let first = try await SpecificationTraceRuntime.evaluateChild(
                    left, candidate, name: String(reflecting: Left.self)
                )
                try Task.checkCancellation()
                guard first else {
                    if !SpecificationTraceRuntime.isExcluded(right) {
                        SpecificationTraceRuntime.skip(String(reflecting: Right.self))
                    }
                    return false
                }
                let second = try await SpecificationTraceRuntime.evaluateChild(
                    right, candidate, name: String(reflecting: Right.self)
                )
                try Task.checkCancellation()
                return second
            }
        #else
            try Task.checkCancellation()
            let leftIsSatisfied = try await left.isSatisfiedBy(candidate)
            try Task.checkCancellation()
            guard leftIsSatisfied else { return false }
            try Task.checkCancellation()
            let rightIsSatisfied = try await right.isSatisfiedBy(candidate)
            try Task.checkCancellation()
            return rightIsSatisfied
        #endif
    }
}

/// An asynchronous specification that combines two specifications using logical OR.
public struct AsyncOrSpecification<Left: AsyncSpecification, Right: AsyncSpecification>: AsyncSpecification
    where Left.T == Right.T
{
    public typealias T = Left.T

    private let left: Left
    private let right: Right

    init(left: Left, right: Right) {
        self.left = left
        self.right = right
    }

    public func isSatisfiedBy(_ candidate: T) async throws -> Bool {
        #if Tracing
            return try await SpecificationTraceRuntime.withBoolean("ASYNC OR") {
                try Task.checkCancellation()
                let first = try await SpecificationTraceRuntime.evaluateChild(
                    left, candidate, name: String(reflecting: Left.self)
                )
                try Task.checkCancellation()
                if first {
                    if !SpecificationTraceRuntime.isExcluded(right) {
                        SpecificationTraceRuntime.skip(String(reflecting: Right.self))
                    }
                    return true
                }
                let second = try await SpecificationTraceRuntime.evaluateChild(
                    right, candidate, name: String(reflecting: Right.self)
                )
                try Task.checkCancellation()
                return second
            }
        #else
            try Task.checkCancellation()
            let leftIsSatisfied = try await left.isSatisfiedBy(candidate)
            try Task.checkCancellation()
            if leftIsSatisfied {
                return true
            }
            try Task.checkCancellation()
            let rightIsSatisfied = try await right.isSatisfiedBy(candidate)
            try Task.checkCancellation()
            return rightIsSatisfied
        #endif
    }
}

/// An asynchronous specification that negates another specification.
public struct AsyncNotSpecification<Wrapped: AsyncSpecification>: AsyncSpecification {
    public typealias T = Wrapped.T

    private let wrapped: Wrapped

    init(wrapped: Wrapped) {
        self.wrapped = wrapped
    }

    public func isSatisfiedBy(_ candidate: T) async throws -> Bool {
        #if Tracing
            return try await SpecificationTraceRuntime.withBoolean("ASYNC NOT") {
                try Task.checkCancellation()
                let result = try await SpecificationTraceRuntime.evaluateChild(
                    wrapped, candidate, name: String(reflecting: Wrapped.self)
                )
                try Task.checkCancellation()
                return !result
            }
        #else
            try Task.checkCancellation()
            let isSatisfied = try await wrapped.isSatisfiedBy(candidate)
            try Task.checkCancellation()
            return !isSatisfied
        #endif
    }
}

/// A type-erased wrapper for any asynchronous specification.
///
/// `AnyAsyncSpecification` allows you to store async specifications of different
/// concrete types in the same collection or use them in contexts where the
/// specific type isn't known at compile time. It also provides bridging from
/// synchronous specifications to async context.
///
/// ## Usage Examples
///
/// ### Type Erasure for Collections
/// ```swift
/// let asyncSpecs: [AnyAsyncSpecification<EvaluationContext>] = [
///     AnyAsyncSpecification(RemoteFeatureFlagSpec(flagKey: "feature_a")),
///     AnyAsyncSpecification(DatabaseUserSpec()),
///     AnyAsyncSpecification(MaxCountSpec(counterKey: "attempts", maximumCount: 3)) // sync spec
/// ]
///
/// for spec in asyncSpecs {
///     let result = try await spec.isSatisfiedBy(context)
///     print("Spec satisfied: \(result)")
/// }
/// ```
///
/// ### Bridging Synchronous Specifications
/// ```swift
/// let syncSpec = MaxCountSpec(counterKey: "login_attempts", maximumCount: 3)
/// let asyncSpec = AnyAsyncSpecification(syncSpec) // Bridge to async
///
/// let isAllowed = try await asyncSpec.isSatisfiedBy(context)
/// ```
///
/// ### Custom Async Logic
/// ```swift
/// let customAsyncSpec = AnyAsyncSpecification<EvaluationContext> { context in
///     // Simulate async network call
///     try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
///     return context.flag(for: "delayed_feature") == true
/// }
/// ```
public struct AnyAsyncSpecification<T>: AsyncSpecification {
    private let _isSatisfied: (T) async throws -> Bool
    #if Tracing
        private let traceName: String
        private let traceExcluded: Bool
    #endif

    /// Creates a type-erased async specification wrapping the given async specification.
    /// - Parameter spec: The async specification to wrap
    public init<S: AsyncSpecification>(_ spec: S) where S.T == T {
        _isSatisfied = spec.isSatisfiedBy
        #if Tracing
            traceName = String(reflecting: S.self)
            traceExcluded = SpecificationTraceRuntime.isExcluded(spec)
        #endif
    }

    /// Creates a type-erased async specification from an async closure.
    /// - Parameter predicate: An async closure that takes a candidate and returns whether it satisfies the
    /// specification
    public init(_ predicate: @escaping (T) async throws -> Bool) {
        _isSatisfied = predicate
        #if Tracing
            traceName = "async predicate"
            traceExcluded = false
        #endif
    }

    public func isSatisfiedBy(_ candidate: T) async throws -> Bool {
        #if Tracing
            if traceExcluded {
                return try await SpecificationTraceRuntime.withoutRecording { try await _isSatisfied(candidate) }
            }
            return try await SpecificationTraceRuntime.withBoolean(traceName) {
                try await _isSatisfied(candidate)
            }
        #else
            try await _isSatisfied(candidate)
        #endif
    }
}

// MARK: - Bridging

public extension AnyAsyncSpecification {
    /// Bridge a synchronous specification to async form.
    init<S: Specification>(_ spec: S) where S.T == T {
        _isSatisfied = { candidate in spec.isSatisfiedBy(candidate) }
        #if Tracing
            traceName = String(reflecting: S.self)
            traceExcluded = SpecificationTraceRuntime.isExcluded(spec)
        #endif
    }
}

#if Tracing
    extension AnyAsyncSpecification: SpecificationTraceExclusion {
        var excludesSpecificationTracing: Bool {
            traceExcluded
        }
    }
#endif
