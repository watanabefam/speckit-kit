# Data Model: EARS Executable Specifications

**Feature**: `001-ears-executable-specs` | **Date**: 2026-10-04

This feature adds template text, not runtime state. Entities below are the conceptual objects the templates define, trace, and verify. No database, no migrations.

## EARS Requirement

- **What**: One functional requirement written in a single EARS pattern (ubiquitous, event-driven, state-driven, unwanted-behaviour, optional-feature).
- **Fields**: `id` (stable, e.g., `FR-001`); `pattern` (one of the five); `trigger/state/condition` (the WHEN/WHILE/IF/WHERE clause); `actor` (named system before SHALL); `response` (observable behaviour after SHALL); `acceptance` (Given/When/Then scenario(s) or Independent Test pointer).
- **Validation**: Exactly one `SHALL` (uppercase, RFC 2119); exactly one named actor; WHEN holds a point event (≥3-word trigger), WHILE a durable state, IF an unwanted condition, WHERE an optional variant; response observable (number/unit/tolerance or named message/state, no stack prescription); ≤2 EARS keywords or split/reference a table.
- **State transitions**: Draft → checklist-reviewed (Tier-1 structural pass) → accepted. Misuse returns to Draft with the probe that fired.
- **Relationships**: Parent of 0..many Correctness Properties (0 only with an opt-out reason); source of 1..many acceptance checks (SC-001).

## Correctness Property

- **What**: A universally-quantified statement `for any <domain>, <property holds>` mapping 1:1 or 1:many to a testable EARS requirement.
- **Fields**: `property_id` (`P-001…`, minted only for mapped rows); `requirement_id` (traces to `FR-00x`); `for_any` (the quantified statement); `non_mapped_reason` (one line, filled ONLY when no property maps); `design_notes` (domain generators, oracles, invariants referenced).
- **Validation**: Either `for_any` present (starts with `for any`, names a generatable domain + decidable postcondition) XOR `non_mapped_reason` present — never both, never neither. Non-mappable kinds: qualitative/UX judgement, existential/single-example, taste/aesthetic, unquantified vagueness.
- **State transitions**: Proposed → reviewed (quantifier + oracle checkable) → accepted; or Proposed → opted-out (reason recorded) → accepted as accounted-for.
- **Relationships**: Child of exactly one EARS Requirement; parent of exactly one Property-Based Test Task (mapped rows only).

## Property-Based Test Task

- **What**: One task-item verifying a single correctness property across generated inputs.
- **Fields**: `task_id` (`T00x`); `property_id` (`P-00x`); `requirement_id` (`FR-00x`); `framework` (the plan-recorded per-project framework name, or the recorded fallback); `scope_boundaries`; `verification` (command/check proving it passes); `completion_conditions`.
- **Validation**: Every mapped property has ≥1 task; every task traces to exactly one property + requirement; framework field names the plan's recorded decision (never a kit default); co-located with the behaviour's story phase, not a trailing phase.
- **State transitions**: Planned → property test written (fails first where applicable) → passes → requirement acceptance satisfied.
- **Relationships**: Child of one Correctness Property; execution follows the Framework Decision.

## PBT Framework Reference (decision record, not a registry)

- **What**: The per-project framework choice recorded at plan time.
- **Fields**: `detected_framework` (name + version, or "none"); `signal` (manifest + grep that found it, e.g., `package.json devDeps: fast-check`); `decision` (`use-detected` | `adopt-<name>` | `example-based-fallback-with-reason`).
- **Validation**: Kit text never supplies a default; the plan row is always filled; tasks reference this row's decision verbatim.
- **Relationships**: Referenced by all Property-Based Test Tasks in the feature.

## Traceability chain

```text
FR-00x (EARS Requirement)
  └─ P-00x (Correctness Property) — or explicit opt-out reason
       └─ T00x (Property-Based Test Task, names Framework Reference decision)
```

Coverage rule: a requirement with no property row is unbuilt; a property with no test task is unverified; a test task with no requirement/property is scope creep. SC-002 audits mapped XOR opted-out = 100%.
