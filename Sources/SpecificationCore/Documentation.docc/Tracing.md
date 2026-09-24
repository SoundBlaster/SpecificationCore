# Trace Specification Evaluations

Inspect the evaluation path of synchronous and asynchronous specifications with the optional `Tracing` SwiftPM trait. SpecificationCore 2.1.0 adds operation-scoped monotonic positions for correlating Core spans with events from other components.

## Enable tracing

The trait is disabled by default and requires Swift tools 6.1 or later. Enable it in your package manifest using a released version that includes the trait:

```swift
.package(
    url: "https://github.com/SoundBlaster/SpecificationCore.git",
    from: "2.1.0",
    traits: ["Tracing"]
)
```

The trait makes the trace API and macros available. Configure a default recorder once at application startup to collect events from instrumented specifications without changing evaluation call sites.

## Record throughout an application

Set ``SpecificationTraceRuntime/defaultRecorder`` once, then keep calling `isSatisfiedBy(_:)` and `decide(_:)` as usual:

```swift
let recorder = SpecificationTraceRecorder()
SpecificationTraceRuntime.defaultRecorder = recorder

let allowed = rule.isSatisfiedBy(candidate)

for event in recorder.events {
    print(event.id, event.parentID as Any, event.name, event.outcome)
}

SpecificationTraceRuntime.defaultRecorder = nil // Stop recording when finished.
```

This setting is process-wide and thread-safe. Concurrent evaluations share the recorder, and their root events can interleave. The default recorder does not create a timeline, so its events do not receive positions that imply a total order across operations. Keep a long-running recorder only as long as needed for diagnostics, since it retains every event until released. Setting the property to `nil` stops new root events; an evaluation already in progress finishes with the recorder it started with.

## Isolate one evaluation

The explicit ``SpecificationTraceRuntime`` entry points remain useful when a tool needs a separate recorder for one operation:

```swift
let recorder = SpecificationTraceRecorder()
let allowed = SpecificationTraceRuntime.evaluate(rule, candidate, recordingTo: recorder)
```

Use `evaluateAsync(_:_:recordingTo:)` for ``AsyncSpecification`` values, `decide(_:_:recordingTo:)` for ``DecisionSpec`` values, and `decideAsync(_:_:recordingTo:)` for ``AsyncDecisionSpec`` values. An explicit scope takes precedence over the process-wide recorder for that task. The asynchronous entry points propagate thrown errors, including cancellation. You can inspect the recorder after an error.

Each ``SpecificationTraceEvent`` has a recorder-local ID, optional parent ID, name, ``SpecificationTraceOutcome``, and duration in nanoseconds. The result of a Boolean evaluation is `.satisfied` or `.unsatisfied`; a decision is `.selected` or `.noMatch`. A branch skipped by short-circuit evaluation has `.skipped` and zero duration. An error produces `.failed` with the error type name, and a thrown `CancellationError` produces `.cancelled`. Events contain no candidate or decision result values.

Events are returned in ID order. Parent IDs reconstruct each instrumented evaluation tree, including evaluations captured through the default recorder.

## Correlate events from multiple components

Recorder-local IDs cannot order events from different recorders. To place specification spans beside lifecycle events from an integrating library, create one ``SpecificationTraceTimeline`` for that logical operation and pass it explicitly to the recorder and event producer:

```swift
func evaluateOrder(_ order: Order) async throws -> Bool {
    let timeline = SpecificationTraceTimeline()
    let recorder = SpecificationTraceRecorder(timeline: timeline)
    let requestPosition = timeline.mark()
    let allowed = try await SpecificationTraceRuntime.evaluateAsync(
        orderEligibility,
        order,
        recordingTo: recorder
    )
    let decisionPosition = timeline.mark()

    print(requestPosition.sequence, decisionPosition.sequence)
    for event in recorder.events {
        print(event.name, event.startPosition as Any, event.completionPosition as Any)
    }
    return allowed
}
```

Positions contain a strictly increasing sequence and monotonic elapsed nanoseconds relative to that timeline. The sequence is authoritative when elapsed offsets tie at clock resolution. A traced evaluation records `startPosition` and `completionPosition`; a skipped branch uses the same position for both. Sort events from all producers by sequence to interleave them, and keep `parentID` scoped to its recorder when reconstructing Core's tree.

``SpecificationTraceRecorder()`` does not create a timeline, so its events have no positions. The process-wide ``SpecificationTraceRuntime/defaultRecorder`` likewise creates no implicit shared scale. A timeline must be supplied explicitly, and should not be shared across unrelated logical operations.

