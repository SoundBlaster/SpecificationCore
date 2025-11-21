import SpecificationCore

// Combine patterns for maximum expressiveness

// Create a reusable specification factory
enum SpecificationFactory {

    // Promotional content specifications
    static func promoBanner(
        maxShows: Int = 3,
        cooldownHours: TimeInterval = 24
    ) -> AnySpecification<EvaluationContext> {
        let maxCount = MaxCountSpec(counterKey: "promo_shown", maximumCount: maxShows)
        let cooldown = CooldownIntervalSpec(eventKey: "last_promo", hours: cooldownHours)
        return AnySpecification(maxCount.and(cooldown))
    }

    // Feature gating specifications
    static func featureGate(
        flag: String,
        requiresEngagement: Bool = false
    ) -> AnySpecification<EvaluationContext> {
        var specs: [AnySpecification<EvaluationContext>] = [
            AnySpecification { $0.flag(for: flag) }
        ]

        if requiresEngagement {
            specs.append(AnySpecification { $0.counter(for: "sessions") >= 5 })
        }

        return specs.allSatisfied()
    }

    // Rate limiting specifications
    static func rateLimit(
        action: String,
        maxPerHour: Int
    ) -> AnySpecification<EvaluationContext> {
        AnySpecification(MaxCountSpec(counterKey: "\(action)_hourly", maximumCount: maxPerHour))
    }
}

// Usage
let promo = SpecificationFactory.promoBanner(maxShows: 2, cooldownHours: 48)
let feature = SpecificationFactory.featureGate(flag: "new_ui", requiresEngagement: true)
let rateLimit = SpecificationFactory.rateLimit(action: "api_call", maxPerHour: 100)
