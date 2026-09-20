# ``SpecificationCore/AsyncDecisionSpec``

Use `AsyncDecisionSpec` to evaluate an asynchronous rule and produce a typed result when it applies. A missing result is represented by `nil`; thrown errors propagate to the caller.

## Adapt an asynchronous condition

Call ``SpecificationCore/AsyncSpecification/returningAsync(_:)`` to associate a result with a boolean asynchronous specification:

```swift
import SpecificationCore

let isEligible = AnyAsyncSpecification<User> { user in
    try await subscriptionService.isActive(for: user)
}

let decision = isEligible.returningAsync("premium")
let result = try await decision.decide(user)
```

## Select the first matching result

`AsyncFirstMatchSpec` evaluates its pairs in order and stops after the first match. Later specifications are not started early. Errors and task cancellation propagate to the caller.

```swift
let decision = AsyncFirstMatchSpec<User, String>.builder()
    .add(SubscriptionActiveSpec(), result: "premium")
    .add(TrialPeriodSpec(), result: "trial")
    .fallback("standard")
    .build()

let tier = try await decision.decide(user)
```

Use ``AsyncFirstMatchSpec/decideWithMetadata(_:)`` when the result should include the zero-based index of the matching pair.

## Compose asynchronous conditions

Async specifications provide ``SpecificationCore/AsyncSpecification/andAsync(_:)``, ``SpecificationCore/AsyncSpecification/orAsync(_:)``, and ``SpecificationCore/AsyncSpecification/notAsync()``. The `andAsync` and `orAsync` operations short-circuit in the same way as their synchronous counterparts.
