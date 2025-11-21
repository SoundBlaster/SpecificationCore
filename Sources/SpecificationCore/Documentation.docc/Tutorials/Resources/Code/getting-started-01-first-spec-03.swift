import SpecificationCore

// Define a model to evaluate
struct User {
    let name: String
    let age: Int
    let isPremium: Bool
}

// Create a specification that checks if a user is an adult
struct AdultUserSpec: Specification {
    func isSatisfiedBy(_ user: User) -> Bool {
        user.age >= 18
    }
}

// Test the specification
let adultSpec = AdultUserSpec()

let alice = User(name: "Alice", age: 25, isPremium: false)
let bob = User(name: "Bob", age: 16, isPremium: true)

print(adultSpec.isSatisfiedBy(alice))  // true
print(adultSpec.isSatisfiedBy(bob))  // false
