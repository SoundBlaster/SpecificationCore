@testable import SpecificationCore
import XCTest

private struct NeverMatches: Specification {
    func isSatisfiedBy(_: Int) -> Bool {
        false
    }
}

private struct MatchesValue: Specification {
    let expected: Int

    func isSatisfiedBy(_ candidate: Int) -> Bool {
        candidate == expected
    }
}

final class StaticFirstMatchTests: XCTestCase {
    private final class EvaluationLog {
        var visited: [Int] = []
    }

    private struct OptionalNilMatch: DecisionSpec {
        typealias Context = Int
        typealias Result = String?

        func decide(_ context: Int) -> String?? {
            context == 1 ? .some(nil) : nil
        }
    }

    private struct SendableNoMatch: DecisionSpec, Sendable {
        typealias Context = Int
        typealias Result = String

        func decide(_: Int) -> String? {
            nil
        }
    }

    func testStaticFirstMatchPreservesOrderAndShortCircuits() {
        let log = EvaluationLog()
        let decision = StaticFirstMatch {
            PredicateSpec<Int> { value in
                log.visited.append(0)
                return value == 0
            }.returning("zero")
            PredicateSpec<Int> { value in
                log.visited.append(1)
                return value == 1
            }.returning("one")
            PredicateSpec<Int> { value in
                log.visited.append(2)
                return value == 2
            }.returning("two")
        }

        XCTAssertEqual(decision.decide(1), "one")
        XCTAssertEqual(log.visited, [0, 1])

        log.visited.removeAll()
        XCTAssertNil(decision.decide(10))
        XCTAssertEqual(log.visited, [0, 1, 2])
    }

    func testStaticFirstMatchPreservesAnOptionalNilResultAsAMatch() {
        var laterRuleEvaluations = 0
        let decision = StaticFirstMatch {
            OptionalNilMatch()
            PredicateSpec<Int> { _ in
                laterRuleEvaluations += 1
                return true
            }.returning(Optional.some("fallback"))
        }

        let result: String?? = decision.decide(1)

        if case .some(.none) = result {
            // A nil payload remains a match.
        } else {
            XCTFail("Expected a matched decision with a nil payload")
        }
        XCTAssertEqual(laterRuleEvaluations, 0)
    }

    func testStaticFirstMatchHandlesGrowingLeafSpecificationTypes() {
        let leaf0 = MatchesValue(expected: 0)
        let leaf1 = leaf0.or(MatchesValue(expected: 1)).and(NeverMatches().not())
        let leaf2 = leaf1.or(MatchesValue(expected: 2)).and(NeverMatches().not())
        let leaf3 = leaf2.or(MatchesValue(expected: 3)).and(NeverMatches().not())
        let leaf4 = leaf3.or(MatchesValue(expected: 4)).and(NeverMatches().not())
        let leaf5 = leaf4.or(MatchesValue(expected: 5)).and(NeverMatches().not())
        let leaf6 = leaf5.or(MatchesValue(expected: 6)).and(NeverMatches().not())
        let leaf7 = leaf6.or(MatchesValue(expected: 7)).and(NeverMatches().not())
        let leaf8 = leaf7.or(MatchesValue(expected: 8)).and(NeverMatches().not())
        let decision = StaticFirstMatch {
            leaf0.returning(0)
            leaf1.returning(1)
            leaf2.returning(2)
            leaf3.returning(3)
            leaf4.returning(4)
            leaf5.returning(5)
            leaf6.returning(6)
            leaf7.returning(7)
            leaf8.returning(8)
        }

        for expected in 0 ... 8 {
            XCTAssertEqual(decision.decide(expected), expected)
        }
        XCTAssertNil(decision.decide(9))
    }

