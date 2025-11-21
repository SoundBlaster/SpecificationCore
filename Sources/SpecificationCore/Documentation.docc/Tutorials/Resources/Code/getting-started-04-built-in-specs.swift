import SpecificationCore

let provider = DefaultContextProvider.shared

// MaxCountSpec: Limit how many times something can happen
let maxBannerShows = MaxCountSpec(counterKey: "banner_shown", maximumCount: 3)

// Check if we can show the banner
let context = provider.currentContext()
if maxBannerShows.isSatisfiedBy(context) {
    print("Showing banner...")
    provider.incrementCounter("banner_shown")
}

// Convenience factory methods
let onlyOnce = MaxCountSpec.onlyOnce("welcome_shown")
let dailyLimit = MaxCountSpec.dailyLimit("api_calls", limit: 100)
