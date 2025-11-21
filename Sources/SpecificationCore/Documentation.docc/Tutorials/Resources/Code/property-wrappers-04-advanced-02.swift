import SpecificationCore

struct ConvenienceExample {
    // Use factory methods for common patterns

    // Time-based: true after 10 seconds since launch
    @Satisfies(predicate: { $0.timeSinceLaunch >= 10 })
    var hasBeenOpenLongEnough: Bool

    // Counter-based: true while counter < 5
    @Satisfies(using: MaxCountSpec.counter("views", limit: 5))
    var canShowMoreViews: Bool

    // Flag-based using predicate
    @Satisfies(predicate: { $0.flag(for: "dark_mode") })
    var isDarkModeEnabled: Bool

    // Cooldown-based
    @Satisfies(predicate: { context in
        guard let lastEvent = context.event(for: "last_notification") else {
            return true
        }
        return context.currentDate.timeIntervalSince(lastEvent) >= 3600
    })
    var canShowNotification: Bool
}

// Usage
let provider = DefaultContextProvider.shared
provider.setFlag("dark_mode", to: true)
provider.setCounter("views", to: 2)

let example = ConvenienceExample()
print("Dark mode: \(example.isDarkModeEnabled)") // true
print("Can show views: \(example.canShowMoreViews)") // true
