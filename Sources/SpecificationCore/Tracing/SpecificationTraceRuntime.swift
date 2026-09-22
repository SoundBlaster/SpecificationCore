#if Tracing
    import Foundation

    protocol SpecificationTraceExclusion {
        var excludesSpecificationTracing: Bool { get }
    }

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

    /// Records instrumented specifications in an explicit scope or with a
    /// process-wide default recorder.
    public enum SpecificationTraceRuntime {
        private struct Context: Sendable {
            let recorder: SpecificationTraceRecorder
            let parentID: Int?
        }

        private final class DefaultRecorderStorage: @unchecked Sendable {
            let lock = NSLock()
            var recorder: SpecificationTraceRecorder?
        }

        @TaskLocal private static var context: Context?
        @TaskLocal private static var recordingSuppressed = false
        private static let defaultRecorderStorage = DefaultRecorderStorage()

        /// The process-wide recorder used when an explicit trace scope is absent.
        ///
        /// Set this once at application startup to trace instrumented evaluations
        /// without changing their call sites. Set it to `nil` to stop recording.
        /// Explicit `evaluate` and `decide` calls take precedence for their task.
        /// The runtime holds the recorder strongly while it is configured.
        public static var defaultRecorder: SpecificationTraceRecorder? {
            get {
                defaultRecorderStorage.lock.lock()
                defer { defaultRecorderStorage.lock.unlock() }
                return defaultRecorderStorage.recorder
            }
            set {
                defaultRecorderStorage.lock.lock()
                defer { defaultRecorderStorage.lock.unlock() }
                defaultRecorderStorage.recorder = newValue
            }
        }

        private static var activeContext: Context? {
            guard !recordingSuppressed else {
                return nil
            }
            if let context {
                return context
            }
            return defaultRecorder.map { Context(recorder: $0, parentID: nil) }
        }

        @usableFromInline
        static func isExcluded(_ specification: Any) -> Bool {
            (specification as? any SpecificationTraceExclusion)?.excludesSpecificationTracing == true
        }

        /// Evaluates an operation without recording it or any nested events.
        public static func withoutRecording<Result>(_ operation: () -> Result) -> Result {
            $recordingSuppressed.withValue(true, operation: operation)
        }

        /// Evaluates an asynchronous operation without recording nested events.
        public static func withoutRecording<Result>(_ operation: () async throws -> Result) async rethrows -> Result {
            try await $recordingSuppressed.withValue(true, operation: operation)
        }

        @usableFromInline
        static func evaluateChild<S: Specification>(_ specification: S, _ candidate: S.T, name: String) -> Bool {
            if isExcluded(specification) {
                return withoutRecording { specification.isSatisfiedBy(candidate) }
            }
            return withBoolean(name) { specification.isSatisfiedBy(candidate) }
        }

        static func evaluateChild<S: AsyncSpecification>(
            _ specification: S,
            _ candidate: S.T,
            name: String
        ) async throws -> Bool {
            if isExcluded(specification) {
                return try await withoutRecording { try await specification.isSatisfiedBy(candidate) }
            }
            return try await withBoolean(name) { try await specification.isSatisfiedBy(candidate) }
        }

        static func decideChild<S: DecisionSpec>(
            _ specification: S,
            _ candidate: S.Context,
            name: String
        ) -> S.Result? {
            if isExcluded(specification) {
                return withoutRecording { specification.decide(candidate) }
            }
            return withDecision(name) { specification.decide(candidate) }
        }

        static func decideChild<S: AsyncDecisionSpec>(
            _ specification: S,
            _ candidate: S.Context,
            name: String
        ) async throws -> S.Result? {
            if isExcluded(specification) {
                return try await withoutRecording { try await specification.decide(candidate) }
            }
            return try await withDecision(name) { try await specification.decide(candidate) }
        }

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

        /// Records a synchronous Boolean operation in the active trace context.
        /// Without an explicit or default recorder, runs without recording.
        public static func withBoolean(_ name: String, _ operation: () -> Bool) -> Bool {
            guard let context = activeContext else { return operation() }
            let id = context.recorder.reserveID()
            let start = DispatchTime.now().uptimeNanoseconds
            let result = $context.withValue(Context(recorder: context.recorder, parentID: id), operation: operation)
            finish(id, context, name, result ? .satisfied : .unsatisfied, start)
            return result
        }

        /// Records an asynchronous Boolean operation in the active trace context.
        public static func withBoolean(_ name: String, _ operation: () async -> Bool) async -> Bool {
            guard let context = activeContext else { return await operation() }
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
            guard let context = activeContext else { return try await operation() }
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
            guard let context = activeContext else { return operation() }
            let id = context.recorder.reserveID()
            let start = DispatchTime.now().uptimeNanoseconds
            let result = $context.withValue(Context(recorder: context.recorder, parentID: id), operation: operation)
            finish(id, context, name, result == nil ? .noMatch : .selected, start)
            return result
        }

        /// Records an asynchronous optional decision as selected or unmatched.
        public static func withDecision<Result>(_ name: String, _ operation: () async -> Result?) async -> Result? {
            guard let context = activeContext else { return await operation() }
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
            guard let context = activeContext else { return try await operation() }
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
        /// Without an explicit or default recorder, this method has no effect.
        public static func skip(_ name: String) {
            guard let context = activeContext else { return }
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
                evaluateChild(specification, candidate, name: String(reflecting: S.self))
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
                try await evaluateChild(specification, candidate, name: String(reflecting: S.self))
            }
        }

        /// Evaluates a synchronous decision specification in a new root trace scope.
        public static func decide<S: DecisionSpec>(
            _ specification: S,
            _ candidate: S.Context,
            recordingTo recorder: SpecificationTraceRecorder
        ) -> S.Result? {
            $context.withValue(Context(recorder: recorder, parentID: nil)) {
                decideChild(specification, candidate, name: String(reflecting: S.self))
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
                try await decideChild(specification, candidate, name: String(reflecting: S.self))
            }
        }
    }

    /// A named wrapper for a synchronous specification.
    public struct TracedSpecification<Base: Specification>: Specification, SpecificationTraceExclusion {
        public typealias T = Base.T
        private let base: Base
        private let name: String
        var excludesSpecificationTracing: Bool {
            SpecificationTraceRuntime.isExcluded(base)
        }

        /// Wraps a specification with a stable name for its trace event.
        public init(_ base: Base, name: String) {
            self.base = base
            self.name = name
        }

        /// Returns the base result and records it when a recorder is active.
        public func isSatisfiedBy(_ candidate: T) -> Bool {
            if excludesSpecificationTracing {
                return SpecificationTraceRuntime.withoutRecording { base.isSatisfiedBy(candidate) }
            }
            return SpecificationTraceRuntime.withBoolean(name) { base.isSatisfiedBy(candidate) }
        }
    }

    public extension Specification {
        /// Returns a named tracing wrapper around this specification.
        func traced(_ name: String) -> TracedSpecification<Self> {
            TracedSpecification(self, name: name)
        }

        /// Returns a wrapper whose evaluation is omitted from traces.
        /// Nested evaluations are also omitted while the wrapper runs.
        func withoutTracing() -> UntracedSpecification<Self> {
            UntracedSpecification(self)
        }
    }

    /// A synchronous specification whose evaluations are excluded from traces.
    public struct UntracedSpecification<Base: Specification>: Specification, SpecificationTraceExclusion {
        public typealias T = Base.T
        let base: Base
        var excludesSpecificationTracing: Bool {
            true
        }

        /// Wraps a specification without changing its evaluation result.
        public init(_ base: Base) {
            self.base = base
        }

        /// Evaluates the base specification without recording its subtree.
        public func isSatisfiedBy(_ candidate: T) -> Bool {
            SpecificationTraceRuntime.withoutRecording { base.isSatisfiedBy(candidate) }
        }
    }

    /// A named wrapper for an asynchronous specification.
    public struct TracedAsyncSpecification<Base: AsyncSpecification>: AsyncSpecification, SpecificationTraceExclusion {
        public typealias T = Base.T
        private let base: Base
        private let name: String
        var excludesSpecificationTracing: Bool {
            SpecificationTraceRuntime.isExcluded(base)
        }

        /// Wraps an asynchronous specification with a stable trace name.
        public init(_ base: Base, name: String) {
            self.base = base
            self.name = name
        }

        /// Returns the base result and propagates errors after recording them.
        public func isSatisfiedBy(_ candidate: T) async throws -> Bool {
            if excludesSpecificationTracing {
                return try await SpecificationTraceRuntime.withoutRecording { try await base.isSatisfiedBy(candidate) }
            }
            return try await SpecificationTraceRuntime.withBoolean(name) { try await base.isSatisfiedBy(candidate) }
        }
    }

    public extension AsyncSpecification {
        /// Returns a named tracing wrapper around this asynchronous specification.
        func traced(_ name: String) -> TracedAsyncSpecification<Self> {
            TracedAsyncSpecification(self, name: name)
        }

        /// Returns a wrapper whose asynchronous evaluation is omitted from traces.
        func withoutTracing() -> UntracedAsyncSpecification<Self> {
            UntracedAsyncSpecification(self)
        }
    }

    /// An asynchronous specification whose evaluations are excluded from traces.
    public struct UntracedAsyncSpecification<Base: AsyncSpecification>: AsyncSpecification,
        SpecificationTraceExclusion
    {
        public typealias T = Base.T
        let base: Base
        var excludesSpecificationTracing: Bool {
            true
        }

        /// Wraps an asynchronous specification without changing its result or errors.
        public init(_ base: Base) {
            self.base = base
        }

        /// Evaluates the base specification without recording its subtree.
        public func isSatisfiedBy(_ candidate: T) async throws -> Bool {
            try await SpecificationTraceRuntime.withoutRecording { try await base.isSatisfiedBy(candidate) }
        }
    }

    /// A named wrapper for a synchronous decision specification.
    public struct TracedDecisionSpec<Base: DecisionSpec>: DecisionSpec, SpecificationTraceExclusion {
        public typealias Context = Base.Context
        public typealias Result = Base.Result
        private let base: Base
        private let name: String
        var excludesSpecificationTracing: Bool {
            SpecificationTraceRuntime.isExcluded(base)
        }

        /// Wraps a decision specification with a stable trace name.
        public init(_ base: Base, name: String) {
            self.base = base
            self.name = name
        }

        /// Returns the base decision and records whether it selected a result.
        public func decide(_ context: Context) -> Result? {
            if excludesSpecificationTracing {
                return SpecificationTraceRuntime.withoutRecording { base.decide(context) }
            }
            return SpecificationTraceRuntime.withDecision(name) { base.decide(context) }
        }
    }

    public extension DecisionSpec {
        /// Returns a named tracing wrapper around this decision specification.
        func traced(_ name: String) -> TracedDecisionSpec<Self> {
            TracedDecisionSpec(self, name: name)
        }

        /// Returns a wrapper whose decision is omitted from traces.
        func withoutTracing() -> UntracedDecisionSpec<Self> {
            UntracedDecisionSpec(self)
        }
    }

    /// A synchronous decision whose evaluations are excluded from traces.
    public struct UntracedDecisionSpec<Base: DecisionSpec>: DecisionSpec, SpecificationTraceExclusion {
        public typealias Context = Base.Context
        public typealias Result = Base.Result
        let base: Base
        var excludesSpecificationTracing: Bool {
            true
        }

        /// Wraps a decision without changing its result.
        public init(_ base: Base) {
            self.base = base
        }

        /// Evaluates the base decision without recording its subtree.
        public func decide(_ context: Context) -> Result? {
            SpecificationTraceRuntime.withoutRecording { base.decide(context) }
        }
    }

    /// A named wrapper for an asynchronous decision specification.
    public struct TracedAsyncDecisionSpec<Base: AsyncDecisionSpec>: AsyncDecisionSpec, SpecificationTraceExclusion {
        public typealias Context = Base.Context
        public typealias Result = Base.Result
        private let base: Base
        private let name: String
        var excludesSpecificationTracing: Bool {
            SpecificationTraceRuntime.isExcluded(base)
        }

        /// Wraps an asynchronous decision specification with a stable trace name.
        public init(_ base: Base, name: String) {
            self.base = base
            self.name = name
        }

        /// Returns the base decision and propagates errors after recording them.
        public func decide(_ context: Context) async throws -> Result? {
            if excludesSpecificationTracing {
                return try await SpecificationTraceRuntime.withoutRecording { try await base.decide(context) }
            }
            return try await SpecificationTraceRuntime.withDecision(name) { try await base.decide(context) }
        }
    }

    public extension AsyncDecisionSpec {
        /// Returns a named tracing wrapper around this asynchronous decision specification.
        func traced(_ name: String) -> TracedAsyncDecisionSpec<Self> {
            TracedAsyncDecisionSpec(self, name: name)
        }

        /// Returns a wrapper whose asynchronous decision is omitted from traces.
        func withoutTracing() -> UntracedAsyncDecisionSpec<Self> {
            UntracedAsyncDecisionSpec(self)
        }
    }

    /// An asynchronous decision whose evaluations are excluded from traces.
    public struct UntracedAsyncDecisionSpec<Base: AsyncDecisionSpec>: AsyncDecisionSpec, SpecificationTraceExclusion {
        public typealias Context = Base.Context
        public typealias Result = Base.Result
        let base: Base
        var excludesSpecificationTracing: Bool {
            true
        }

        /// Wraps an asynchronous decision without changing its result or errors.
        public init(_ base: Base) {
            self.base = base
        }

        /// Evaluates the base decision without recording its subtree.
        public func decide(_ context: Context) async throws -> Result? {
            try await SpecificationTraceRuntime.withoutRecording { try await base.decide(context) }
        }
    }
#endif
