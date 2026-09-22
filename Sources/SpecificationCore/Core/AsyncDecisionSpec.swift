import Foundation

/// A specification that asynchronously produces a typed result when it applies.
public protocol AsyncDecisionSpec {
    /// The type of context this decision evaluates.
    associatedtype Context

    /// The type of result this decision produces.
    associatedtype Result

    /// Evaluates this decision for the given context.
    func decide(_ context: Context) async throws -> Result?
}

/// A type-erased asynchronous decision specification.
public struct AnyAsyncDecisionSpec<Context, Result>: AsyncDecisionSpec {
    private let _decide: (Context) async throws -> Result?
    #if Tracing
        private let traceName: String
    #endif

    /// Creates a type-erased decision from an asynchronous closure.
    public init(_ decide: @escaping (Context) async throws -> Result?) {
        _decide = decide
        #if Tracing
            traceName = "async decision predicate"
        #endif
    }

    /// Creates a type-erased decision wrapping another asynchronous decision specification.
    public init<S: AsyncDecisionSpec>(_ specification: S)
        where S.Context == Context, S.Result == Result
    {
        _decide = specification.decide
        #if Tracing
            traceName = String(reflecting: S.self)
        #endif
    }

    /// Bridges a synchronous decision specification into an asynchronous decision.
    public init<S: DecisionSpec>(_ specification: S)
        where S.Context == Context, S.Result == Result
    {
        _decide = { context in specification.decide(context) }
        #if Tracing
            traceName = String(reflecting: S.self)
        #endif
    }

    public func decide(_ context: Context) async throws -> Result? {
        #if Tracing
            return try await SpecificationTraceRuntime.withDecision(traceName) {
                try Task.checkCancellation()
                let result = try await _decide(context)
                try Task.checkCancellation()
                return result
            }
        #else
            try Task.checkCancellation()
            let result = try await _decide(context)
            try Task.checkCancellation()
            return result
        #endif
    }
}

/// Adapts an asynchronous boolean specification to a typed decision.
public struct AsyncBooleanDecisionAdapter<S: AsyncSpecification, Result>: AsyncDecisionSpec {
    public typealias Context = S.T

    private let specification: S
    private let result: Result

    /// Creates an adapter that returns `result` when `specification` is satisfied.
    public init(specification: S, result: Result) {
        self.specification = specification
        self.result = result
    }

    public func decide(_ context: Context) async throws -> Result? {
        #if Tracing
            return try await SpecificationTraceRuntime.withDecision(String(reflecting: S.self)) {
                try Task.checkCancellation()
                let isSatisfied = try await specification.isSatisfiedBy(context)
                try Task.checkCancellation()
                return isSatisfied ? result : nil
            }
        #else
            try Task.checkCancellation()
            let isSatisfied = try await specification.isSatisfiedBy(context)
            try Task.checkCancellation()
            return isSatisfied ? result : nil
        #endif
    }
}
