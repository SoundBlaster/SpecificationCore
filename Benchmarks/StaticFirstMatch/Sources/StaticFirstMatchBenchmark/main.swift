import Foundation
import SpecificationCore

private struct Candidate {
    let value: Int
}

private struct ValueEquals: Specification {
    let expected: Int

    func isSatisfiedBy(_ candidate: Candidate) -> Bool {
        candidate.value == expected
    }
}

private struct NeverMatches: Specification {
    func isSatisfiedBy(_: Candidate) -> Bool {
        false
    }
}

private struct Variant {
    let name: String
    let evaluate: (Candidate) -> Int?
}

private let candidates = (0 ..< 120_000).map { Candidate(value: $0 % 12) }
private let growingLeaf0 = ValueEquals(expected: 0)
private let growingRule0 = growingLeaf0.returning(0)
private let growingLeaf1 = growingLeaf0.or(ValueEquals(expected: 1)).and(NeverMatches().not())
private let growingRule1 = growingLeaf1.returning(1)
private let growingLeaf2 = growingLeaf1.or(ValueEquals(expected: 2)).and(NeverMatches().not())
private let growingRule2 = growingLeaf2.returning(2)
private let growingLeaf3 = growingLeaf2.or(ValueEquals(expected: 3)).and(NeverMatches().not())
private let growingRule3 = growingLeaf3.returning(3)
private let growingLeaf4 = growingLeaf3.or(ValueEquals(expected: 4)).and(NeverMatches().not())
private let growingRule4 = growingLeaf4.returning(4)
private let growingLeaf5 = growingLeaf4.or(ValueEquals(expected: 5)).and(NeverMatches().not())
private let growingRule5 = growingLeaf5.returning(5)
private let growingLeaf6 = growingLeaf5.or(ValueEquals(expected: 6)).and(NeverMatches().not())
private let growingRule6 = growingLeaf6.returning(6)
private let growingLeaf7 = growingLeaf6.or(ValueEquals(expected: 7)).and(NeverMatches().not())
private let growingRule7 = growingLeaf7.returning(7)
private let growingLeaf8 = growingLeaf7.or(ValueEquals(expected: 8)).and(NeverMatches().not())
private let growingRule8 = growingLeaf8.returning(8)

private let nestedGrowingChain = BinaryFirstMatch(
    first: growingRule0,
    second: BinaryFirstMatch(
        first: growingRule1,
        second: BinaryFirstMatch(
            first: growingRule2,
            second: BinaryFirstMatch(
                first: growingRule3,
                second: BinaryFirstMatch(
                    first: growingRule4,
                    second: BinaryFirstMatch(
                        first: growingRule5,
                        second: BinaryFirstMatch(
                            first: growingRule6,
                            second: BinaryFirstMatch(first: growingRule7, second: growingRule8)
                        )
                    )
                )
            )
        )
    )
)

private let staticBalanced = StaticFirstMatch {
    growingRule0
    growingRule1
    growingRule2
    growingRule3
    growingRule4
    growingRule5
    growingRule6
    growingRule7
    growingRule8
}

private let variants = [
    Variant(name: "nested_growing_leaves_chain", evaluate: { nestedGrowingChain.decide($0) }),
    Variant(name: "static_balanced", evaluate: { staticBalanced.decide($0) })
]

private func expected(_ value: Int) -> Int? {
    if (0 ... 8).contains(value) {
        value
    } else {
        nil
    }
}

for variant in variants {
    for candidate in candidates {
        precondition(variant.evaluate(candidate) == expected(candidate.value))
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

let rounds = 32
print("round,strategy,elapsed_ns,ns_per_candidate,checksum")
for round in 0 ..< rounds {
    let offset = round % variants.count
    for step in 0 ..< variants.count {
        let variant = variants[(offset + step) % variants.count]
        let (elapsed, checksum) = measure(variant)
        print("\(round),\(variant.name),\(elapsed),\(Double(elapsed) / Double(candidates.count)),\(checksum)")
    }
}
