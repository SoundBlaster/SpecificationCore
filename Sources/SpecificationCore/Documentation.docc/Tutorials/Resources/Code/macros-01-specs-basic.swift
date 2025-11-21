import SpecificationCore

// Create composite specifications using @specs macro
// Note: Requires SpecificationCoreMacros module

// Traditional approach (without macro)
struct BannerEligibilitySpec: Specification {
    typealias T = EvaluationContext

    let timeSinceLaunch = TimeSinceEventSpec.sinceAppLaunch(seconds: 10)
    let maxCount = MaxCountSpec(counterKey: "banner_shown", maximumCount: 3)
    let cooldown = CooldownIntervalSpec(eventKey: "last_banner", days: 1)

    func isSatisfiedBy(_ context: EvaluationContext) -> Bool {
        timeSinceLaunch.isSatisfiedBy(context) && maxCount.isSatisfiedBy(context)
            && cooldown.isSatisfiedBy(context)
    }
}

// With predefined CompositeSpec
let promoBanner = CompositeSpec.promoBanner
let ratingPrompt = CompositeSpec.ratingPrompt
