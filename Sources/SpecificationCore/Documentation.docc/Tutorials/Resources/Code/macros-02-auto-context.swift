import SpecificationCore

// @AutoContext enables automatic context provider access
// The macro synthesizes an isSatisfied property that uses the default provider

// Without @AutoContext - manual context access
struct ManualBannerSpec: Specification {
    typealias T = EvaluationContext

    func isSatisfiedBy(_ context: EvaluationContext) -> Bool {
        context.counter(for: "banner_shown") < 3 && context.timeSinceLaunch >= 10
    }

    // Manual evaluation requires provider
    func evaluate(using provider: some ContextProviding) -> Bool {
        isSatisfiedBy(provider.currentContext())
    }
}

// With @AutoContext (when using SpecificationCoreMacros)
// @AutoContext
// struct AutoBannerSpec: Specification {
//     typealias T = EvaluationContext
//
//     func isSatisfiedBy(_ context: EvaluationContext) -> Bool {
//         context.counter(for: "banner_shown") < 3
//     }
//
//     // Synthesized: var isSatisfied: Bool (uses DefaultContextProvider.shared)
// }

// Usage pattern
let spec = ManualBannerSpec()
let context = DefaultContextProvider.shared.currentContext()
let canShow = spec.isSatisfiedBy(context)
