# Implementation Plan: Review and Stress-Test Gate

**Feature Branch**: `002-review-and-stress-gate` · **Date**: 2026-10-16 · **Spec**: `spec.md`

## Summary

Add two rule sections to `preset/commands/speckit.converge.prepend.md` — *review by a context that
did not do the work*, and *stress the properties the change asserts* — plus the gate assertions that
make them load-bearing. No new pipeline step, no new artifact type: the review folds into converge,
which already owns close-out.

## Technical Context

- Delivery: preset command prepend (`strategy: "prepend"`), composed after frontmatter onto
  `.opencode/commands/speckit.converge.md`. Same mechanism as the existing converge/specify rules.
- Verification: `scripts/self-gate.sh` (§3b source markers, §5 materialised-command check) and
  `bin/speckit-check` (drift).
- No code, no dependencies, no schema. Bash 3.2-safe gate edits only.

## Design Decisions

- **A rule in converge, not a new step.** Converge already owns "Completion requires evidence" and
  boundary checks; review is the missing sibling. Alternatives — a separate `/speckit.review`, or a
  hook — were rejected: a separate step fragments close-out, and a hook cannot judge.
- **Bounded and severity-gated, not "until zero findings".** Grounded in the self-critique paradox
  (`research.md` [S2]) and the kit's own `specify` precedent (max 3 iterations). A critic told to find
  problems will invent them; the stop signal is severity, not silence.
- **Evidence-bearing findings.** Mirrors AMTSO's "observable evidence over asserted outcomes"
  (`research.md` [S6]); a finding without `file:line`/reproducing command is dismissed with a reason.
- **Stress test triggered by assertion, not size.** Read from red-team practice — verify at the
  action boundary, keep every confirmed bypass as a regression case (`research.md` [S3]–[S6]).
- **Advisory, and stated as advisory.** Like every command rule, this guarantees the rule is read,
  not obeyed. The spec and the rule say so.

## Correctness Properties

Framework decision: **none adopted.** This is a prompt-text change verified by the kit's existing
shell gate; no property-based testing framework is added (`research.md`). Properties below are
checked by deterministic shell assertions (runtime-assert) or by review.

| Property ID | Requirement | Property (for any …) | Check method | Scope |
| --- | --- | --- | --- | --- |
| P-001 | FR-010, SC-002 | for any edit that removes the converge review's evidence bullet (`Every finding carries evidence`) or its severity bound (`Stop when no UNRESOLVED`), the self-gate reports FAIL | runtime-assert | system |
| P-002 | FR-008, SC-003 | for any fresh install, the materialised `.opencode/commands/speckit.converge.md` contains the review rule and its severity bound | runtime-assert | system |
| P-003 | FR-009 | for any converge prepend content, the review rule does not contradict or duplicate the completion-evidence rule | review-only | operation |
| P-004 | FR-006 | for any review finding missing `file:line` or a reproducing command, the rule directs dismissal-with-reason rather than action | review-only | operation |
| P-005 | FR-003, SC-004 | for any review run, termination is defined by unresolved HIGH severity, not by the reviewer's silence | review-only | operation |
| P-006 | (invariant) | for any preset version, it equals the newest `## [x.y.z]` CHANGELOG entry (pre-existing §1c) | runtime-assert | system |

**Non-mapped requirements** (opt-out, with reason): FR-001, FR-002, FR-004, FR-005, FR-007 are
statements about what the converge command must *prescribe*. They are not independently falsifiable
without executing an agent, so no property is forced; they are covered indirectly by P-001/P-002 (the
rule is present and load-bearing) and P-004/P-005 (the rule's operative sentences).

## Implementation Boundaries

- **Must Not Change**: `bin/speckit-init`, `hooks/speckit-hooks.yaml`, the four template addenda,
  `preset/commands/speckit.{specify,plan,tasks,implement}.prepend.md`. This feature touches converge
  and the gate only.
- **Must Not Change**: the existing `### Completion requires evidence` rule — the new rules add to
  it, never contradict or duplicate it (FR-009).
- No new dependency, no named external tool, no enforcement claim.

## Risks

| Risk | Mitigation |
| --- | --- |
| Rule ignored (prompt text) | Accepted and stated; the gate proves the rule is *present*, not obeyed. Review is an outer-loop aid, not a guarantee. |
| Rule bloats the converge command | Two sections, ≤8 bullets, reviewed for length; converge remains the shortest command. |
| "Zero findings" misread as the goal | Bound and severity language is explicit in the rule and asserted by FR-003/SC-004. |
| Gate assertion is keyword-only (the kit's own criticism) | §3b/§5 assert the operating sentences (evidence bullet + severity bound), not only headings, and T008 negative-tests one; substring matching is still a keyword check — recorded as residual H3 in `progress.md`. |

## Requirement Traceability

| Requirement | Design area | Task |
| --- | --- | --- |
| FR-001..FR-007, FR-009 | converge prepend | T004, T005 |
| FR-008 | prepend mechanism | T004, T005 |
| FR-010 | self-gate §3b/§5 | T006, T007 |
| SC-002 | negative test | T008 |
| SC-005 | gate + version/changelog | T006, T009 |
