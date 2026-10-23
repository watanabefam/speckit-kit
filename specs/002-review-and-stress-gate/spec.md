# Feature Specification: Review and Stress-Test Gate

**Feature Branch**: `002-review-and-stress-gate`

**Created**: 2026-10-16

**Status**: Draft

**Input**: User description: "The kit has no independent review step. A small change passed the mechanical gate and the author's own reading; only an independent reviewer caught semantic defects. Add an independent review step to /speckit.converge, and a stress test that scales by what the change asserts — not iterating until zero findings."

## Document Status

**Status changed:** 2026-10-16 (created Draft)
**Approved by:** watanabefam (repo owner, at request) · **Authority:** maintainer of this kit
**Workflow:** full spec-driven · **Companion:** `research.md` (informative)

> This spec is authoritative for behaviour. `research.md` is informative: it carries the sources and
> rationale, and where the two disagree, this spec prevails.

Normative sections: User Scenarios & Testing, Requirements, Success Criteria. All other sections are
informative.

## Normative Status

**Normative:** User Scenarios & Testing, Requirements, Success Criteria. Everything else in this
document is informative.

### Which document wins

This spec is authoritative for behaviour. `research.md` is informative: it carries the sources and
rationale, and where the two disagree, this spec prevails.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Independent review before completion (Priority: P1)

An agent finishing a feature has the work reviewed by a context that did not produce it, and acts on
evidence-bearing findings, so semantic defects (a claim that is not true, a rule that guards the
wrong thing) are caught before "done" is reported.

**Why this priority**: This is the whole motivation. The escape that started this feature was
semantic and invisible to the mechanical gate.

**Independent Test**: Give a change containing a planted semantic defect to the converge step; a
fresh-context review surfaces it with `file:line` evidence. A review that merely re-reads the
author's own work does not.

**Acceptance Scenarios**:

1. **Given** a completed change, **When** converge runs, **Then** the review is performed in a
   context that did not produce the change.
2. **Given** a review returns a finding, **When** it is recorded, **Then** it carries `file:line` or
   a reproducing command, or it is dismissed with a recorded reason.
3. **Given** review findings remain, **When** the loop is evaluated for termination, **Then** it
   stops when no unresolved finding is HIGH or above, and does not exceed three passes.

### User Story 2 - Stress the properties the change asserts (Priority: P1)

An agent finishing a change that asserts a behavioural property (a gate, hook, validator, guard, or
invariant) runs a stress test that sends the negative case first, so the assertion is shown to be
load-bearing rather than decorative.

**Why this priority**: Joint P1. Review reads the change; only a stress test shows the assertion
actually fails when it should — the kit's own worst regressions passed review and keyword checks.

**Independent Test**: Remove the guarded thing from a gated artifact; the gate SHALL report FAIL. A
gate that only greps for a marker passes and is decoration.

**Acceptance Scenarios**:

1. **Given** a change that asserts a behavioural property, **When** converge runs, **Then** a stress
   test exercises the input the change SHALL reject and confirms rejection.
2. **Given** a stress test finds an input that fails or bypasses the change, **When** the change
   ships, **Then** that input is retained as a permanent regression fixture.
3. **Given** a prose-only change with no falsifiable oracle, **When** it is reviewed, **Then** no
   stress test is required and the reasoning is probed for loopholes instead.

### Edge Cases

- What happens when the reviewer hallucinates a finding (a false positive)? — It carries no
  reproducible evidence and is dismissed with a recorded reason; it is not counted. (Observed in the
  motivating audit: a reviewer asserted a file was missing that existed one directory away.)
- What if review and author share a model/context? — That defeats the separation; the rule requires
  a fresh context, ideally a different model (`research.md` [S1][3][5]).
- What if the reviewer never goes quiet? — Termination is severity-based, not silence-based; because
  a critic asked to find problems will invent them, "zero findings" is not the stop signal
  (`research.md` [S2]).
- What about non-deterministic behaviour? — Repeat and report the spread, not a single pass/fail.

## Requirements *(mandatory)*

All functional requirements are in EARS form. Pattern labels in brackets are informative.

### Functional Requirements

- **FR-001** [ubiquitous]: THE SYSTEM SHALL require, in the converge step, that a change be reviewed
  by a context that did not produce it before completion is reported.
- **FR-002** [event-driven]: WHEN a review finding is recorded, THE SYSTEM SHALL require it to carry
  evidence (`file:line` or a command that reproduces it).
