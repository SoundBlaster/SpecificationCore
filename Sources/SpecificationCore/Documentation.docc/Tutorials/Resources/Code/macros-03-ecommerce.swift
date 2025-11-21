import SpecificationCore

// Real-world e-commerce promotional specifications

struct ECommercePromoSpec: Specification {
    typealias T = EvaluationContext

    private let composite: AnySpecification<EvaluationContext>

    init() {
        // Show promo when:
        // 1. User browsed for at least 2 minutes
        // 2. Viewed at least 3 products
        // 3. No purchase in last 24 hours
        // 4. No promo shown in last 4 hours

        let browsingTime = TimeSinceEventSpec.sinceAppLaunch(minutes: 2)
        let productViews = PredicateSpec<EvaluationContext>.counter(
            "products_viewed",
            .greaterThanOrEqual,
            3
        )
        let noPurchaseRecently = CooldownIntervalSpec(eventKey: "last_purchase", hours: 24)
        let promoCooldown = CooldownIntervalSpec(eventKey: "last_promo", hours: 4)

        composite = AnySpecification(
            browsingTime
                .and(AnySpecification(productViews))
                .and(AnySpecification(noPurchaseRecently))
                .and(AnySpecification(promoCooldown))
        )
    }

    func isSatisfiedBy(_ context: EvaluationContext) -> Bool {
        composite.isSatisfiedBy(context)
    }
}

// Usage
let provider = DefaultContextProvider.shared
provider.setCounter("products_viewed", to: 5)

let promoSpec = ECommercePromoSpec()
let context = provider.currentContext()

if promoSpec.isSatisfiedBy(context) {
    showDiscountBanner()
    provider.recordEvent("last_promo")
}

func showDiscountBanner() {
    print("10% off your next purchase!")
}
