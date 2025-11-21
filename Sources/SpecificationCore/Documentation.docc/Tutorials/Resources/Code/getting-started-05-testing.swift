import SpecificationCore
import XCTest

final class SpecificationTests: XCTestCase {
    func testMaxCountSpec() {
        // Create a fresh provider for testing
        let provider = MockContextProvider()

        // Set up test state
        provider.setCounter("banner_shown", to: 2)

        let spec = MaxCountSpec(counterKey: "banner_shown", maximumCount: 3)
        let context = provider.currentContext()

        // Counter is 2, max is 3, so should be satisfied
        XCTAssertTrue(spec.isSatisfiedBy(context))

        // Increment to 3
        provider.setCounter("banner_shown", to: 3)
        let updatedContext = provider.currentContext()

        // Now at limit, should not be satisfied
        XCTAssertFalse(spec.isSatisfiedBy(updatedContext))
    }

    func testComposedSpecification() {
        struct AgeSpec: Specification {
            let minAge: Int
            func isSatisfiedBy(_ age: Int) -> Bool {
                age >= minAge
            }
        }

        let adultSpec = AgeSpec(minAge: 18)
        let seniorSpec = AgeSpec(minAge: 65)

        // Adult but not senior
        let middleAgedSpec = adultSpec.and(seniorSpec.not())

        XCTAssertTrue(middleAgedSpec.isSatisfiedBy(30))
        XCTAssertFalse(middleAgedSpec.isSatisfiedBy(16))
        XCTAssertFalse(middleAgedSpec.isSatisfiedBy(70))
    }
}
