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
