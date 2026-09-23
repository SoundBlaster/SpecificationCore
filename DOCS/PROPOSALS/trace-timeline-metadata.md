# Proposal: Shared trace timeline metadata

**Status:** Draft; API choices resolved for implementation

**Date:** 2026-09-24

**Target:** SpecificationCore 2.x

## Summary

Add a lightweight monotonic timeline that lets SpecificationCore events and events emitted by an integrating library share one comparable order and elapsed-time origin. Keep recorder-local IDs for tree relationships. Do not add logging, export, or application-specific event payloads to the package.

## Problem

`SpecificationTraceEvent` currently carries a recorder-local `id`, `parentID`, name, outcome, and duration. This is enough to render the tree from one recorder, but it cannot place a specification evaluation beside events recorded by another component. IDs from different recorders can collide, and duration alone says how long an evaluation took without saying when it happened relative to its neighbors.

This limits consumers such as SwiftDecision, which currently records lifecycle events and SpecificationCore events in separate arrays. They can preserve each array's order but cannot produce one reliable timeline.

## Goals

- Provide stable ordering metadata shared by multiple event producers during one operation.
- Represent specification evaluations as spans with monotonic start and completion positions.
- Preserve local `id` and `parentID` semantics for the existing specification tree.
- Keep trace metadata content-free and independent of wall-clock changes.
- Preserve current evaluation behavior and existing call sites.

## Non-goals

- Logging, analytics exporters, persistence, or UI rendering.
- A process-wide or cross-process total order.
- Recording candidate values, results, prompts, or arbitrary metadata dictionaries.
- Replacing recorder-local IDs or the existing duration field.

## Proposed API shape

Names are illustrative; the implementation should follow the package's API guidelines.

```swift
public struct SpecificationTracePosition: Sendable, Hashable {
    public let sequence: UInt64
    public let elapsedNanoseconds: UInt64
}

public final class SpecificationTraceTimeline: @unchecked Sendable {
    public init()
    public func mark() -> SpecificationTracePosition
}

public final class SpecificationTraceRecorder: @unchecked Sendable {
    public init(timeline: SpecificationTraceTimeline? = nil)
}
```

`mark()` atomically allocates a strictly increasing sequence and captures elapsed nanoseconds from a monotonic clock started with the timeline. Both values are captured inside the same synchronization boundary, so elapsed time cannot go backwards as sequence increases. The timeline is safe to share across concurrent tasks. Callers that need positions create one timeline per logical operation and pass it to each recorder and event producer.

`SpecificationTraceRecorder()` retains its existing behavior and records no positions. In particular, `SpecificationTraceRuntime.defaultRecorder` may be configured once for the whole process and reused across unrelated evaluations; it does not create an implicit process-wide timeline. To obtain comparable positions, callers use an explicit, operation-scoped timeline. A recorder given a timeline uses it for every evaluation recorded by that recorder, so it must not be reused across unrelated operations if operation scoping matters.

Add optional `startPosition` and `completionPosition` fields to `SpecificationTraceEvent`. Both are present for events from a recorder with an explicit timeline and both are absent for a recorder without one. The tracing runtime captures the start position when an instrumented evaluation begins and the completion position when it records the outcome. A skipped branch receives one mark as both its start and completion position. Existing `id` and `parentID` remain recorder-local, and `durationNanoseconds` remains available for existing consumers.

For consumer-authored point events, `timeline.mark()` returns the comparable position:

```swift
let timeline = SpecificationTraceTimeline()
let recorder = SpecificationTraceRecorder(timeline: timeline)
let requestPosition = timeline.mark() // Consumer lifecycle event.
let isValid = try await SpecificationTraceRuntime.evaluateAsync(
    requestRules,
    request,
    recordingTo: recorder
)
```

This snippet belongs in an async throwing context. The important contract is that both the recorder and consumer call `mark()` on the same timeline.

## Ordering and time semantics

- `sequence` is the authoritative tie-breaker and order for marks made through one timeline.
- `elapsedNanoseconds` is monotonic elapsed time from that timeline's creation. It is useful for relative placement and duration visualization.
- Marks from one timeline have unique sequences and nondecreasing elapsed offsets; equal offsets are possible at the clock's resolution. Sort by sequence. Positions from separate timelines have no common origin or order.
- Span start and completion positions expose overlap without claiming evaluations ran serially.
- `Date` is intentionally not part of the shared ordering contract. Consumers that need a wall-clock anchor can store one at their boundary and combine it with relative offsets according to their own retention policy.
- A timeline is scoped to one logical operation. Separate timelines cannot be compared.

## Compatibility

The additions are source-compatible: `SpecificationTraceRecorder()` continues to work, event IDs and parent IDs keep their current meaning, and the duration property remains unchanged. The existing `SpecificationTraceEvent` initializer must remain callable with its current arguments. An extended initializer can achieve this with trailing `startPosition: SpecificationTracePosition? = nil` and `completionPosition: SpecificationTracePosition? = nil` parameters, or by retaining the existing initializer as an overload. Merely making the new parameter types optional is insufficient in Swift. Existing consumers may ignore the new fields.

The runtime must behave identically when no trace is recorded. Timeline allocation and marks occur only on traced paths.

## Validation

- Verify sequence numbers increase across marks from multiple recorders sharing one timeline.
- Verify elapsed offsets never decrease as sequences increase, including concurrent marks.
- Verify evaluation start precedes completion and the position delta is consistent with the separately measured duration, allowing for mark and clock-call overhead.
- Verify nested parent relationships and recorder-local IDs remain unchanged.
- Verify `SpecificationTraceRecorder()` and a process-wide `defaultRecorder` emit no positions across multiple independent evaluations, while explicit per-operation timelines remain isolated.
- Compile an adapter using the existing five-argument `SpecificationTraceEvent` initializer without changes.
- Verify skipped, failed, and cancelled evaluations still produce the same outcomes and valid positions.
- Verify concurrent evaluations produce unique sequence values without corrupting tree relationships.
- Verify existing call sites compile without changes and untraced evaluation results remain identical.

## API decisions

1. Use `SpecificationTracePosition`. The explicit package prefix makes the shared value unambiguous in integrating libraries; it does not restrict which producer may call `mark()`.
2. Positions require an explicitly supplied timeline. This keeps the existing process-wide `defaultRecorder` from silently creating a cross-operation order.
3. Expose both `startPosition` and `completionPosition`. Duration alone cannot place the completion of overlapping spans in the shared sequence.
