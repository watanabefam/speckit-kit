---

<!--
  Appended by the spec-driven-development preset (strategy: append).
  The core sections above remain authoritative and unchanged. These sections add
  problem framing and traceability that the core template does not carry.
-->

## Requirements Syntax (EARS)

Every functional requirement is written in **EARS** (Easy Approach to Requirements Syntax). EARS
constrains free-form prose into a small set of testable shapes, so a reviewer can write an
acceptance check from the requirement text alone.

**Use `SHALL` for every required behaviour — never MUST, SHOULD, or a bare lowercase verb.**
`SHALL` is the only normative keyword here (RFC 2119 sense). Mixing in MUST, or writing "the
system validates…", leaves it ambiguous whether the behaviour is binding.

| Pattern | Keyword | Shape | Use when |
| --- | --- | --- | --- |
| Ubiquitous | *(none)* | `THE <system> SHALL <response>` | the behaviour is always active |
| Event-driven | `WHEN` | `WHEN <trigger> THE <system> SHALL <response>` | a response is required to a triggering event |
| State-driven | `WHILE` | `WHILE <state> THE <system> SHALL <response>` | the behaviour holds while a state is true |
| Optional feature | `WHERE` | `WHERE <feature is included> THE <system> SHALL <response>` | it applies only to variants that include a feature |
| Unwanted behaviour | `IF` / `THEN` | `IF <unwanted condition> THEN THE <system> SHALL <response>` | a response is required to a fault, failure, or undesired situation |

Examples:

- **Ubiquitous** — `THE <system> SHALL prevent concurrent edits to the same record.`
- **Event-driven** — `WHEN a request carries an expired token, THE <system> SHALL reject it with an authentication error.`
- **State-driven** — `WHILE a sync is in progress, THE <system> SHALL queue further writes.`
- **Optional feature** — `WHERE audit logging is enabled, THE <system> SHALL record the acting user.`
- **Unwanted behaviour** — `IF the upstream service is unavailable, THEN THE <system> SHALL retry with backoff and report a degraded status.`

**Clause order is fixed** and follows temporal logic: preconditions (`WHILE`, `WHERE`) precede
the trigger (`WHEN`), which precedes the system response. Requirements that combine keywords are
**complex** — e.g. `WHILE <state>, WHEN <trigger>, THE <system> SHALL <response>`. Use the fewest
clauses that work; if a requirement needs more than three, split it.

**Common misuse:** `WHEN` is for an event, not a state; `WHILE` is for a state, not an event;
`IF…THEN` is for unwanted behaviour and is evaluated on the second pass — do not use it for the
normal path; `WHERE` denotes a variant, not a location.

This guidance is deliberately **language-agnostic**. The property-based testing framework (if any)
is decided per project in `plan.md`. Do not hardcode a framework (e.g. Hypothesis) into a
requirement.

## Carried Forward

Summary of what this artifact inherits from the work before it. Keep it short — it is a
handoff, not a retelling.

### Confirmed Decisions

- [Decision already settled by the user or by earlier evidence]

### Constraints

- [Constraint that limits the solution space]

### Assumptions

- [Assumption being carried in; becomes a risk if it is wrong]

### Risks

- [Known risk, and how it would show up]

### Open Questions

- [Unresolved item that affects behavior, scope, architecture, or acceptance]

## Problem / Opportunity

[What problem or opportunity exists, for whom, and why does it matter now? If this is not a
real problem, the feature should not be built.]

## Goals

- [Outcome this feature is meant to produce]

## Non-Goals

- [Explicitly **not** being solved here. Prevents silent scope expansion.]

## Dependencies and External Contracts

- [Service, API, data source, schema, or external contract this feature depends on, and what
  happens if it changes]

## MVP Scope

[The smallest slice that delivers the value of the highest-priority user story. Everything
else is Future Work.]

## Future Work

[Deliberately deferred. Not part of this feature's acceptance criteria. Must not be
implemented without explicit approval.]

## Validation Plan

How this feature will be proven, before implementation starts.

- **Automated tests** —
- **Manual checks** —
- **Data or migration checks** —
- **Security / privacy checks** —
- **Performance checks** —
- **Evidence required for approval** —

## Requirement Traceability

Fill in as the work progresses. A requirement with no task is unbuilt; a task with no
requirement is scope creep.

| Requirement | User Story | Acceptance Criteria | Planned Design Area | Task |
| --- | --- | --- | --- | --- |
| FR-001 | US1 | Given / When / Then | | |
