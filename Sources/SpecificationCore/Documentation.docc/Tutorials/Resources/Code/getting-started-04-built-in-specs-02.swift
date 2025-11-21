import SpecificationCore

let provider = DefaultContextProvider.shared

// TimeSinceEventSpec: Check time elapsed since an event
let cooldownSpec = TimeSinceEventSpec(
    eventKey: "last_notification",
    minimumInterval: 3600  // 1 hour in seconds
)

// Record when we showed a notification
provider.recordEvent("last_notification")

// Later, check if enough time has passed
let context = provider.currentContext()
if cooldownSpec.isSatisfiedBy(context) {
    print("Enough time has passed, can show notification")
    provider.recordEvent("last_notification")
}
