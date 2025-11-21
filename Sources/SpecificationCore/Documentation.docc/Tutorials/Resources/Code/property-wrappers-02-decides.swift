import SpecificationCore

// Define tiers for decision routing
enum SubscriptionTier: String {
    case free
    case basic
    case premium
}

struct SubscriptionManager {
    // @Decides returns typed values based on specification matches
    @Decides(
        provider: DefaultContextProvider.shared,
        using: FirstMatchSpec(cases: [
            (AnySpecification { $0.flag(for: "is_premium") }, SubscriptionTier.premium),
            (AnySpecification { $0.flag(for: "is_basic") }, SubscriptionTier.basic)
        ]),
        default: .free
    )
    var currentTier: SubscriptionTier

    func displayContent() {
        switch currentTier {
        case .premium:
            print("Showing all premium features")
        case .basic:
            print("Showing basic features")
        case .free:
            print("Showing free tier content")
        }
    }
}
