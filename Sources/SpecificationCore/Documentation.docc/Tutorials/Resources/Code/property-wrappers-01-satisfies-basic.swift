import SpecificationCore

struct FeatureManager {
    // Use @Satisfies with a built-in specification
    @Satisfies(using: MaxCountSpec(counterKey: "banner_shown", maximumCount: 3))
    var canShowBanner: Bool

    // Use with custom provider
    @Satisfies(
        provider: DefaultContextProvider.shared,
        using: MaxCountSpec(counterKey: "promo_shown", maximumCount: 5)
    )
    var canShowPromo: Bool

    func checkFeatures() {
        if canShowBanner {
            print("Showing banner...")
            DefaultContextProvider.shared.incrementCounter("banner_shown")
        }
    }
}