- **FR-003** [state-driven]: WHILE review findings remain unresolved, THE SYSTEM SHALL terminate the
  review only when no unresolved finding is HIGH or above, and THE SYSTEM SHALL cap the review at
  three passes.
- **FR-004** [event-driven]: WHEN a change asserts a behavioural property (a hook, gate, validator,
  guard, or invariant), THE SYSTEM SHALL require a stress test that exercises the negative case
  first and confirms the change rejects it.
- **FR-005** [event-driven]: WHEN a stress test identifies an input that fails or bypasses the
  change, THE SYSTEM SHALL require it to be retained as a permanent regression fixture.
- **FR-006** [unwanted-behaviour]: IF a review finding carries no evidence, THEN THE SYSTEM SHALL
  require it to be dismissed with a recorded reason rather than acted on or counted.
- **FR-007** [unwanted-behaviour]: IF a change is prose with no falsifiable oracle, THEN THE SYSTEM
  SHALL NOT require a stress test, and SHALL require the change's reasoning to be probed for
  loopholes instead.
- **FR-008** [ubiquitous]: THE SYSTEM SHALL deliver the review and stress-test rules as a command
  prepend (`strategy: "prepend"`) that functions without any agent skill being loaded.
- **FR-009** [state-driven]: WHILE the existing evidence-based completion rule is in force, THE
  SYSTEM SHALL keep the review and stress-test rules consistent with it — no contradiction and no
  duplication.
- **FR-010** [event-driven]: WHEN the kit self-gate runs, THE SYSTEM SHALL assert the converge
  command carries the review rule and its bound, and that the materialised command carries them too.

### Key Entities

- **Review finding**: A claimed defect in a change, with severity, evidence (`file:line` or
  reproducing command), and a disposition (fixed, or dismissed-with-reason).
- **Stress test**: An adversarial check that sends the input a change asserts it will reject, and
  reports observed behaviour as evidence.
- **Regression fixture**: A stress-test case retained permanently beside the artifact once it has
  failed or bypassed the change.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A fresh-context review of a change with a planted semantic defect surfaces it with
  `file:line` evidence (1 of 1 planted defects found in the acceptance trial).
- **SC-002**: Removing the review rule's evidence requirement from the converge prepend makes the
  kit self-gate FAIL (the assertion is load-bearing, demonstrated by a negative test).
- **SC-003**: A freshly-installed repo's materialised `.opencode/commands/speckit.converge.md`
  contains the review rule and its severity bound (checked by the end-to-end gate).
- **SC-004**: The stop condition is severity-based: a run with only LOW findings and an unresolved
  HIGH finding terminates only after the HIGH one is fixed or dismissed; a run with only LOW
  findings and no HIGH stops without another pass.
- **SC-005**: Kit self-gate passes on Linux and macOS with the new prepend composed; re-run is
  idempotent; version and changelog stay consistent.

## Assumptions

- The existing converge prepend is the delivery vehicle; no core Spec Kit command is forked or
  replaced (`strategy: "prepend"`).
- "Fresh context" is available to the installed repo (a subagent or a separate session). Where it is
  not, the rule degrades to "state explicitly that no independent review was possible" — not to a
  self-review that claims independence.
- The stop condition is severity (HIGH or above), not "zero findings", grounded in the self-critique
  paradox (`research.md` [S2]).
- Extending the kit self-gate is in scope, because the kit asserts command contributions and a rule
  it cares about must be asserted (its own stated practice).
- The unratified `.specify/memory/constitution.md` is a pre-existing governance gap, not created or
  resolved by this feature; recorded here rather than silently ignored.

## Requirements Syntax

Not applicable — this feature's requirements are written in prose, not EARS. The EARS rules arrived
with spec 001 for requirements that must be machine-checkable; converting 002's existing FR-001…FR-010
to EARS would rewrite approved requirement text to satisfy a template, which is the failure mode this
section exists to prevent. The shape this section asks for is present in 001.

## Carried Forward

What this artifact inherits from the work before it.

### Confirmed Decisions

- The review capability is delivered as a **prepend** to an existing command, not a forked core
  command (`strategy: "prepend"`), so upstream Spec Kit can still be merged.
- The stopping condition is severity (HIGH or above), not "zero findings".

### Constraints

- The rule is advisory in mechanism — a hook cannot enforce judgement — so it is asserted in the
  gate by its presence and its bound, not by behaviour under pressure.
- No new dependency: `scripts/self-gate.sh` is extended rather than a second harness added.

### Assumptions

