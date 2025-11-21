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

// Get the current context for evaluation
let context = provider.currentContext()
print("App launches: \(context.counter(for: "app_launches"))")
