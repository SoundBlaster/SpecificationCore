---
name: specification-patterns
description: Decide where SpecificationCore clarifies domain policy; use when designing or refactoring decision-heavy code, explaining pattern benefits and trade-offs, or evaluating refactoring pilots.
---

# Shape code around semantic decisions

Use this skill to put stable domain decisions in named, testable specifications without turning every branch into a specification. A syntactic opportunity is a prompt to inspect intent, not an instruction to refactor.

For exact APIs, first check the consuming project's resolved SpecificationCore version, then follow the [SpecificationCore API skill](../specificationcore/SKILL.md).

## Understand the benefit

SpecificationCore provides a common way to name, compose, test, observe, and change domain rules. Its value includes a consistent development style for humans and agents: callers consume a policy contract instead of reconstructing its conditions. A useful extraction can also expose duplicated rules, unreachable fallbacks, or a decision being recomputed in the wrong layer.

Evaluate the whole decision family, including specifications and their callers. A shorter caller is useful evidence, but does not show that total complexity or duplication fell. For choosing a refactor, explaining its benefit, or assessing a pilot, read [Benefits and evidence](references/benefits-and-evidence.md).

## Decide whether a branch expresses policy

Before changing code, state the question the code answers and list its meaningful outcomes. A decision is a strong specification candidate when it:

- chooses a domain outcome such as eligibility, lifecycle state, authority/provenance, completeness, or routing;
- has stable named alternatives, priority, or a meaningful no-match case;
- is repeated across call sites, needs a single place to evolve, or benefits from named traces and branch-level tests.

Keep ordinary control flow when it performs mechanics: parsing or recognizing syntax, adapting I/O into facts, handling exceptions, projecting optional values, iterating/aggregating, serializing, or carrying out side effects. A large `switch` is not automatically a domain rule; inspect what the cases mean and whether the same decision is duplicated elsewhere.

When repeated cases dispatch behavior already owned by variants of an enum or protocol, consider placing that behavior with the variants. Keep a switch at a boundary when it translates external or syntactic forms into typed domain facts.

## Keep responsibilities in their layer

Use a narrow pipeline:

```text
input / I-O adapter -> typed facts -> named policy specifications -> typed outcome -> application effects
```

Adapters may branch to parse formats and report malformed input. Specifications evaluate prepared facts; they should not fetch, mutate, publish, or hide fallback effects. The application layer interprets the outcome and performs effects. Do not move a decision to another layer just to make a file-level metric smaller.

Model one semantic decision per specification. Do not create one specification for every `if`, every field, or every line. Prefer a small immutable context that names the facts the decision needs. Put each new concrete specification in its own source file; share a context type only when it is substantial or used by multiple rules.

Use Boolean specifications for predicates. Use `FirstMatchSpec` for ordered alternatives and make the fallback explicit. Preserve a meaningful no-match result when absence is part of the contract; do not silently turn it into a fallback. Keep priority order observable and deliberate.

When alternatives produce the same outcome and priority has no semantic meaning, prefer one Boolean specification with explicit composition rather than an ordered decision table. Keep independent observations independent: for example, an operation can be a no-op while findings still prevent readiness.

For example, a routing decision can use an immutable context and typed outcomes:

```swift
enum AccessOutcome { case denied, trial, allowed }

struct AccessContext {
    let accountIsSuspended: Bool
    let isInTrial: Bool
}

let accessSpec = FirstMatchSpec<AccessContext, AccessOutcome>.withFallback([
    (PredicateSpec<AccessContext>(description: "account.suspended") { $0.accountIsSuspended }, .denied),
    (PredicateSpec<AccessContext>(description: "account.trial") { $0.isInTrial }, .trial),
], fallback: .allowed)
```

The caller remains responsible for enforcing the outcome; evaluating the specification does not perform an access-control side effect. Check the resolved package API version before copying an example into a consuming project.

## Implement and verify

1. Record the current behavior as a decision table: input facts, outcome, precedence, no-match/error behavior, and effects owned by the caller.
   Trace the production callers and producer guarantees. A fallback tested with constructed inputs can still be unreachable in the real pipeline; distinguish reachable behavior from obsolete or contradictory logic before extraction.
2. Separate facts already available at the decision boundary from parsing and external work. Build a typed context from those facts.
3. Name the semantic rules and outcomes. Extract only the policy decision; leave mechanical branches and orchestration in their current owners.
4. Compare observable behavior before and after, including warning/error details and side-effect timing where relevant.
5. Test every outcome, overlapping rules and priority, fallback/no-match, and representative malformed or boundary inputs. If tracing is enabled, assert stable semantic rule names and skipped later branches.
6. Review the diff for unnecessary modules, duplicated rule logic, new dependencies, and decision logic that has leaked into adapters or orchestration.
7. State the observed benefit: shared policy consumers, duplicate rules removed, boundaries restored, useful traces, or reduced caller complexity. Distinguish these results from expectations about future bugs or change cost.

Prefer a behavior-preserving refactor. Do not change the business rule, externally visible output, error contract, or side-effect order unless the user explicitly requested that change.
