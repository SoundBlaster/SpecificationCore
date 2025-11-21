import SpecificationCore

struct ContentManager {
    // @Maybe returns optional results - nil if no match
    @Maybe(
        provider: DefaultContextProvider.shared,
        using: FirstMatchSpec(cases: [
            (AnySpecification { $0.flag(for: "show_promo_a") }, "Summer Sale!"),
            (AnySpecification { $0.flag(for: "show_promo_b") }, "Holiday Discount!")
        ])
    )
    var promoMessage: String?

    func displayPromo() {
        if let message = promoMessage {
            print("Promo: \(message)")
        } else {
            print("No active promotions")
        }
    }
}

// Setup flags
let provider = DefaultContextProvider.shared
provider.setFlag("show_promo_a", to: true)

let manager = ContentManager()
manager.displayPromo() // "Promo: Summer Sale!"
