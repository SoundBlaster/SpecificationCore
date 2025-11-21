import SpecificationCore

struct User {
    let name: String
    let age: Int
    let isPremium: Bool
    let country: String
}

struct AdultUserSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.age >= 18
    }
}

struct PremiumUserSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.isPremium
    }
}

struct USResidentSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.country == "US"
    }
}

// Combine specifications using logical operators
let adultSpec = AdultUserSpec()
let premiumSpec = PremiumUserSpec()
let usResidentSpec = USResidentSpec()

// User must be adult AND (premium OR US resident)
let eligibleSpec = adultSpec.and(premiumSpec.or(usResidentSpec))

// User must NOT be a minor
let notMinorSpec = adultSpec.not().not() // Same as adultSpec
