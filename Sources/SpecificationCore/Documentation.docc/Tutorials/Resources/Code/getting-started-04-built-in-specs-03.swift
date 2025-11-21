import SpecificationCore

let provider = DefaultContextProvider.shared

// Combine built-in specs for complex rules
let maxShows = MaxCountSpec(counterKey: "promo_shown", maximumCount: 5)
let cooldown = TimeSinceEventSpec(eventKey: "last_promo", minimumInterval: 86400)

// Show promo only if under limit AND cooldown passed
let canShowPromo = maxShows.and(cooldown)

let context = provider.currentContext()
if canShowPromo.isSatisfiedBy(context) {
    showPromotion()
    provider.incrementCounter("promo_shown")
    provider.recordEvent("last_promo")
}

func showPromotion() {
    print("Displaying promotion...")
}
