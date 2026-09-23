#if Tracing
    import Foundation

    /// A position on one explicitly shared specification trace timeline.
    public struct SpecificationTracePosition: Hashable, Sendable {
        /// The unique, increasing mark number within one timeline.
        public let sequence: UInt64

        /// Monotonic elapsed nanoseconds since the timeline was created.
        public let elapsedNanoseconds: UInt64

        /// Creates a position for a trace adapter.
        public init(sequence: UInt64, elapsedNanoseconds: UInt64) {
            self.sequence = sequence
            self.elapsedNanoseconds = elapsedNanoseconds
        }
    }

    /// Allocates comparable positions for events produced during one logical operation.
    ///
    /// Share one timeline with a `SpecificationTraceRecorder` and any integrating event
    /// producer that needs to interleave its events with specification evaluations. Sequence
    /// numbers from different timeline instances are unrelated. The lock protects sequence
    /// allocation; the monotonic origin is immutable after initialization.
    public final class SpecificationTraceTimeline: @unchecked Sendable {
        private let lock = NSLock()
        private let origin = DispatchTime.now().uptimeNanoseconds
        private var nextSequence: UInt64 = 0

        public init() {}

        /// Returns a unique sequence and monotonic elapsed-time position.
        ///
        /// Marks from a single timeline have strictly increasing sequence numbers and
        /// nondecreasing elapsed offsets, including when the timeline is shared across tasks.
        public func mark() -> SpecificationTracePosition {
            lock.lock()
            defer { lock.unlock() }

            nextSequence += 1
            let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - origin
            return SpecificationTracePosition(
                sequence: nextSequence,
                elapsedNanoseconds: elapsedNanoseconds
            )
        }
    }
#endif
