# Trace Specification Evaluations

Inspect the evaluation path of synchronous and asynchronous specifications with the optional `Tracing` SwiftPM trait.

## Enable tracing

The trait is disabled by default and requires Swift tools 6.1 or later. Enable it in your package manifest using a released version that includes the trait:

```swift
.package(
    url: "https://github.com/SoundBlaster/SpecificationCore.git",
    from: "<release-containing-Tracing>",
    traits: ["Tracing"]
)
```

The trait makes the trace API and macros available. It does not start recording automatically. Each evaluation needs an explicit trace scope.

## Record an evaluation

Create a ``SpecificationTraceRecorder`` and call the appropriate ``SpecificationTraceRuntime`` entry point:

```swift
let recorder = SpecificationTraceRecorder()
let allowed = SpecificationTraceRuntime.evaluate(rule, candidate, recordingTo: recorder)

for event in recorder.events {
    print(event.id, event.parentID as Any, event.name, event.outcome)
}
```

Use `evaluateAsync(_:_:recordingTo:)` for ``AsyncSpecification`` values, `decide(_:_:recordingTo:)` for ``DecisionSpec`` values, and `decideAsync(_:_:recordingTo:)` for ``AsyncDecisionSpec`` values. The asynchronous entry points propagate thrown errors, including cancellation. You can inspect the recorder after an error.

Each ``SpecificationTraceEvent`` has a recorder-local ID, optional parent ID, name, ``SpecificationTraceOutcome``, and duration in nanoseconds. The result of a Boolean evaluation is `.satisfied` or `.unsatisfied`; a decision is `.selected` or `.noMatch`. A branch skipped by short-circuit evaluation has `.skipped` and zero duration. An error produces `.failed` with the error type name, and a thrown `CancellationError` produces `.cancelled`. Events contain no candidate or decision result values.

Events are returned in ID order. A recorder can be shared across tasks, so sibling events from concurrent evaluations may interleave. Parent IDs reconstruct the tree within each scoped evaluation.

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
let recorder = SpecificationTraceRecorder()
let accepted = SpecificationTraceRuntime.evaluate(positive, 3, recordingTo: recorder)
```

The modifier is available for ``Specification``, ``AsyncSpecification``, ``DecisionSpec``, and ``AsyncDecisionSpec``. It returns a named wrapper: ``TracedSpecification``, ``TracedAsyncSpecification``, ``TracedDecisionSpec``, or ``TracedAsyncDecisionSpec``. The wrapper preserves the original result and error behavior.

## Understand trace coverage

Built-in AND, OR, NOT, first-match, type-erased, and collection evaluation paths emit child events when called within a trace scope. Short-circuited branches are marked `.skipped` and are not evaluated. Calls made inside arbitrary user code appear as child events only when they pass through an instrumented composition or traced method. A macro cannot infer semantic calls inside an arbitrary method body. The `@specs` macro synthesizes composition code whose children are traced by the runtime.

Calls outside `SpecificationTraceRuntime` entry points behave normally and record no events. ``SpecificationTraceRecorder`` synchronizes its event storage; it does not export, log, or retain input values. Applications can translate the recorded events to their own diagnostics or observability system.

## Topics

### Recording

- ``SpecificationTraceRuntime``
- ``SpecificationTraceRecorder``
- ``SpecificationTraceEvent``
- ``SpecificationTraceOutcome``

### Named Wrappers

- ``TracedSpecification``
- ``TracedAsyncSpecification``
- ``TracedDecisionSpec``
- ``TracedAsyncDecisionSpec``

### Macros

- ``TracedSpecification(_:)``
- ``TraceEvaluation(_:)``
