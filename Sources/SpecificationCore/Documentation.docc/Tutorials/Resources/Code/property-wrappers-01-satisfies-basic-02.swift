import SpecificationCore

struct FeatureManager {
    // Use inline predicate for simple conditions
    @Satisfies(predicate: { context in
        context.counter(for: "app_launches") >= 3
    })
    var hasUsedAppEnough: Bool

    // Use convenience factory methods
    @Satisfies(using: MaxCountSpec.onlyOnce("welcome_shown"))
    var shouldShowWelcome: Bool

    // Combine conditions with allOf
    @Satisfies(allOf: [
        AnySpecification(MaxCountSpec(counterKey: "banner_shown", maximumCount: 3)),
        AnySpecification { context in context.flag(for: "banners_enabled") }
    ])
    var canShowBannerWithFlag: Bool

    func onAppLaunch() {
        if shouldShowWelcome {
            showWelcomeScreen()
            DefaultContextProvider.shared.incrementCounter("welcome_shown")
        }
    }

    func showWelcomeScreen() {
        print("Welcome!")
    }
}