    func testStaticFirstMatchSupportsBuilderAritiesOneThroughEight() {
        let one = StaticFirstMatch { rule(matching: 1) }
        let two = StaticFirstMatch {
            rule(matching: 1)
            rule(matching: 2)
        }
        let four = StaticFirstMatch {
            rule(matching: 1)
            rule(matching: 2)
            rule(matching: 3)
            rule(matching: 4)
        }
        let five = StaticFirstMatch {
            rule(matching: 1)
            rule(matching: 2)
            rule(matching: 3)
            rule(matching: 4)
            rule(matching: 5)
        }
        let six = StaticFirstMatch {
            rule(matching: 1)
            rule(matching: 2)
            rule(matching: 3)
            rule(matching: 4)
            rule(matching: 5)
            rule(matching: 6)
        }
        let seven = StaticFirstMatch {
            rule(matching: 1)
            rule(matching: 2)
            rule(matching: 3)
            rule(matching: 4)
            rule(matching: 5)
            rule(matching: 6)
            rule(matching: 7)
        }
        let eight = StaticFirstMatch {
            rule(matching: 1)
            rule(matching: 2)
            rule(matching: 3)
            rule(matching: 4)
            rule(matching: 5)
            rule(matching: 6)
            rule(matching: 7)
            rule(matching: 8)
        }

        XCTAssertEqual(one.decide(1), 1)
        XCTAssertEqual(two.decide(2), 2)
        XCTAssertEqual(four.decide(4), 4)
        XCTAssertEqual(five.decide(5), 5)
        XCTAssertEqual(six.decide(6), 6)
        XCTAssertEqual(seven.decide(7), 7)
        XCTAssertEqual(eight.decide(8), 8)
    }

    func testStaticFirstMatchSupportsNineAndTenRules() {
        let nineRules = StaticFirstMatch {
            rule(matching: 1)
            rule(matching: 2)
            rule(matching: 3)
            rule(matching: 4)
            rule(matching: 5)
            rule(matching: 6)
            rule(matching: 7)
            rule(matching: 8)
            rule(matching: 9)
        }
        let tenRules = StaticFirstMatch {
            rule(matching: 1)
            rule(matching: 2)
            rule(matching: 3)
            rule(matching: 4)
            rule(matching: 5)
            rule(matching: 6)
            rule(matching: 7)
            rule(matching: 8)
            rule(matching: 9)
            rule(matching: 10)
        }

        XCTAssertEqual(nineRules.decide(9), 9)
        XCTAssertNil(nineRules.decide(10))
        XCTAssertEqual(tenRules.decide(10), 10)
    }

    #if Tracing
        func testStaticFirstMatchTracingRecordsTreeAndPreservesExclusion() {
            let decision = StaticFirstMatch {
                PredicateSpec<Int> { $0 == 1 }.returning("one").withoutTracing()
                PredicateSpec<Int> { $0 == 2 }.returning("two")
            }
            let recorder = SpecificationTraceRecorder()

            XCTAssertEqual(SpecificationTraceRuntime.decide(decision, 1, recordingTo: recorder), "one")
            XCTAssertTrue(recorder.events.contains { $0.name == "StaticFirstMatch" })
            XCTAssertTrue(recorder.events.contains { $0.name == "BinaryFirstMatch" })
            XCTAssertFalse(recorder.events.contains { $0.name == "first" })
            XCTAssertTrue(recorder.events.contains { $0.name == "second" && $0.outcome == .skipped })

            let untraced = StaticFirstMatch {
                PredicateSpec<Int> { $0 == 1 }.returning("one").withoutTracing()
                PredicateSpec<Int> { $0 == 2 }.returning("two").withoutTracing()
            }.withoutTracing()
            let excludedRecorder = SpecificationTraceRecorder()
            XCTAssertEqual(SpecificationTraceRuntime.decide(untraced, 1, recordingTo: excludedRecorder), "one")
            XCTAssertTrue(excludedRecorder.events.isEmpty)
        }
    #endif

    func testStaticFirstMatchIsSendableWhenRulesAreSendable() {
        func requireSendable(_: some Sendable) {}

        let decision = StaticFirstMatch { SendableNoMatch() }
        requireSendable(decision)
        XCTAssertNil(decision.decide(0))
    }

    private func rule(matching value: Int) -> BooleanDecisionAdapter<PredicateSpec<Int>, Int> {
        PredicateSpec<Int> { $0 == value }.returning(value)
    }
}
