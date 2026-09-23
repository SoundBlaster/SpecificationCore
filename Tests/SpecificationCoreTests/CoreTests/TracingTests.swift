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

        private enum Rejected: Error { case value }

        private struct TypedThrowingSpecification: AsyncSpecification {
            @TraceEvaluation("typed.boolean")
            func isSatisfiedBy(_ candidate: Int) async throws(Rejected) -> Bool {
                if candidate < 0 {
                    throw .value
                }
                return candidate > 0
            }
        }

        private struct TypedThrowingDecision: AsyncDecisionSpec {
            @TraceEvaluation("typed.decision")
            func decide(_ candidate: Int) async throws(Rejected) -> String? {
                if candidate < 0 {
                    throw .value
                }
                return candidate > 0 ? "accepted" : nil
            }
        }

        func testTypeMacroTracesUserSpecification() {
            let recorder = SpecificationTraceRecorder()
            let result = SpecificationTraceRuntime.evaluate(Positive(), 3, recordingTo: recorder)

            XCTAssertTrue(result)
            XCTAssertEqual(recorder.events.first { $0.name == "custom.positive" }?.outcome, .satisfied)
        }

        func testTimelinePositionsRequireExplicitTimeline() throws {
            let recorder = SpecificationTraceRecorder()
            XCTAssertTrue(SpecificationTraceRuntime.evaluate(Positive(), 3, recordingTo: recorder))

            let event = try XCTUnwrap(recorder.events.first { $0.name == "custom.positive" })
            XCTAssertNil(event.startPosition)
            XCTAssertNil(event.completionPosition)

            let externallyCreatedEvent = SpecificationTraceEvent(
                id: 1,
                parentID: nil,
                name: "adapter.event",
                outcome: .satisfied,
                durationNanoseconds: 0
            )
            XCTAssertEqual(externallyCreatedEvent.name, "adapter.event")
            XCTAssertNil(externallyCreatedEvent.startPosition)
            XCTAssertNil(externallyCreatedEvent.completionPosition)
        }

        func testDefaultRecorderDoesNotCreateTimeline() throws {
            let previousRecorder = SpecificationTraceRuntime.defaultRecorder
            let recorder = SpecificationTraceRecorder()
            defer { SpecificationTraceRuntime.defaultRecorder = previousRecorder }
            SpecificationTraceRuntime.defaultRecorder = recorder

            XCTAssertTrue(Positive().traced("default.positive").isSatisfiedBy(3))

            let event = try XCTUnwrap(recorder.events.first { $0.name == "default.positive" })
            XCTAssertNil(event.startPosition)
            XCTAssertNil(event.completionPosition)
        }

        func testExplicitTimelinePositionsBracketEvaluationAndConsumerMarks() throws {
            let timeline = SpecificationTraceTimeline()
            let recorder = SpecificationTraceRecorder(timeline: timeline)
            let before = timeline.mark()
            let specification = AnySpecification<Int> { $0 > 0 }.traced("input.positive")

            XCTAssertTrue(SpecificationTraceRuntime.evaluate(specification, 1, recordingTo: recorder))
            let after = timeline.mark()

            let events = recorder.events
            let root = try XCTUnwrap(events.first { $0.name == "input.positive" })
            let child = try XCTUnwrap(events.first { $0.parentID == root.id })
            let start = try XCTUnwrap(root.startPosition)
            let completion = try XCTUnwrap(root.completionPosition)
            let childStart = try XCTUnwrap(child.startPosition)
            let childCompletion = try XCTUnwrap(child.completionPosition)

            XCTAssertLessThan(before.sequence, start.sequence)
            XCTAssertLessThan(start.sequence, childStart.sequence)
            XCTAssertLessThan(childCompletion.sequence, completion.sequence)
            XCTAssertLessThan(completion.sequence, after.sequence)
            XCTAssertLessThanOrEqual(start.elapsedNanoseconds, completion.elapsedNanoseconds)
            XCTAssertEqual(root.durationNanoseconds, completion.elapsedNanoseconds - start.elapsedNanoseconds)
            XCTAssertLessThan(childStart.sequence, childCompletion.sequence)
        }

        func testMultipleRecordersCanShareOneTimeline() throws {
            let timeline = SpecificationTraceTimeline()
            let firstRecorder = SpecificationTraceRecorder(timeline: timeline)
            let secondRecorder = SpecificationTraceRecorder(timeline: timeline)
            let firstStart = timeline.mark()

            XCTAssertTrue(SpecificationTraceRuntime.evaluate(Positive(), 1, recordingTo: firstRecorder))
            let between = timeline.mark()
            XCTAssertTrue(SpecificationTraceRuntime.evaluate(Positive(), 2, recordingTo: secondRecorder))
            let after = timeline.mark()

            let first = try XCTUnwrap(firstRecorder.events.first { $0.name == "custom.positive" })
            let second = try XCTUnwrap(secondRecorder.events.first { $0.name == "custom.positive" })
            let firstCompletion = try XCTUnwrap(first.completionPosition)
            let secondStart = try XCTUnwrap(second.startPosition)
            let secondCompletion = try XCTUnwrap(second.completionPosition)

            XCTAssertLessThan(firstStart.sequence, firstCompletion.sequence)
            XCTAssertLessThan(firstCompletion.sequence, between.sequence)
            XCTAssertLessThan(between.sequence, secondStart.sequence)
            XCTAssertLessThan(secondStart.sequence, secondCompletion.sequence)
            XCTAssertLessThan(secondCompletion.sequence, after.sequence)
        }

        func testTimelineMarksStayUniqueAndMonotonicAcrossTasks() async {
            let timeline = SpecificationTraceTimeline()
            let positions = await withTaskGroup(of: SpecificationTracePosition.self) { group in
                for _ in 0 ..< 100 {
                    group.addTask { timeline.mark() }
                }

                var collected: [SpecificationTracePosition] = []
                for await position in group {
                    collected.append(position)
                }
                return collected
            }
            let ordered = positions.sorted { $0.sequence < $1.sequence }

            XCTAssertEqual(Set(ordered.map(\.sequence)).count, 100)
            XCTAssertEqual(ordered.map(\.sequence), (1 ... 100).map { UInt64($0) })
            XCTAssertTrue(zip(ordered, ordered.dropFirst()).allSatisfy {
                $0.elapsedNanoseconds <= $1.elapsedNanoseconds
            })
        }

        func testSkippedBranchUsesOneInstantOnExplicitTimeline() throws {
            let timeline = SpecificationTraceTimeline()
            let recorder = SpecificationTraceRecorder(timeline: timeline)
            let rule = AnySpecification<Int> { _ in false }.and(AnySpecification<Int> { _ in true })

            XCTAssertFalse(SpecificationTraceRuntime.evaluate(rule, 0, recordingTo: recorder))

            let skipped = try XCTUnwrap(recorder.events.first { $0.outcome == .skipped })
            XCTAssertEqual(skipped.startPosition, skipped.completionPosition)
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
            let recorder = SpecificationTraceRecorder(timeline: SpecificationTraceTimeline())

            do {
                _ = try await SpecificationTraceRuntime.evaluateAsync(specification, 1, recordingTo: recorder)
                XCTFail("Expected the specification error")
            } catch SampleError.rejected {
                XCTAssertTrue(recorder.events.contains {
                    if case .failed = $0.outcome {
                        return $0.startPosition != nil && $0.completionPosition != nil
                    }
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
            let recorder = SpecificationTraceRecorder(timeline: SpecificationTraceTimeline())
            let task = Task {
                try await SpecificationTraceRuntime.evaluateAsync(specification, 1, recordingTo: recorder)
            }
            task.cancel()

            do {
                _ = try await task.value
                XCTFail("Expected cancellation")
            } catch is CancellationError {
                XCTAssertTrue(recorder.events.contains {
                    $0.outcome == .cancelled && $0.startPosition != nil && $0.completionPosition != nil
                })
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        func testTypedThrowsMacroPreservesErrorAndRecordsOutcomes() async {
            let recorder = SpecificationTraceRecorder()
            do {
                _ = try await SpecificationTraceRuntime.evaluateAsync(
                    TypedThrowingSpecification(), -1, recordingTo: recorder
                )
                XCTFail("Expected typed rejection")
            } catch Rejected.value {
                XCTAssertTrue(recorder.events.contains {
                    if case .failed = $0.outcome {
                        return $0.name == "typed.boolean"
                    }
                    return false
                })
            } catch {
                XCTFail("Unexpected error: \(error)")
            }

            do {
                _ = try await SpecificationTraceRuntime.decideAsync(
                    TypedThrowingDecision(), -1, recordingTo: recorder
                )
                XCTFail("Expected typed rejection")
            } catch Rejected.value {
                XCTAssertTrue(recorder.events.contains {
                    if case .failed = $0.outcome {
                        return $0.name == "typed.decision"
                    }
                    return false
                })
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }

        func testLazyCollectionShortCircuitDoesNotMaterializeUnusedElements() {
            for recording in [false, true] {
                var transformed: [Int] = []
                let all = (0 ..< 3).lazy.map { index -> AnySpecification<Int> in
                    transformed.append(index)
                    return AnySpecification { _ in false }
                }.allSatisfied()
                let recorder = SpecificationTraceRecorder()
                let allResult = recording
                    ? SpecificationTraceRuntime.evaluate(all, 1, recordingTo: recorder)
                    : all.isSatisfiedBy(1)
                XCTAssertFalse(allResult)
                XCTAssertEqual(transformed, [0])
                if recording {
                    XCTAssertEqual(recorder.events.filter { $0.outcome == .skipped }.count, 2)
                }

                transformed.removeAll()
                let any = (0 ..< 3).lazy.map { index -> AnySpecification<Int> in
                    transformed.append(index)
                    return AnySpecification { _ in true }
                }.anySatisfied()
                let anyResult = recording
                    ? SpecificationTraceRuntime.evaluate(any, 1, recordingTo: recorder)
                    : any.isSatisfiedBy(1)
                XCTAssertTrue(anyResult)
                XCTAssertEqual(transformed, [0])
            }
        }

        func testLazyCollectionShortCircuitUnderSuppressedRecording() {
            var transformed: [Int] = []
            let rule = (0 ..< 3).lazy.map { index -> AnySpecification<Int> in
                transformed.append(index)
                return AnySpecification { _ in false }
            }.allSatisfied()
            let recorder = SpecificationTraceRecorder()

            let result = SpecificationTraceRuntime.withoutRecording {
                SpecificationTraceRuntime.evaluate(rule, 1, recordingTo: recorder)
            }

            XCTAssertFalse(result)
            XCTAssertEqual(transformed, [0])
            XCTAssertTrue(recorder.events.isEmpty)
        }
    }
#endif