## Trace custom specifications

Attach ``TracedSpecification(_:)`` to a user-defined type to instrument its supported evaluation methods without changing their bodies:

```swift
@TracedSpecification("checkout.cart.eligible")
struct CartEligibility: Specification {
    func isSatisfiedBy(_ cart: Cart) -> Bool {
        !cart.items.isEmpty
    }
}
```

For one method, attach ``TraceEvaluation(_:)`` directly to `isSatisfiedBy(_:)` or `decide(_:)`. Both macros support synchronous and asynchronous methods. Use a stable name if traces are consumed by logging or analytics; reflected Swift type names can change during refactoring.

For a specification created from a closure, use the `traced(_:)` modifier:

```swift
let positive = AnySpecification<Int> { $0 > 0 }.traced("input.positive")
let accepted = positive.isSatisfiedBy(3) // Recorded when defaultRecorder is configured.
```

Use `.tracedAsync(_:)` for ``AsyncSpecification`` and ``AsyncDecisionSpec``. The distinct name keeps calls unambiguous when a type conforms to both the synchronous and asynchronous protocols. These modifiers return ``TracedSpecification``, ``TracedAsyncSpecification``, ``TracedDecisionSpec``, or ``TracedAsyncDecisionSpec``. The wrappers preserve the original result and error behavior. `@TraceEvaluation` also preserves the error type of an `async throws(Failure)` method.

## Exclude an evaluation

Use `withoutTracing()` to run one specification or decision without recording its event or any nested events:

```swift
let privateCheck = PredicateSpec<User> { user in user.hasSensitiveFlag }.withoutTracing()
let eligibility = publicCheck.and(privateCheck)
let allowed = eligibility.isSatisfiedBy(user)
```

Use `.withoutTracingAsync()` for asynchronous specifications and decisions. The two names remain unambiguous for types with both conformances. These modifiers return ``UntracedSpecification``, ``UntracedAsyncSpecification``, ``UntracedDecisionSpec``, or ``UntracedAsyncDecisionSpec``. The result, error propagation, and short-circuit behavior are unchanged. Exclusion is preserved through the package's type-erased wrappers and built-in compositions, including first-match and collection paths. It also takes precedence when `.traced(_:)` or `.tracedAsync(_:)` is applied after the corresponding exclusion modifier.

The enclosing composition still records its own outcome. If that outcome is sensitive, suppress the entire operation with ``SpecificationTraceRuntime``'s `withoutRecording(_:)` method:

```swift
let allowed = SpecificationTraceRuntime.withoutRecording {
    eligibility.isSatisfiedBy(user)
}
```

The suppression scope also applies to nested async calls. Use the asynchronous overload for a throwing async operation. A custom composition that creates a span before calling an excluded child may still emit that span; use `withoutRecording` around the whole operation when complete silence is required.

## Understand trace coverage

Built-in AND, OR, NOT, first-match, type-erased, and collection evaluation paths emit child events when a default recorder or explicit scope is active. ``PredicateSpec`` also records its direct evaluations, using its description as the event name when available. Short-circuited branches are marked `.skipped` and are not evaluated. Collection tracing does not materialize unused elements of a lazy collection. Calls made inside arbitrary user code appear as child events only when they pass through an instrumented composition or traced method. A macro cannot infer semantic calls inside an arbitrary method body. The `@specs` macro synthesizes composition code whose children are traced by the runtime.

Swift cannot intercept every arbitrary `Specification` conformance automatically. Annotate user-defined types with `@TracedSpecification` or wrap values with `.traced(_:)` to give them their own spans. With neither a default recorder nor an explicit scope, all evaluations behave normally and record no events. ``SpecificationTraceRecorder`` synchronizes its event storage; it does not export, log, or retain input values. Applications can translate the recorded events to their own diagnostics or observability system.

## Topics

### Recording

- ``SpecificationTraceRuntime``
- ``SpecificationTraceRecorder``
- ``SpecificationTraceTimeline``
- ``SpecificationTracePosition``
- ``SpecificationTraceEvent``
- ``SpecificationTraceOutcome``

### Named Wrappers

- ``TracedSpecification``
- ``TracedAsyncSpecification``
- ``TracedDecisionSpec``
- ``TracedAsyncDecisionSpec``
- ``UntracedSpecification``
- ``UntracedAsyncSpecification``
- ``UntracedDecisionSpec``
- ``UntracedAsyncDecisionSpec``

### Macros

- ``TracedSpecification(_:)``
- ``TraceEvaluation(_:)``
