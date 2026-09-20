@testable import SpecificationCore
import XCTest

final class AsyncDecisionSpecTests: XCTestCase {
    private struct DualSpecification: Specification, AsyncSpecification {
        func isSatisfiedBy(_ candidate: Int) -> Bool {
            candidate > 0
        }

        func isSatisfiedBy(_ candidate: Int) async throws -> Bool {
            candidate > 0
        }
    }

    func testAsyncDecisionAdapterReturnsResultOnlyWhenSatisfied() async throws {
        let specification = AnyAsyncSpecification<Int> { $0 > 10 }
        let decision = specification.returningAsync("large")

        let largeResult = try await decision.decide(11)
        let smallResult = try await decision.decide(10)

        XCTAssertEqual(largeResult, "large")
        XCTAssertNil(smallResult)
    }

    func testAnyAsyncDecisionSpecWrapsClosureAndSyncDecision() async throws {
        let asyncDecision = AnyAsyncDecisionSpec<Int, String> { value in
            value.isMultiple(of: 2) ? "even" : nil
        }
        let evenResult = try await asyncDecision.decide(4)
        let oddResult = try await asyncDecision.decide(3)
        XCTAssertEqual(evenResult, "even")
        XCTAssertNil(oddResult)

        let syncDecision = PredicateDecisionSpec<Int, String>(predicate: { $0 > 0 }, result: "positive")
        let bridgedDecision = AnyAsyncDecisionSpec<Int, String>(syncDecision)
        let bridgedResult = try await bridgedDecision.decide(1)
        XCTAssertEqual(bridgedResult, "positive")
    }

    func testAsyncFirstMatchBuilderSelectsFirstMatchAndSkipsLaterPairs() async throws {
        var laterSpecificationEvaluations = 0
        let first = AnyAsyncSpecification<Int> { $0 > 0 }
        let second = AnyAsyncSpecification<Int> { _ in
            laterSpecificationEvaluations += 1
            return true
        }

        let decision = AsyncFirstMatchSpec<Int, String>.builder()
            .add(first, result: "positive")
            .add(second, result: "later")
            .fallback("fallback")
            .build()

        let match = try await decision.decideWithMetadata(1)
        XCTAssertEqual(match?.result, "positive")
        XCTAssertEqual(match?.index, 0)
        XCTAssertEqual(laterSpecificationEvaluations, 0)
    }

    func testAsyncFirstMatchBuilderUsesFallbackWhenNothingMatches() async throws {
        let decision = AsyncFirstMatchSpec<Int, String>.builder()
            .addPredicate({ $0 > 10 }, result: "large")
            .fallback("other")
            .build()

        let fallbackResult = try await decision.decide(10)
        let emptyResult = try await AsyncFirstMatchSpec<Int, String>([]).decide(10)
        XCTAssertEqual(fallbackResult, "other")
        XCTAssertNil(emptyResult)
    }

    func testAsyncFirstMatchBuilderAcceptsSynchronousSpecifications() async throws {
        let specification = PredicateSpec<Int> { $0.isMultiple(of: 2) }
        let decision = AsyncFirstMatchSpec<Int, String>.builder()
            .addSync(specification, result: "even")
            .build()

        let result = try await decision.decide(4)
        XCTAssertEqual(result, "even")
    }

    func testAsyncSpecificationCompositionShortCircuitsAndNegates() async throws {
        var secondEvaluations = 0
        let falseSpecification = AnyAsyncSpecification<Int> { $0 > 0 }
        let secondSpecification = AnyAsyncSpecification<Int> { _ in
            secondEvaluations += 1
            return true
        }

        let andResult = try await falseSpecification.andAsync(secondSpecification).isSatisfiedBy(0)
        XCTAssertEqual(secondEvaluations, 0)
        let orResult = try await falseSpecification.orAsync(secondSpecification).isSatisfiedBy(0)
        let notResult = try await falseSpecification.notAsync().isSatisfiedBy(0)
        XCTAssertFalse(andResult)
        XCTAssertTrue(orResult)
        XCTAssertTrue(notResult)
    }

    func testDualConformingSpecificationKeepsSyncAndAsyncOperationsUnambiguous() async throws {
        let specification = DualSpecification()
        let syncAnd = specification.and(specification)
        let syncOr = specification.or(specification)
        let syncNot = specification.not()
        let syncDecision = specification.returning("positive")

        XCTAssertTrue(syncAnd.isSatisfiedBy(1))
        XCTAssertTrue(syncOr.isSatisfiedBy(1))
        XCTAssertFalse(syncNot.isSatisfiedBy(1))
        XCTAssertEqual(syncDecision.decide(1), "positive")

        let asyncAnd = specification.andAsync(specification)
        let asyncOr = specification.orAsync(specification)
        let asyncNot = specification.notAsync()
        let asyncDecision = specification.returningAsync("positive")

        let asyncAndResult = try await asyncAnd.isSatisfiedBy(1)
        let asyncOrResult = try await asyncOr.isSatisfiedBy(1)
        let asyncNotResult = try await asyncNot.isSatisfiedBy(1)
        let asyncDecisionResult = try await asyncDecision.decide(1)

        XCTAssertTrue(asyncAndResult)
        XCTAssertTrue(asyncOrResult)
        XCTAssertFalse(asyncNotResult)
        XCTAssertEqual(asyncDecisionResult, "positive")
    }

    func testAsyncFirstMatchPropagatesErrors() async {
        enum ExpectedError: Error { case failed }
        let throwingSpecification = AnyAsyncSpecification<Int> { _ in throw ExpectedError.failed }
        let decision = AsyncFirstMatchSpec<Int, String>([(throwingSpecification, "unreachable")])

        do {
            _ = try await decision.decide(1)
            XCTFail("Expected the specification error to propagate")
        } catch ExpectedError.failed {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAsyncFirstMatchHonorsTaskCancellation() async {
        let decision = AsyncFirstMatchSpec<Int, String>.builder()
            .fallback("fallback")
            .build()
        let task = Task { try await decision.decide(0) }
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation to propagate")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAsyncDecisionPropagatesCancellationDuringEvaluation() async {
        let decision = AnyAsyncDecisionSpec<Int, String> { _ in
            withUnsafeCurrentTask { task in
                task?.cancel()
            }
            return "result"
        }
        let task = Task { try await decision.decide(0) }

        do {
            _ = try await task.value
            XCTFail("Expected cancellation during evaluation to propagate")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
