import Foundation
import SpecificationCore

private struct Candidate {
    let value: Int
}

private struct IsMultipleOfThree: Specification {
    func isSatisfiedBy(_ candidate: Candidate) -> Bool {
        candidate.value.isMultiple(of: 3)
    }
}

private struct IsBelowEight: Specification {
    func isSatisfiedBy(_ candidate: Candidate) -> Bool {
        candidate.value < 8
    }
}

private struct IsZero: Specification {
    func isSatisfiedBy(_ candidate: Candidate) -> Bool {
        candidate.value == 0
    }
}

private let candidates = (0 ..< 120_000).map { Candidate(value: $0 % 12) }
private let predicate = PredicateSpec<Candidate> { $0.value.isMultiple(of: 3) }
private let secondPredicate = PredicateSpec<Candidate> { $0.value < 8 }
private let composition = predicate.and(secondPredicate)
private let concreteAnd = IsMultipleOfThree().and(IsBelowEight())
private let concreteOr = IsZero().or(IsBelowEight())
private let concreteNot = IsBelowEight().not()
private let returningAdapter = predicate.returning(7)
private let predicateDecision = PredicateDecisionSpec<Candidate, Int>(
    predicate: { $0.value.isMultiple(of: 3) },
    result: 7
)
private let firstMatch = FirstMatchSpec<Candidate, Int>([
    (PredicateSpec { $0.value == 0 }, 10),
    (PredicateSpec { $0.value.isMultiple(of: 3) }, 7),
    (PredicateSpec { $0.value < 8 }, 3)
])

private struct Variant {
    let name: String
    let evaluate: (Candidate) -> Int?
}

private let variants = [
    Variant(name: "predicate", evaluate: { predicate.isSatisfiedBy($0) ? 1 : nil }),
    Variant(name: "composition", evaluate: { composition.isSatisfiedBy($0) ? 1 : nil }),
    Variant(name: "concrete_and", evaluate: { concreteAnd.isSatisfiedBy($0) ? 1 : nil }),
    Variant(name: "concrete_or", evaluate: { concreteOr.isSatisfiedBy($0) ? 1 : nil }),
    Variant(name: "concrete_not", evaluate: { concreteNot.isSatisfiedBy($0) ? 1 : nil }),
    Variant(name: "first_match", evaluate: { firstMatch.decide($0) }),
    Variant(name: "returning_adapter", evaluate: { returningAdapter.decide($0) }),
    Variant(name: "predicate_decision", evaluate: { predicateDecision.decide($0) })
]

private func expected(_ value: Int, strategy: String) -> Int? {
    switch strategy {
    case "predicate": value.isMultiple(of: 3) ? 1 : nil
    case "composition": value.isMultiple(of: 3) && value < 8 ? 1 : nil
    case "concrete_and": value.isMultiple(of: 3) && value < 8 ? 1 : nil
    case "concrete_or": value == 0 || value < 8 ? 1 : nil
    case "concrete_not": value >= 8 ? 1 : nil
    case "first_match":
        if value == 0 { 10 }
        else if value.isMultiple(of: 3) { 7 }
        else if value < 8 { 3 }
        else { nil }
    case "returning_adapter", "predicate_decision": value.isMultiple(of: 3) ? 7 : nil
    default: fatalError("Unknown strategy: \(strategy)")
    }
}

for variant in variants {
    for candidate in candidates {
        precondition(variant.evaluate(candidate) == expected(candidate.value, strategy: variant.name))
    }
}

for variant in variants {
    _ = measure(variant)
}

@inline(never)
private func measure(_ variant: Variant) -> (UInt64, Int) {
    let start = DispatchTime.now().uptimeNanoseconds
    var checksum = 0
    for candidate in candidates {
        if let result = variant.evaluate(candidate) {
            checksum &+= result
        }
    }
    return (DispatchTime.now().uptimeNanoseconds - start, checksum)
}

let rounds = 24
print("round,strategy,elapsed_ns,ns_per_candidate,checksum")
for round in 0 ..< rounds {
    let offset = round % variants.count
    for step in 0 ..< variants.count {
        let variant = variants[(offset + step) % variants.count]
        let (elapsed, checksum) = measure(variant)
        print("\(round),\(variant.name),\(elapsed),\(Double(elapsed) / Double(candidates.count)),\(checksum)")
    }
}
