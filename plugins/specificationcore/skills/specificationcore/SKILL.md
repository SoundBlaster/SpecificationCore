---
name: specificationcore
description: Use when designing, implementing, or reviewing Swift code that uses SpecificationCore. Covers synchronous and asynchronous rules, typed decisions, composition, context, tracing, and tests.
---

# Use SpecificationCore well

Help the user express business rules as small, typed, composable specifications. Fit the existing code and the resolved SpecificationCore version; do not invent APIs or change package versions as part of an application-level task.

## Establish the API version

Before proposing code, inspect the consuming project's `Package.resolved` and `Package.swift`. Confirm the SpecificationCore version, Swift tools version, and whether the `Tracing` trait is enabled. Use the API for that resolved version, not automatically the latest API.

When a checkout of SpecificationCore is available, use its DocC articles under `Sources/SpecificationCore/Documentation.docc` and implementation as the source of truth. Otherwise use the documentation shipped with the dependency or the matching upstream release. Useful topics include `Specification`, `AsyncSpecification`, `DecisionSpec`, `AsyncDecisionSpec`, `FirstMatchSpec`, `Tracing`, and `SpecsMacro`.

SpecificationCore 2.0.0 requires Swift tools 6.1. Tracing is an opt-in SwiftPM trait and is not available unless enabled by the dependency declaration. Do not enable a trait or raise the app's deployment targets unless the task requires it.

## Model the rule

- Use `Specification` when evaluation is synchronous and returns `Bool`.
- Use `AsyncSpecification` when evaluation awaits I/O or another async operation. Preserve its `throws` behavior and call it with `try await`.
- Use `DecisionSpec` when a synchronous rule returns a typed result or `nil` when no rule applies. Use `AsyncDecisionSpec` for asynchronous decisions.
- Keep “no match” distinct from thrown errors. A decision's `nil` is not an error and should not be silently converted into a fallback unless the caller explicitly wants one.
- Keep specifications focused on answering whether a rule applies. Put orchestration, side effects, cancellation, and user-facing fallback policy in the owning application layer unless the existing abstraction explicitly owns them.

## Compose rules

Use `.and`, `.or`, and `.not` (or `&&`, `||`, and `!`) for synchronous Boolean composition. These compositions short-circuit; do not depend on later rules being evaluated after a decisive result.

For asynchronous composition use the explicit async operations `.andAsync`, `.orAsync`, and `.notAsync`. Their distinct names keep call sites clear when a type supports both sync and async protocols. Preserve short-circuiting, error propagation, and cancellation.

Use `FirstMatchSpec` or `AsyncFirstMatchSpec` for ordered routing and policy selection. Rule order is observable: keep higher-priority rules first, and make fallback behavior explicit. Async first-match evaluation is sequential; do not change it to parallel evaluation without confirming that the altered ordering and side effects are acceptable.

Use `AnySpecification`, `AnyAsyncSpecification`, or the corresponding decision type only when type erasure is needed, such as storing heterogeneous concrete specifications together. Prefer concrete types when they keep the composition understandable.

Use `@specs` for a declarative AND composition when its generated shape fits the rule. Use property wrappers such as `@Satisfies`, `@Decides`, `@Maybe`, or `@AsyncSatisfies` when they improve the owning model's API; do not use them to hide important evaluation, error, or fallback behavior.

## Add trace names

Tracing is opt-in. If it is enabled:

- Give a `PredicateSpec` a stable `description`; the predicate records that description as its event name.
- Annotate a custom specification with `@TracedSpecification("domain.rule.name")`, or annotate only its evaluation method with `@TraceEvaluation("domain.rule.name")`.
- Wrap a runtime-created synchronous value with `.traced("domain.rule.name")`; use `.tracedAsync("domain.rule.name")` for async specifications and async decisions.
- Use `.withoutTracing()` / `.withoutTracingAsync()` for an excluded subtree, or `SpecificationTraceRuntime.withoutRecording` when the entire operation must emit no events.

Configure `SpecificationTraceRuntime.defaultRecorder` once for app-wide collection, or use an explicit `SpecificationTraceRuntime` scope for one operation. A default recorder is process-wide, concurrent roots can interleave, and recorded events remain in memory until released. Events intentionally omit candidate and result values; do not add sensitive input data to trace names.

Prefer stable semantic identifiers over reflected Swift type names when trace consumers depend on the names. Avoid wrapping a `PredicateSpec` in `.traced(...)` when its `description` already provides the desired name, since both layers can emit events.

## Test the behavior

Follow the test framework and naming style used by nearby tests. Cover the contract that matters:

- Boolean results and composition short-circuiting.
- First-match ordering and explicit fallback/no-match behavior.
- Async errors and cancellation when an async rule can throw.
- Trace names, outcomes, parent-child relationships, exclusions, and skipped branches when tracing is enabled.

Prefer deterministic fake services for async specifications. Do not make ordinary tests depend on live network services, credentials, wall-clock timing, or a model backend.

## References

- [SpecificationCore repository](https://github.com/SoundBlaster/SpecificationCore)
- [Tracing DocC guide](https://github.com/SoundBlaster/SpecificationCore/blob/main/Sources/SpecificationCore/Documentation.docc/Tracing.md)
- [Async decision DocC guide](https://github.com/SoundBlaster/SpecificationCore/blob/main/Sources/SpecificationCore/Documentation.docc/AsyncDecisionSpec.md)
- [Specification operators DocC guide](https://github.com/SoundBlaster/SpecificationCore/blob/main/Sources/SpecificationCore/Documentation.docc/SpecificationOperators.md)