Five assumptions are carried, all stated in `## Assumptions` above; the load-bearing one is that a
fresh context is available, and the spec already says what happens when it is not (the rule degrades
to stating that no independent review was possible, rather than to a self-review claiming
independence).

### Risks

- **A rule that reads as satisfied by any reviewer sentence.** Mitigated by requiring a file:line
  citation or a dismissal with a reason, and by the negative test in `## Validation Plan`.
- **Review as a rubber stamp.** Mitigated by the severity stop and the ≤3 pass bound.

### Open Questions

None open. The two that were open — whether review could be hook-enforced, and whether the loop could
be unbounded — were decided against, and both decisions are recorded in `## Non-Goals`.

## Problem / Opportunity

The kit verifies *artifact consistency and declared-boundary integrity*; it does not review the
produced change. Every worst regression in the kit's history passed review and a keyword check and
failed only under an adversarial run (`CHANGELOG.md`: the no-verify guard bypass class; the inverted
drift checker; the eval runner that evaluated the wrong directory). The missing capability is
independent, adversarial verification.

## Goals

- Catch semantic defects the mechanical gate cannot see, before completion is reported.
- Make "the assertion is load-bearing" an explicit, evidenced claim, not an assumption.

## Non-Goals

- Enforcing review via a hook — review is judgement and cannot be mechanised; it is an advisory
  command rule, stated as such.
- A mandatory, unbounded review loop. The loop is bounded and severity-gated.
- Replacing the mechanical gate. Review and gate are complementary.

## Dependencies and External Contracts

- The preset `prepend` mechanism (`preset/preset.yml`).
- The kit self-gate (`scripts/self-gate.sh`), whose §3b/§5 assertions are extended.

## MVP Scope

US1 + US2 delivered as two rule sections in `preset/commands/speckit.converge.prepend.md`, with
self-gate assertions and the `SKILL.md` "command carries" row updated.

## Future Work (parking lot)

| # | Idea | Noticed during | Why deferred | Revisit when |
| --- | --- | --- | --- | --- |
| 1 | Ratify `.specify/memory/constitution.md` | Specify | Not this feature; governance gap predates it | Before the next feature is specified |
| 2 | An eval-based (RED-GREEN) test of whether the review rule changes agent behaviour under pressure | Research | Belongs at kit-release cadence, like `evals/`; expensive per-change | When a review-rule regression is suspected |
| 3 | A distinct "different model" option documented for review, versus "different context" | Research | Depends on host capabilities; the rule says "ideally" | If hosts expose model selection to subagents |

### Parking lot vs Non-Goals

A **Non-Goal** is a thing this feature deliberately will not do (hook-enforced review, an unbounded
loop). A **parked idea** is something noticed while building it that may deserve its own feature
later — the three rows in the table above. Nothing moves from the parking lot into scope without a
spec of its own; the constitution ratification in row 1 is the clearest case: it is a governance gap
that predates this feature and is recorded, not resolved.

## Validation Plan

- **Automated tests** — `scripts/self-gate.sh` (full, incl. e2e): asserts the converge rule and its
  bound in the source and materialised command.
- **Manual checks** — a negative test: remove the rule's evidence line → gate FAIL; restore → PASS.
- **Security / privacy checks** — not applicable (no data, no network).
- **Evidence required for approval** — self-gate PASS; `speckit-check` current; the negative test's
  before/after output.

## Requirement Traceability

| Requirement | User Story | Acceptance Criteria | Planned Design Area | Task |
| --- | --- | --- | --- | --- |
| FR-001 | US1 | Given/Then: review by a non-author context | converge prepend | T004 |
| FR-002 | US1 | Given/Then: evidence or dismiss-with-reason | converge prepend | T004 |
| FR-003 | US1 | Given/Then: severity stop; ≤3 passes | converge prepend | T004 |
| FR-004 | US2 | Given/Then: negative case first | converge prepend | T005 |
| FR-005 | US2 | Given/Then: failing case → regression fixture | converge prepend | T005 |
| FR-006 | US1 | Given/Then: no evidence → dismissed, not counted | converge prepend | T004 |
| FR-007 | US2 | Given/Then: prose has no oracle | converge prepend | T005 |
| FR-008 | US1/US2 | Given/Then: works skill-unloaded | prepend mechanism | T004, T005 |
| FR-009 | US1 | Given/Then: no contradiction with evidence rule | converge prepend | T004 |
| FR-010 | US1/US2 | Given/Then: gate asserts rule + bound | self-gate, E2E | T006, T007 |
