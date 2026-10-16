# Tasks: Review and Stress-Test Gate

**Feature**: `002-review-and-stress-gate` · **Spec**: `spec.md` · **Plan**: `plan.md`
**Ordering**: Foundational first, then US1 (review), then US2 (stress test), then verification.

## Phase 1 — Foundational

- [x] T001 Record the governance gap: note in `spec.md` Assumptions that `.specify/memory/constitution.md` is unratified (per spec Assumptions) — **FR: exempt (governance; no FR maps to recording a gap)**
- [x] T002 Confirm the converge command is the correct delivery point and that the existing `### Completion requires evidence` rule is not duplicated — **FR-009**
- [x] T003 Read `preset/commands/speckit.converge.prepend.md` and `preset/commands/speckit.specify.prepend.md` to match section style and the existing "max 3 iterations" precedent — **FR-003**

## Phase 2 — US1: Independent review (P1)

- [x] T004 [US1] Add the `### Review by a context that did not do the work` section to `preset/commands/speckit.converge.prepend.md`: fresh-context requirement, evidence-or-dismiss, severity-based stop, ≤3 passes, prefer-deterministic-check — **FR: FR-001, FR-002, FR-003, FR-006, FR-009**
- [x] T005 [US2] Add the `### Stress the properties the change asserts` section: trigger by assertion not size, negative case first, failing case → regression fixture, evidence-not-verdict, non-determinism handling — **FR: FR-004, FR-005, FR-007, FR-008**

## Phase 3 — Gate wiring (makes the rules load-bearing)

- [x] T006 [P] Extend `scripts/self-gate.sh` §3b: add the converge review markers (rule heading + `did not do the work` + the bound) to the expected set — **FR: FR-010**
- [x] T007 [P] Extend `scripts/self-gate.sh` §5 E2E: `check_cmd converge` asserts the new rule reaches the materialised command — **FR: FR-010**
- [x] T008 [P] Add the negative test to the acceptance evidence: remove the evidence line from the converge prepend → gate FAIL; restore → PASS — **SC-002**

## Phase 4 — Release plumbing

- [x] T009 Bump `preset/preset.yml` version and add the `CHANGELOG.md` entry (newest entry == preset version) — **SC-005**
- [x] T010 Update the `SKILL.md` "the command carries" row for `/speckit.converge` (review + stress rules) — **FR-008**

## Phase 5 — Verify

- [x] T011 `bin/speckit-init .` to re-apply; confirm the materialised converge command carries both sections — **FR-008, SC-003**
- [x] T012 [P] `scripts/self-gate.sh` (full, incl. e2e) → PASS; `bin/speckit-check .` → current — **SC-002, SC-003, SC-005**
- [x] T013 [P] Dogfood: run converge on this change — dispatch an independent reviewer and run the negative stress test; record findings and dispositions — **FR-001, FR-004**
- [x] T014 Write `specs/002-review-and-stress-gate/progress.md` ledger and close it — **FR: exempt (handoff; no FR maps to ledger close)**

## Requirement Coverage

| Requirement | Tasks |
| --- | --- |
| FR-001 | T004, T013 |
| FR-002 | T004 |
| FR-003 | T004 |
| FR-004 | T005, T013 |
| FR-005 | T005 |
| FR-006 | T004 |
| FR-007 | T005 |
| FR-008 | T005, T010, T011 |
| FR-009 | T002, T004 |
| FR-010 | T006, T007 |
| SC-001 | T013 |
| SC-002 | T008, T012 |
| SC-003 | T011, T012 |
| SC-004 | T013 |
| SC-005 | T009, T012 |

| Property | Task |
| --- | --- |
| P-001 | T006, T008 |
| P-002 | T007, T011 |
| P-003 | T002, T004 |
| P-004 | T004 |
| P-005 | T004 |
| P-006 | T009 |
