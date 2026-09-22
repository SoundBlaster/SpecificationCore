import Foundation

/// Evaluates asynchronous specifications in order and returns the result for the first match.
public struct AsyncFirstMatchSpec<Context, Result>: AsyncDecisionSpec {
    /// A pair containing an asynchronous specification and the result associated with it.
    public typealias SpecificationPair = (specification: AnyAsyncSpecification<Context>, result: Result)

    private let pairs: [SpecificationPair]

    /// Creates a first-match decision from type-erased specification-result pairs.
    public init(_ pairs: [SpecificationPair]) {
        self.pairs = pairs
    }

    /// Creates a first-match decision from specifications of one concrete type.
    public init<S: AsyncSpecification>(_ pairs: [(S, Result)]) where S.T == Context {
        let specificationPairs: [SpecificationPair] = pairs.map {
            (specification: AnyAsyncSpecification($0.0), result: $0.1)
        }
        self.init(specificationPairs)
    }

    /// Returns the result of the first satisfied specification, or `nil` if none match.
    public func decide(_ context: Context) async throws -> Result? {
        try await decideWithMetadata(context)?.result
    }

    /// Returns the first matching result and its zero-based position in the configured pairs.
    public func decideWithMetadata(_ context: Context) async throws -> (result: Result, index: Int)? {
        #if Tracing
            return try await SpecificationTraceRuntime.withDecision("AsyncFirstMatchSpec") {
                try Task.checkCancellation()
                for (index, pair) in pairs.enumerated() {
                    try Task.checkCancellation()
                    let matched = try await SpecificationTraceRuntime.withBoolean("pair[\(index)]") {
                        try await pair.specification.isSatisfiedBy(context)
                    }
                    try Task.checkCancellation()
                    if matched {
                        for skippedIndex in pairs.indices where skippedIndex > index {
                            SpecificationTraceRuntime.skip("pair[\(skippedIndex)]")
                        }
                        return (pair.result, index)
                    }
                }
                return nil
            }
        #else
            try Task.checkCancellation()
            for (index, pair) in pairs.enumerated() {
                try Task.checkCancellation()
                let isSatisfied = try await pair.specification.isSatisfiedBy(context)
                try Task.checkCancellation()
                if isSatisfied {
                    return (pair.result, index)
                }
            }
            return nil
        #endif
    }

    /// Creates a first-match decision that returns `fallback` when none of the pairs match.
    public static func withFallback(
        _ pairs: [SpecificationPair],
        fallback: Result
    ) -> AsyncFirstMatchSpec<Context, Result> {
        var allPairs = pairs
        allPairs.append((specification: AnyAsyncSpecification(AlwaysTrueSpec<Context>()), result: fallback))
        return AsyncFirstMatchSpec(allPairs)
    }
}

// MARK: - Builder

public extension AsyncFirstMatchSpec {
    /// A builder for asynchronous first-match decisions.
    final class Builder<C, R> {
        private var pairs: [AsyncFirstMatchSpec<C, R>.SpecificationPair] = []

        public init() {}

        /// Adds an asynchronous specification and its associated result.
        @discardableResult
        public func add<S: AsyncSpecification>(_ specification: S, result: R) -> Builder where S.T == C {
            pairs.append((specification: AnyAsyncSpecification(specification), result: result))
            return self
        }

        /// Adds a synchronous specification and its associated result.
        @discardableResult
        public func addSync<S: Specification>(_ specification: S, result: R) -> Builder where S.T == C {
            pairs.append((specification: AnyAsyncSpecification(specification), result: result))
            return self
        }

        /// Adds an asynchronous predicate and its associated result.
        @discardableResult
        public func addPredicate(
            _ predicate: @escaping (C) async throws -> Bool,
            result: R
        ) -> Builder {
            pairs.append((specification: AnyAsyncSpecification(predicate), result: result))
            return self
        }

        /// Adds a fallback result evaluated after all other pairs.
        @discardableResult
        public func fallback(_ result: R) -> Builder {
            pairs.append((specification: AnyAsyncSpecification(AlwaysTrueSpec<C>()), result: result))
            return self
        }

        /// Builds the configured asynchronous first-match decision.
        public func build() -> AsyncFirstMatchSpec<C, R> {
            AsyncFirstMatchSpec<C, R>(pairs)
        }
    }

    /// Creates a builder for constructing an asynchronous first-match decision.
    static func builder() -> Builder<Context, Result> {
        Builder<Context, Result>()
    }
}
