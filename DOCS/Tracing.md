# Specification tracing

`Tracing` is an opt-in SwiftPM trait for inspecting specification evaluations. It is disabled by default. The trait raises this package's minimum Swift tools version to 6.1; the next release should therefore use a new major version.

Consumers enable the trait in their package dependency declaration:

```swift
.package(
    url: "https://github.com/SoundBlaster/SpecificationCore.git",
    from: "<release-containing-Tracing>",
    traits: ["Tracing"]
)
```

The placeholder above should be replaced with the published release version.

## Record an evaluation

```swift
let recorder = SpecificationTraceRecorder()
let allowed = SpecificationTraceRuntime.evaluate(rule, candidate, recordingTo: recorder)

for event in recorder.events {
    print(event.id, event.parentID as Any, event.name, event.outcome)
}
```

Use `evaluateAsync`, `decide`, or `decideAsync` for the corresponding protocol. The async entry points rethrow evaluation errors. The recorder remains available after a thrown error, so diagnostics can still inspect completed events. Events contain a name, parent ID, outcome, and duration. They do not contain candidate or result values.

## Trace custom specifications

```swift
@TracedSpecification("checkout.cart.eligible")
struct CartEligibility: Specification {
    func isSatisfiedBy(_ cart: Cart) -> Bool {
        cart.items.count > 0
    }
}
```

The macro wraps the existing `isSatisfiedBy(_:)` body. `@TraceEvaluation("stable.name")` can be attached directly to `isSatisfiedBy(_:)` or `decide(_:)`. Both support async evaluations. Use stable names for analytics; Swift type names can change during refactoring.

For a rule created from a closure, wrap the value instead:

```swift
let rule = AnySpecification<Int> { $0 > 0 }.traced("input.positive")
```

The runtime also traces the package's AND, OR, NOT, first-match, type-erased, and collection evaluation paths. Short-circuited branches are recorded as `skipped`; they are never evaluated for tracing. A user-defined method's internal calls are visible only when they pass through an instrumented composition or another traced method. Swift macros cannot automatically discover semantic calls inside arbitrary code. The existing `@specs` macro synthesizes its own evaluation method; its generated composition supplies the child trace events.

Tracing is scoped to each explicit entry point. Evaluations outside a trace scope return their usual results and do not create events. A recorder may be shared across tasks and synchronizes access to its event list. Logging and export adapters can consume the events without introducing logging dependencies into SpecificationCore.
