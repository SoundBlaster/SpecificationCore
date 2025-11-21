import SpecificationCore
import XCTest

final class ComplexSpecificationTests: XCTestCase {
    var mockProvider: MockContextProvider!

    override func setUp() {
        super.setUp()
        mockProvider = MockContextProvider()
    }

    func testPromoSpecShowsForEngagedUser() {
        // Setup: User has viewed products and no recent promo
        mockProvider.setCounter("products_viewed", to: 5)
        mockProvider.setCounter("app_launches", to: 10)

        let spec = ECommercePromoSpec()
        let context = mockProvider.currentContext()

        // Should show promo for engaged user
        XCTAssertTrue(spec.isSatisfiedBy(context))
    }

    func testPromoSpecHidesAfterRecentPurchase() {
        // Setup: User has purchased recently
        mockProvider.setCounter("products_viewed", to: 5)
        mockProvider.recordEvent("last_purchase") // Just now

        let spec = ECommercePromoSpec()
        let context = mockProvider.currentContext()

        // Should NOT show promo after recent purchase
        XCTAssertFalse(spec.isSatisfiedBy(context))
    }

    func testUpgradePromptForFreemiumUser() {
        // Setup: Active free user who uses premium features
        mockProvider.setCounter("days_active", to: 14)
        mockProvider.setCounter("premium_feature_usage", to: 8)
        mockProvider.setCounter("app_opens", to: 25)
        mockProvider.setFlag("is_premium", to: false)

        let spec = UpgradePromptSpec()
        let context = mockProvider.currentContext()

        XCTAssertTrue(spec.isSatisfiedBy(context))
    }

    func testUpgradePromptHiddenForPremiumUser() {
        // Setup: Already premium
        mockProvider.setCounter("days_active", to: 14)
        mockProvider.setFlag("is_premium", to: true)

        let spec = UpgradePromptSpec()
        let context = mockProvider.currentContext()

        // Premium users should NOT see upgrade prompt
        XCTAssertFalse(spec.isSatisfiedBy(context))
    }
}
