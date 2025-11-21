import SpecificationCore

// Build complex multi-condition specifications
struct FeatureGatingSpec: Specification {
    typealias T = EvaluationContext

    private let composite: AnySpecification<EvaluationContext>

    init(
        featureFlag: String,
        minAppLaunches: Int = 5,
        requirePremium: Bool = false
    ) {
        var specs: [AnySpecification<EvaluationContext>] = []

        // Feature must be enabled
        specs.append(
            AnySpecification { context in
                context.flag(for: featureFlag)
            })

        // User must have launched app minimum times
        specs.append(
            AnySpecification { context in
                context.counter(for: "app_launches") >= minAppLaunches
            })

        // Optional premium requirement
        if requirePremium {
            specs.append(
                AnySpecification { context in
                    context.flag(for: "is_premium")
                })
        }

        composite = specs.allSatisfied()
    }

    func isSatisfiedBy(_ context: EvaluationContext) -> Bool {
        composite.isSatisfiedBy(context)
    }
}

// Usage
let advancedFeature = FeatureGatingSpec(
    featureFlag: "advanced_analytics",
    minAppLaunches: 10,
    requirePremium: true
)
