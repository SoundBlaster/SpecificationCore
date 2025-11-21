import SpecificationCore

struct User {
    let name: String
    let age: Int
    let isPremium: Bool
    let country: String
}

// Create focused, single-responsibility specifications
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
