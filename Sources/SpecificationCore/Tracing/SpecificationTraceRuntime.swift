#if Tracing
    import Foundation

    /// The outcome of one specification evaluation or an intentionally skipped branch.
    public enum SpecificationTraceOutcome: Equatable, Sendable {
        /// A Boolean specification returned `true`.
        case satisfied
        /// A Boolean specification returned `false`.
        case unsatisfied
        /// A decision specification returned a result.
        case selected
        /// A decision specification returned `nil`.
        case noMatch
        /// A short-circuited branch was not evaluated.
        case skipped
        /// An evaluation threw an error; the associated value is its type name.
        case failed(String)
        /// An evaluation threw `CancellationError`.
        case cancelled
    }

    /// One node in a specification evaluation tree. IDs are local to a recorder.
    public struct SpecificationTraceEvent: Sendable {
        /// The event's unique ID within its recorder.
        public let id: Int
        /// The enclosing event's ID, or `nil` for a root event.
        public let parentID: Int?
        /// A caller-supplied name or reflected specification type name.
        public let name: String
        /// The recorded result, failure, or skipped state.
        public let outcome: SpecificationTraceOutcome
        /// The measured duration; zero for a skipped branch.
        public let durationNanoseconds: UInt64

        /// Creates a trace event for an external event consumer or adapter.
        public init(
            id: Int,
            parentID: Int?,
            name: String,
            outcome: SpecificationTraceOutcome,
            durationNanoseconds: UInt64
        ) {
            self.id = id
            self.parentID = parentID
            self.name = name
            self.outcome = outcome
            self.durationNanoseconds = durationNanoseconds
        }
    }

    /// Thread-safe storage for events from one or more evaluations.
    public final class SpecificationTraceRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var nextID = 0
        private var storedEvents: [SpecificationTraceEvent] = []

        /// Creates an empty recorder that may be shared across tasks.
        public init() {}

        /// A snapshot of completed events in recorder-local ID order.
        public var events: [SpecificationTraceEvent] {
            lock.lock()
            defer { lock.unlock() }
            return storedEvents.sorted { $0.id < $1.id }
        }

        fileprivate func reserveID() -> Int {
            lock.lock()
            defer { lock.unlock() }
            nextID += 1
            return nextID
        }

        fileprivate func append(_ event: SpecificationTraceEvent) {
            lock.lock()
            defer { lock.unlock() }
            storedEvents.append(event)
        }
    }

    /// Runs evaluations in a trace scope and records nested specification events.
    /// Calls without a scope do not record events.
    public enum SpecificationTraceRuntime {
        private struct Context: Sendable {
            let recorder: SpecificationTraceRecorder
            let parentID: Int?
        }

        @TaskLocal private static var context: Context?

        private static func finish(
            _ id: Int,
            _ context: Context,
            _ name: String,
            _ outcome: SpecificationTraceOutcome,
            _ start: UInt64
        ) {
            context.recorder.append(SpecificationTraceEvent(
                id: id,
                parentID: context.parentID,
                name: name,
                outcome: outcome,
                durationNanoseconds: DispatchTime.now().uptimeNanoseconds - start
            ))
        }

        /// Records a synchronous Boolean operation as a child of the current scope.
        /// Outside a scope, runs the operation without recording.
        public static func withBoolean(_ name: String, _ operation: () -> Bool) -> Bool {
            guard let context else { return operation() }
            let id = context.recorder.reserveID()
            let start = DispatchTime.now().uptimeNanoseconds
            let result = $context.withValue(Context(recorder: context.recorder, parentID: id), operation: operation)
            finish(id, context, name, result ? .satisfied : .unsatisfied, start)
            return result
        }

        /// Records an asynchronous Boolean operation as a child of the current scope.
        public static func withBoolean(_ name: String, _ operation: () async -> Bool) async -> Bool {
            guard let context else { return await operation() }
            let id = context.recorder.reserveID()
            let start = DispatchTime.now().uptimeNanoseconds
            let result = await $context.withValue(
                Context(recorder: context.recorder, parentID: id),
                operation: operation
            )
            finish(id, context, name, result ? .satisfied : .unsatisfied, start)
            return result
        }

        /// Records an asynchronous throwing Boolean operation and propagates its error.
        /// A thrown `CancellationError` receives the `cancelled` outcome.
        public static func withBoolean(_ name: String, _ operation: () async throws -> Bool) async throws -> Bool {
            guard let context else { return try await operation() }
            let id = context.recorder.reserveID()
            let start = DispatchTime.now().uptimeNanoseconds
            do {
                let result = try await $context.withValue(
                    Context(recorder: context.recorder, parentID: id),
                    operation: operation
                )
                finish(id, context, name, result ? .satisfied : .unsatisfied, start)
                return result
            } catch {
                finish(
                    id,
                    context,
                    name,
                    error is CancellationError ? .cancelled : .failed(String(reflecting: type(of: error))),
                    start
                )
                throw error
            }
        }

        /// Records a synchronous optional decision as selected or unmatched.
        public static func withDecision<Result>(_ name: String, _ operation: () -> Result?) -> Result? {
            guard let context else { return operation() }
            let id = context.recorder.reserveID()
            let start = DispatchTime.now().uptimeNanoseconds
            let result = $context.withValue(Context(recorder: context.recorder, parentID: id), operation: operation)
            finish(id, context, name, result == nil ? .noMatch : .selected, start)
            return result
        }

        /// Records an asynchronous optional decision as selected or unmatched.
        public static func withDecision<Result>(_ name: String, _ operation: () async -> Result?) async -> Result? {
            guard let context else { return await operation() }
            let id = context.recorder.reserveID()
            let start = DispatchTime.now().uptimeNanoseconds
            let result = await $context.withValue(
                Context(recorder: context.recorder, parentID: id),
                operation: operation
            )
            finish(id, context, name, result == nil ? .noMatch : .selected, start)
            return result
        }

        /// Records an asynchronous throwing decision and propagates its error.
        public static func withDecision<Result>(
            _ name: String,
            _ operation: () async throws -> Result?
        ) async throws -> Result? {
            guard let context else { return try await operation() }
            let id = context.recorder.reserveID()
            let start = DispatchTime.now().uptimeNanoseconds
            do {
                let result = try await $context.withValue(
                    Context(recorder: context.recorder, parentID: id),
                    operation: operation
                )
                finish(id, context, name, result == nil ? .noMatch : .selected, start)
                return result
            } catch {
                finish(
                    id,
                    context,
                    name,
                    error is CancellationError ? .cancelled : .failed(String(reflecting: type(of: error))),
                    start
                )
                throw error
            }
        }

        /// Records a branch that short-circuit evaluation did not execute.
        /// Outside a trace scope, this method has no effect.
        public static func skip(_ name: String) {
            guard let context else { return }
            let id = context.recorder.reserveID()
            context.recorder.append(SpecificationTraceEvent(
                id: id,
                parentID: context.parentID,
                name: name,
                outcome: .skipped,
                durationNanoseconds: 0
            ))
        }

        /// Evaluates a synchronous specification in a new root trace scope.
        public static func evaluate<S: Specification>(
            _ specification: S,
            _ candidate: S.T,
            recordingTo recorder: SpecificationTraceRecorder
        ) -> Bool {
            $context.withValue(Context(recorder: recorder, parentID: nil)) {
                withBoolean(String(reflecting: S.self)) { specification.isSatisfiedBy(candidate) }
            }
        }

        /// Evaluates an asynchronous specification in a new root trace scope.
        /// Errors, including cancellation, are recorded and then rethrown.
        public static func evaluateAsync<S: AsyncSpecification>(
            _ specification: S,
            _ candidate: S.T,
            recordingTo recorder: SpecificationTraceRecorder
        ) async throws -> Bool {
            try await $context.withValue(Context(recorder: recorder, parentID: nil)) {
                try await withBoolean(String(reflecting: S.self)) { try await specification.isSatisfiedBy(candidate) }
            }
        }

        /// Evaluates a synchronous decision specification in a new root trace scope.
        public static func decide<S: DecisionSpec>(
            _ specification: S,
            _ candidate: S.Context,
            recordingTo recorder: SpecificationTraceRecorder
        ) -> S.Result? {
            $context.withValue(Context(recorder: recorder, parentID: nil)) {
                withDecision(String(reflecting: S.self)) { specification.decide(candidate) }
            }
        }

        /// Evaluates an asynchronous decision specification in a new root trace scope.
        /// Errors, including cancellation, are recorded and then rethrown.
        public static func decideAsync<S: AsyncDecisionSpec>(
            _ specification: S,
            _ candidate: S.Context,
            recordingTo recorder: SpecificationTraceRecorder
        ) async throws -> S.Result? {
            try await $context.withValue(Context(recorder: recorder, parentID: nil)) {
                try await withDecision(String(reflecting: S.self)) { try await specification.decide(candidate) }
            }
        }
    }

    /// A named wrapper for a synchronous specification.
    public struct TracedSpecification<Base: Specification>: Specification {
        public typealias T = Base.T
        private let base: Base
        private let name: String

        /// Wraps a specification with a stable name for its trace event.
        public init(_ base: Base, name: String) {
            self.base = base
            self.name = name
        }

        /// Returns the base specification's result and records it within a trace scope.
        public func isSatisfiedBy(_ candidate: T) -> Bool {
            SpecificationTraceRuntime.withBoolean(name) { base.isSatisfiedBy(candidate) }
        }
    }

    public extension Specification {
        /// Returns a named tracing wrapper around this specification.
        func traced(_ name: String) -> TracedSpecification<Self> {
            TracedSpecification(self, name: name)
        }
    }

    /// A named wrapper for an asynchronous specification.
    public struct TracedAsyncSpecification<Base: AsyncSpecification>: AsyncSpecification {
        public typealias T = Base.T
        private let base: Base
        private let name: String

        /// Wraps an asynchronous specification with a stable trace name.
        public init(_ base: Base, name: String) {
            self.base = base
            self.name = name
        }

        /// Returns the base result and propagates errors after recording them.
        public func isSatisfiedBy(_ candidate: T) async throws -> Bool {
            try await SpecificationTraceRuntime.withBoolean(name) { try await base.isSatisfiedBy(candidate) }
        }
    }

    public extension AsyncSpecification {
        /// Returns a named tracing wrapper around this asynchronous specification.
        func traced(_ name: String) -> TracedAsyncSpecification<Self> {
            TracedAsyncSpecification(self, name: name)
        }
    }

    /// A named wrapper for a synchronous decision specification.
    public struct TracedDecisionSpec<Base: DecisionSpec>: DecisionSpec {
        public typealias Context = Base.Context
        public typealias Result = Base.Result
        private let base: Base
        private let name: String

        /// Wraps a decision specification with a stable trace name.
        public init(_ base: Base, name: String) {
            self.base = base
            self.name = name
        }

        /// Returns the base decision and records whether it selected a result.
        public func decide(_ context: Context) -> Result? {
            SpecificationTraceRuntime.withDecision(name) { base.decide(context) }
        }
    }

    public extension DecisionSpec {
        /// Returns a named tracing wrapper around this decision specification.
        func traced(_ name: String) -> TracedDecisionSpec<Self> {
            TracedDecisionSpec(self, name: name)
        }
    }

    /// A named wrapper for an asynchronous decision specification.
    public struct TracedAsyncDecisionSpec<Base: AsyncDecisionSpec>: AsyncDecisionSpec {
        public typealias Context = Base.Context
        public typealias Result = Base.Result
        private let base: Base
        private let name: String

        /// Wraps an asynchronous decision specification with a stable trace name.
        public init(_ base: Base, name: String) {
            self.base = base
            self.name = name
        }

        /// Returns the base decision and propagates errors after recording them.
        public func decide(_ context: Context) async throws -> Result? {
            try await SpecificationTraceRuntime.withDecision(name) { try await base.decide(context) }
        }
    }

    public extension AsyncDecisionSpec {
        /// Returns a named tracing wrapper around this asynchronous decision specification.
        func traced(_ name: String) -> TracedAsyncDecisionSpec<Self> {
            TracedAsyncDecisionSpec(self, name: name)
        }
    }
#endif
