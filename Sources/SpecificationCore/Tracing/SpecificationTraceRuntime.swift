#if Tracing
    import Foundation

    /// The outcome of one specification evaluation.
    public enum SpecificationTraceOutcome: Equatable, Sendable {
        case satisfied
        case unsatisfied
        case selected
        case noMatch
        case skipped
        case failed(String)
        case cancelled
    }

    /// One node in a specification evaluation tree. IDs are local to a recorder.
    public struct SpecificationTraceEvent: Sendable {
        public let id: Int
        public let parentID: Int?
        public let name: String
        public let outcome: SpecificationTraceOutcome
        public let durationNanoseconds: UInt64

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

        public init() {}

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

    /// Runs evaluations in a trace scope. Calls without a scope do not record events.
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

        public static func withBoolean(_ name: String, _ operation: () -> Bool) -> Bool {
            guard let context else { return operation() }
            let id = context.recorder.reserveID()
            let start = DispatchTime.now().uptimeNanoseconds
            let result = $context.withValue(Context(recorder: context.recorder, parentID: id), operation: operation)
            finish(id, context, name, result ? .satisfied : .unsatisfied, start)
            return result
        }

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

        public static func withDecision<Result>(_ name: String, _ operation: () -> Result?) -> Result? {
            guard let context else { return operation() }
            let id = context.recorder.reserveID()
            let start = DispatchTime.now().uptimeNanoseconds
            let result = $context.withValue(Context(recorder: context.recorder, parentID: id), operation: operation)
            finish(id, context, name, result == nil ? .noMatch : .selected, start)
            return result
        }

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

        public static func evaluate<S: Specification>(
            _ specification: S,
            _ candidate: S.T,
            recordingTo recorder: SpecificationTraceRecorder
        ) -> Bool {
            $context.withValue(Context(recorder: recorder, parentID: nil)) {
                withBoolean(String(reflecting: S.self)) { specification.isSatisfiedBy(candidate) }
            }
        }

        public static func evaluateAsync<S: AsyncSpecification>(
            _ specification: S,
            _ candidate: S.T,
            recordingTo recorder: SpecificationTraceRecorder
        ) async throws -> Bool {
            try await $context.withValue(Context(recorder: recorder, parentID: nil)) {
                try await withBoolean(String(reflecting: S.self)) { try await specification.isSatisfiedBy(candidate) }
            }
        }

        public static func decide<S: DecisionSpec>(
            _ specification: S,
            _ candidate: S.Context,
            recordingTo recorder: SpecificationTraceRecorder
        ) -> S.Result? {
            $context.withValue(Context(recorder: recorder, parentID: nil)) {
                withDecision(String(reflecting: S.self)) { specification.decide(candidate) }
            }
        }

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

        public init(_ base: Base, name: String) {
            self.base = base
            self.name = name
        }

        public func isSatisfiedBy(_ candidate: T) -> Bool {
            SpecificationTraceRuntime.withBoolean(name) { base.isSatisfiedBy(candidate) }
        }
    }

    public extension Specification {
        func traced(_ name: String) -> TracedSpecification<Self> {
            TracedSpecification(self, name: name)
        }
    }

    /// A named wrapper for an asynchronous specification.
    public struct TracedAsyncSpecification<Base: AsyncSpecification>: AsyncSpecification {
        public typealias T = Base.T
        private let base: Base
        private let name: String

        public init(_ base: Base, name: String) {
            self.base = base
            self.name = name
        }

        public func isSatisfiedBy(_ candidate: T) async throws -> Bool {
            try await SpecificationTraceRuntime.withBoolean(name) { try await base.isSatisfiedBy(candidate) }
        }
    }

    public extension AsyncSpecification {
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

        public init(_ base: Base, name: String) {
            self.base = base
            self.name = name
        }

        public func decide(_ context: Context) -> Result? {
            SpecificationTraceRuntime.withDecision(name) { base.decide(context) }
        }
    }

    public extension DecisionSpec {
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

        public init(_ base: Base, name: String) {
            self.base = base
            self.name = name
        }

        public func decide(_ context: Context) async throws -> Result? {
            try await SpecificationTraceRuntime.withDecision(name) { try await base.decide(context) }
        }
    }

    public extension AsyncDecisionSpec {
        func traced(_ name: String) -> TracedAsyncDecisionSpec<Self> {
            TracedAsyncDecisionSpec(self, name: name)
        }
    }
#endif
