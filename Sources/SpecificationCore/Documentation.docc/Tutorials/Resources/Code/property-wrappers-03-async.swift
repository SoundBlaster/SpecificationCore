import SpecificationCore

struct AsyncFeatureManager {
    @Satisfies(using: MaxCountSpec(counterKey: "api_calls", maximumCount: 100))
    var canMakeAPICall: Bool

    // Use projected value for async evaluation
    func checkAPILimitAsync() async throws -> Bool {
        // Access async evaluation via $propertyName
        try await $canMakeAPICall.evaluateAsync()
    }

    func makeAPICallIfAllowed() async throws {
        // Synchronous check
        guard canMakeAPICall else {
            print("API limit reached")
            return
        }

        // Or async check
        let allowed = try await checkAPILimitAsync()
        if allowed {
            print("Making API call...")
            DefaultContextProvider.shared.incrementCounter("api_calls")
        }
    }
}
