#if Tracing
    @testable import SpecificationCore
    import XCTest

    final class TracingTests: XCTestCase {
        @TracedSpecification("custom.positive")
        private struct Positive: Specification {
            func isSatisfiedBy(_ candidate: Int) -> Bool {
                candidate > 0
            }
        }

        @TracedSpecification("custom.async-positive")
        private struct AsyncPositive: AsyncSpecification {
            func isSatisfiedBy(_ candidate: Int) async throws -> Bool {
                candidate > 0
            }
        }

        @TracedSpecification("custom.async-nonthrowing")
        private struct NonthrowingAsyncPositive: AsyncSpecification {
            func isSatisfiedBy(_ candidate: Int) async -> Bool {
                candidate > 0
            }
        }

        func testTypeMacroTracesUserSpecification() {
            let recorder = SpecificationTraceRecorder()
            let result = SpecificationTraceRuntime.evaluate(Positive(), 3, recordingTo: recorder)

            XCTAssertTrue(result)
            XCTAssertEqual(recorder.events.first { $0.name == "custom.positive" }?.outcome, .satisfied)
        }

        func testTypeMacroTracesAsyncUserSpecification() async throws {
            let recorder = SpecificationTraceRecorder()
            let result = try await SpecificationTraceRuntime.evaluateAsync(AsyncPositive(), 3, recordingTo: recorder)

            XCTAssertTrue(result)
            XCTAssertEqual(recorder.events.first { $0.name == "custom.async-positive" }?.outcome, .satisfied)
        }

        func testTypeMacroTracesNonthrowingAsyncMethod() async throws {
            let recorder = SpecificationTraceRecorder()
            let result = try await SpecificationTraceRuntime.evaluateAsync(
                NonthrowingAsyncPositive(),
                3,
                recordingTo: recorder
            )

            XCTAssertTrue(result)
            XCTAssertEqual(recorder.events.first { $0.name == "custom.async-nonthrowing" }?.outcome, .satisfied)
        }

        func testAndPreservesShortCircuitAndRecordsSkippedBranch() {
            var calls = 0
            let first = AnySpecification<Int> { _ in false }
            let second = AnySpecification<Int> { _ in
                calls += 1
                return true
            }
            let recorder = SpecificationTraceRecorder()

            let result = SpecificationTraceRuntime.evaluate(first.and(second), 1, recordingTo: recorder)

            XCTAssertFalse(result)
            XCTAssertEqual(calls, 0)
            XCTAssertTrue(recorder.events.contains { $0.outcome == .skipped })
            XCTAssertTrue(recorder.events.contains { $0.outcome == .unsatisfied })
        }

        func testFirstMatchPreservesOrderAndSelectedPair() {
            var visited: [Int] = []
            let decision = FirstMatchSpec<Int, String>.builder()
                .add({ value in visited.append(0); return value < 0 }, result: "first")
                .add({ value in visited.append(1); return value == 1 }, result: "second")
                .add({ _ in visited.append(2); return true }, result: "third")
                .build()
            let recorder = SpecificationTraceRecorder()

            let result = SpecificationTraceRuntime.decide(decision, 1, recordingTo: recorder)

            XCTAssertEqual(result, "second")
            XCTAssertEqual(visited, [0, 1])
            XCTAssertEqual(recorder.events.first { $0.name == "pair[1]" }?.outcome, .satisfied)
            XCTAssertEqual(recorder.events.first { $0.name == "pair[2]" }?.outcome, .skipped)
        }

        func testAsyncErrorIsRecordedAndRethrown() async {
            enum SampleError: Error { case rejected }
            let specification = AnyAsyncSpecification<Int> { _ in throw SampleError.rejected }
            let recorder = SpecificationTraceRecorder()

            do {
                _ = try await SpecificationTraceRuntime.evaluateAsync(specification, 1, recordingTo: recorder)
                XCTFail("Expected the specification error")
            } catch SampleError.rejected {
                XCTAssertTrue(recorder.events.contains {
                    if case .failed = $0.outcome { return true }
                    return false
                })
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        func testNamedWrapperAndParentIDs() {
            let recorder = SpecificationTraceRecorder()
            let specification = AnySpecification<Int> { $0 > 0 }.traced("input.positive")

            XCTAssertTrue(SpecificationTraceRuntime.evaluate(specification, 1, recordingTo: recorder))
            let events = recorder.events
            let named = events.first { $0.name == "input.positive" }
            XCTAssertNotNil(named)
            XCTAssertNotNil(named?.parentID)
            XCTAssertEqual(named?.outcome, .satisfied)
        }

        func testAsyncCancellationIsRecordedAndRethrown() async {
            let specification = AnyAsyncSpecification<Int> { _ in
                try Task.checkCancellation()
                return true
            }
            let recorder = SpecificationTraceRecorder()
            let task = Task {
                try await SpecificationTraceRuntime.evaluateAsync(specification, 1, recordingTo: recorder)
            }
            task.cancel()

            do {
                _ = try await task.value
                XCTFail("Expected cancellation")
            } catch is CancellationError {
                XCTAssertTrue(recorder.events.contains { $0.outcome == .cancelled })
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }
#endif
