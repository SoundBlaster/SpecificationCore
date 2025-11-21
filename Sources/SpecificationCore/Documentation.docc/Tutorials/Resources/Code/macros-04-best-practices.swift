import SpecificationCore

// Best Practices for Specification Design

// 1. Keep specifications focused and single-purpose
struct IsAdultSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.age >= 18
    }
}

// 2. Use descriptive names that explain the business rule
struct CanReceiveMarketingEmailsSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.hasOptedInToMarketing && user.emailVerified
    }
}

// 3. Compose complex rules from simple specifications
let eligibleForPromo = IsAdultSpec()
    .and(CanReceiveMarketingEmailsSpec())

// 4. Use factory methods for common configurations
extension MaxCountSpec {
    static func dailyAPILimit() -> MaxCountSpec {
        MaxCountSpec(counterKey: "daily_api_calls", maximumCount: 1000)
    }
}

// 5. Document business rules in specification comments
/// Determines if a user qualifies for the loyalty program.
/// Requirements:
/// - Account age >= 90 days
/// - Total purchases >= $100
/// - No fraud flags
struct LoyaltyProgramEligibilitySpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.accountAgeDays >= 90 && user.totalPurchaseAmount >= 100 && !user.hasFraudFlag
    }
}

// 6. Use type-safe keys for counters and events
enum ContextKey {
    static let bannerShown = "banner_shown"
    static let lastPromo = "last_promo"
    static let appLaunches = "app_launches"
}

let spec = MaxCountSpec(counterKey: ContextKey.bannerShown, maximumCount: 3)

// Supporting types
struct User {
    let age: Int
    let hasOptedInToMarketing: Bool
    let emailVerified: Bool
    let accountAgeDays: Int
    let totalPurchaseAmount: Double
    let hasFraudFlag: Bool
}
