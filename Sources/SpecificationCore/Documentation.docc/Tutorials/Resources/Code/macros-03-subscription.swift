import SpecificationCore

// Subscription upgrade prompt specifications

struct UpgradePromptSpec: Specification {
    typealias T = EvaluationContext

    private let composite: AnySpecification<EvaluationContext>

    init() {
        // Show upgrade prompt when:
        // 1. User has been active for 7+ days
        // 2. Used premium features 5+ times
        // 3. Is NOT already a premium subscriber
        // 4. Haven't shown upgrade prompt in 3 days
        // 5. Has opened app 10+ times

        let activeUser = PredicateSpec<EvaluationContext>.counter(
            "days_active",
            .greaterThanOrEqual,
            7
        )
        let premiumUsage = PredicateSpec<EvaluationContext>.counter(
            "premium_feature_usage",
            .greaterThanOrEqual,
            5
        )
        let notPremium = PredicateSpec<EvaluationContext>.flag(
            "is_premium",
            equals: false
        )
        let promptCooldown = CooldownIntervalSpec(eventKey: "last_upgrade_prompt", days: 3)
        let engagedUser = PredicateSpec<EvaluationContext>.counter(
            "app_opens",
            .greaterThanOrEqual,
            10
        )

        composite = AnySpecification(
            activeUser
                .and(AnySpecification(premiumUsage))
                .and(AnySpecification(notPremium))
                .and(AnySpecification(promptCooldown))
                .and(AnySpecification(engagedUser))
        )
    }

    func isSatisfiedBy(_ context: EvaluationContext) -> Bool {
        composite.isSatisfiedBy(context)
    }
}

// Tiered access control
struct TierAccessSpec: Specification {
    typealias T = EvaluationContext

    let requiredTier: String

    func isSatisfiedBy(_ context: EvaluationContext) -> Bool {
        guard let userTier = context.userData["subscription_tier"] as? String else {
            return false
        }
        let tierOrder = ["free", "basic", "premium", "enterprise"]
        guard let userIndex = tierOrder.firstIndex(of: userTier),
              let requiredIndex = tierOrder.firstIndex(of: requiredTier)
        else {
            return false
        }
        return userIndex >= requiredIndex
    }
}
