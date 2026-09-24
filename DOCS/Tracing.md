# Specification tracing

`Tracing` is an opt-in SwiftPM trait for inspecting specification evaluations. It is disabled by default and first became available in SpecificationCore 2.0.0, which requires Swift tools 6.1 or later. SpecificationCore 2.1.0 adds explicit operation-scoped timeline positions. SpecificationCore 1.1.0 is the last release compatible with Swift tools 5.10.

Consumers enable the trait in their package dependency declaration:

```swift
.package(
    url: "https://github.com/SoundBlaster/SpecificationCore.git",
    from: "2.1.0",
    traits: ["Tracing"]
)
```

## Configure once for the application

```swift
let recorder = SpecificationTraceRecorder()
SpecificationTraceRuntime.defaultRecorder = recorder

let allowed = rule.isSatisfiedBy(candidate) // Existing call site remains unchanged.
```

The default recorder is process-wide. Set it to `nil` to stop recording new evaluations. It keeps events in memory, so rotate or release a long-running recorder when its events are no longer needed. Instrument custom specifications with `@TracedSpecification` or `.traced(_:)` to give their calls individual spans.

Use `.withoutTracing()` on a synchronous specification or decision, or `.withoutTracingAsync()` on an asynchronous one, to omit that evaluation and its nested events while preserving its behavior. An enclosing composition still records its own outcome. Use `SpecificationTraceRuntime.withoutRecording { ... }` when the whole operation must be silent.

## Isolate one evaluation

```swift
let recorder = SpecificationTraceRecorder()
let allowed = SpecificationTraceRuntime.evaluate(rule, candidate, recordingTo: recorder)

for event in recorder.events {
    print(event.id, event.parentID as Any, event.name, event.outcome)
}
```

Use `evaluateAsync`, `decide`, or `decideAsync` for the corresponding protocol. The async entry points rethrow evaluation errors. The recorder remains available after a thrown error, so diagnostics can still inspect completed events. Events contain a name, parent ID, outcome, and duration. They do not contain candidate or result values.

To interleave specification evaluations with lifecycle events from another component, explicitly share one `SpecificationTraceTimeline` for a single logical operation:

```swift
let timeline = SpecificationTraceTimeline()
let recorder = SpecificationTraceRecorder(timeline: timeline)
let requestStarted = timeline.mark()
let accepted = SpecificationTraceRuntime.evaluate(orderEligibility, order, recordingTo: recorder)
let decisionCompleted = timeline.mark()
```

Each Core event then includes `startPosition` and `completionPosition`. A position contains a unique sequence and monotonic elapsed nanoseconds from the timeline's creation. Sort all event positions by sequence; keep `id` and `parentID` local to their recorder. `SpecificationTraceRecorder()` and a `defaultRecorder` created without a timeline continue to record without positions. Do not reuse one timeline across unrelated operations.

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
let asyncRule = AnyAsyncSpecification<Int> { $0 > 0 }.tracedAsync("input.positive")
```

The runtime also traces the package's AND, OR, NOT, first-match, type-erased, and collection evaluation paths. Short-circuited branches are recorded as `skipped`; they are never evaluated for tracing. A user-defined method's internal calls are visible only when they pass through an instrumented composition or another traced method. Swift macros cannot automatically discover semantic calls inside arbitrary code. The existing `@specs` macro synthesizes its own evaluation method; its generated composition supplies the child trace events.

An explicit entry point uses its own recorder for that task and overrides the application-wide default. Without either recorder, evaluations return their usual results and do not create events. A recorder may be shared across tasks and synchronizes access to its event list. Logging and export adapters can consume the events without introducing logging dependencies into SpecificationCore. See the [DocC guide](../Sources/SpecificationCore/Documentation.docc/Tracing.md) for the full API contract.
