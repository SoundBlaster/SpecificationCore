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

let adultSpec = AdultUserSpec()
let premiumSpec = PremiumUserSpec()
let usResidentSpec = USResidentSpec()

// User must be adult AND (premium OR US resident)
let eligibleSpec = adultSpec.and(premiumSpec.or(usResidentSpec))

// Test with different users
let alice = User(name: "Alice", age: 25, isPremium: true, country: "UK")
let bob = User(name: "Bob", age: 30, isPremium: false, country: "US")
let charlie = User(name: "Charlie", age: 16, isPremium: true, country: "US")

print(eligibleSpec.isSatisfiedBy(alice)) // true (adult + premium)
print(eligibleSpec.isSatisfiedBy(bob)) // true (adult + US)
print(eligibleSpec.isSatisfiedBy(charlie)) // false (not adult)
