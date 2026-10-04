---

<!--
  Appended by the spec-driven-development preset (strategy: append).
  The core sections above (Summary, Technical Context, Constitution Check, Project
  Structure, Complexity Tracking) remain authoritative. These sections carry the
  design-phase reasoning the core template does not ask for.
-->

## Carried Forward

### Confirmed Decisions

- [Settled in the spec or by the user]

### Constraints

- [Technical or operational constraint]

### Assumptions

- [Assumption this design depends on]

### Risks

- [Risk introduced or inherited]

### Open Questions

- [Unresolved item that affects the design]

## Scope Confirmation

### In Scope

- [What this change delivers]

### Out of Scope

- [What it deliberately does not touch]

### Requirements Affected

- [FR-00x addressed / deliberately not addressed]

## Repository Findings

Filled in from inspecting the code, **before** proposing changes. A plan written without
this section is not trustworthy.

**Sweep before you list.** A new block, field, entity, or enum member almost always appears
in more than one place. Search the repository for every occurrence of the concept — not just
the obvious component. Check at least:

- the schema or definition
- **any layer that enumerates the same set** — a validation schema (Zod, JSON Schema), a type
  union, a literal enum, a registry, a route table
- the component / handler
- the renderer or dispatch site
- existing tests and fixtures

A file that re-lists the same set (for example a `_template` enum mirroring the list of block
types) MUST be updated too, or the build fails on the new value — and it will fail *late*,
at implementation or typecheck. Enumerate those files here explicitly.

### Relevant Components

- [Files, modules, services]

### Existing Behavior

- [What happens today]

### Existing Tests

- [What already covers this area, and what does not]

### Project Conventions

- [Patterns this change must follow]

### Constraints Discovered

- [Constraint found in the code that the spec did not mention]

## Architecture Overview

[The shape of the solution, in a paragraph or a small diagram. Prefer existing patterns.]

## Major Components

- [Component and its responsibility]

## Data Flow

[How data moves through the change: input, transformation, storage, output.]

## Interfaces and Contracts

- [Function signature, API route, schema, event — anything a caller depends on]

## Dependencies

- [New dependency, and why it is justified. Prefer none.]

## Error Handling

[What can fail, how it surfaces, and what the user sees.]

## Security and Privacy

[Only if relevant. Otherwise state "Not applicable" and why.]

## Performance and Reliability

[Only if relevant. Otherwise state "Not applicable" and why. Note any known limits.]

## Validation Strategy

[How the design will be verified once implemented — tests, checks, and manual steps.]

## Correctness Properties

A **correctness property** is a universally-quantified statement about how the system must
behave — an invariant or contract that holds regardless of the specific data. Example-based tests
check the examples you thought of; a property is checked against many generated inputs, so it
finds the cases you did not.

Not every requirement maps cleanly to a property. Map what you can, and **opt out explicitly** for
the rest — a vacuous property is worse than a recorded opt-out.

| Property ID | Requirement | `for any …` statement | Non-mapped reason | Notes |
| --- | --- | --- | --- | --- |
| P-001 | FR-001 | `for any <domain>, <property that must hold>` | — | |
| — | FR-002 | — | qualitative / no decidable oracle | |

### Rules

- **Start every property with `for any`.** A statement naming specific values is an example, not
  a property. `for any request carrying an expired token, the response is 401` is a property;
  `request #5 returns 401` is a test case.
- **One requirement may yield several properties** (1:many) — split by input domain, not by
  convenience. Two properties about one requirement are fine; one property pretending to cover
  two is not.
- **The statement needs a decidable oracle.** If you cannot say how a run would be judged pass or
  fail, it is not a property. Requirements that are qualitative, or that depend on
  non-deterministic or external behaviour with no observable contract, opt out.
- **Opt-out rule:** a non-mapped requirement gets **no P-ID**, and its reason goes in one line in
  the `Non-mapped reason` column. Never both a property and an opt-out, and never neither — every
  requirement is either mapped or explicitly opted out. A requirement that is neither is a gap in
  this plan.

### Framework decision

Property-based testing needs a framework. **Detect one; never assume one.** Record the decision
here so `tasks.md` follows it verbatim instead of guessing.

- **Detected** — framework name, or `none found`
- **Version / where found** — the dependency entry, test config, or existing property test
- **Signal** — what in the repository indicated it
- **Decision** — `adopt` the detected framework, or `fallback` to example-based tests

Per-ecosystem signals to look for — a *detection checklist*, not a default. Do not add a
dependency merely because it appears here.

| Ecosystem | Look for |
| --- | --- |
| Python | `hypothesis` in dependencies, or existing `@given` tests |
| JavaScript / TypeScript | `fast-check` (`fc.assert` / `fc.property`) |
| JVM | `jqwik`, `junit-quickcheck`, `scalacheck` |
| Rust | `proptest`, `quickcheck` |
| Haskell | `QuickCheck` |
| Erlang / Elixir | `PropEr`, `StreamData` |

If **no framework is found**, decide explicitly between adopting one and falling back to
example-based tests, and record which. `tasks.md` follows this decision verbatim.

### Traceability

Each property links a requirement to the test that checks it: `FR-xxx → P-xxx → T0xx`. A property
with no task is unbuilt; a property test with no requirement is scope creep — the same symmetry
that applies between requirements and tasks.

### Independence

This is template text, so it applies when the command runs — whether or not the
`spec-driven-development` skill loaded. Under the `lean` preset, which replaces the commands and
bypasses templates entirely, it does not apply: choose `lean` or this preset, not both.

## Alternatives Considered

| Option | Advantages | Disadvantages | Decision |
| --- | --- | --- | --- |
| [Alternative] | | | Rejected / Selected |

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |

## Requirement-to-Design Traceability

Every design decision should serve a requirement. Every requirement should have a design.

| Requirement | Design Decision | Reason |
| --- | --- | --- |
| FR-001 | | |

## Implementation Boundaries

### Must Change

- [Required for correctness]

### Must Not Change

- [Explicitly out of bounds — behaviour, contract, or file that must survive untouched]

## What Changed / What Remains Open

- **Changed from the spec:** —
- **Still open:** —
- **Needs approval:** —
