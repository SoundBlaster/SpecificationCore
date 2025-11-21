import SpecificationCore

struct AdvancedFeatureManager {
    // Use the builder pattern for complex specifications
    var canShowFeature: Satisfies<EvaluationContext> =
        .builder(provider: DefaultContextProvider.shared)
            .with(MaxCountSpec(counterKey: "feature_shown", maximumCount: 5))
            .with { context in context.flag(for: "feature_enabled") }
            .with { context in context.timeSinceLaunch >= 10 }
            .buildAll() // All conditions must be met

    // Or use anyOf for OR logic
    var hasAccess: Satisfies<EvaluationContext> =
        .builder(provider: DefaultContextProvider.shared)
            .with { context in context.flag(for: "is_premium") }
            .with { context in context.flag(for: "is_staff") }
            .buildAny() // Any condition can be met

    func checkAccess() {
        if canShowFeature.wrappedValue {
            print("Feature available")
        }

        if hasAccess.wrappedValue {
            print("Access granted")
        }
    }
}
