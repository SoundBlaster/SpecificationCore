import SpecificationCore

// Create a context provider and set up state
let provider = DefaultContextProvider.shared

// Record events for time-based tracking
provider.recordEvent("last_login")
provider.recordEvent("tutorial_completed")

// Set counters for usage tracking
provider.setCounter("app_launches", to: 5)
provider.incrementCounter("page_views")

// Set feature flags
provider.setFlag("premium_features", to: true)

// Use built-in specifications with context
let maxShowsSpec = MaxCountSpec(counterKey: "banner_shown", maximumCount: 3)

// Evaluate against the current context
let context = provider.currentContext()
let canShowBanner = maxShowsSpec.isSatisfiedBy(context)
print("Can show banner: \(canShowBanner)")  // true (counter is 0)

// After showing the banner, increment the counter
provider.incrementCounter("banner_shown")
