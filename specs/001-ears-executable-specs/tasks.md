---
description: "Task list template for feature implementation"
---

# Tasks: EARS Executable Specifications

**Input**: Design documents from `/specs/001-ears-executable-specs/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/
**Tests**: Verification is via `scripts/self-gate.sh` content assertions + scratch-repo trials in `quickstart.md` (this repo has no `tests/` dir; gate + trials are the test suite). FR-007 requires one property-based-test-task rule per correctness property in the *template*; for *this feature's own* verification each P-ID below has a corresponding gate/trial task naming the decision.
**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- Single project: template text in `preset/templates/`, gate in `scripts/`, installed mirror in `.specify/presets/spec-driven-development/`, docs at repo root.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Baseline the repo so later edits are verifiable and the mirror-set is known.

- [ ] T001 Run baseline gate `scripts/self-gate.sh --no-e2e` in `scripts/self-gate.sh` and record PASS/FAIL before any edit
- [ ] T002 [P] Inventory mirror-set files in `preset/preset.yml` (4 targets, quoted versions, append-only)
- [ ] T003 [P] Confirm specify CLI + bash matrix in `.github/workflows/self-gate.yml` (Linux bash 5 / macOS bash 3.2)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Shared wording conventions all three addenda depend on — MUST complete before any user-story work.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete.

- [ ] T004 Agree SHALL-only RFC 2119 boilerplate line shared by all addenda in `preset/templates/spec-addendum.md`
- [ ] T005 Agree P-ID + requirement → property → test linkage + opt-out convention in `preset/templates/plan-addendum.md`
- [ ] T006 Agree no-hardcode guard + allowlisted negative-example line in `scripts/self-gate.sh`
- [ ] T007 Decide constitution touch vs no-change (default: unchanged) in `preset/templates/constitution-addendum.md`

**Checkpoint**: Foundation ready — conventions agreed; user story implementation can now begin.

---

## Phase 3: User Story 1 — Write requirements in EARS form (Priority: P1) 🎯 MVP

**Goal**: Spec template carries EARS authoring guidance for all five patterns so every functional requirement is testable and unambiguous (FR-001..FR-005).

**Independent Test**: Generate a spec from the composed template (`specify preset resolve spec-template`) and inspect its Functional Requirements section: every requirement matches one EARS pattern and a reviewer can write an acceptance check from the text alone (SC-001: 5 consecutive requirements convertible, zero author questions).

### Implementation for User Story 1

- [ ] T008 [US1] Add five-pattern EARS table (Pattern|Keyword|Shape|Use-when|Example) in `preset/templates/spec-addendum.md`
- [ ] T009 [US1] Add SHALL-only RFC 2119 boilerplate + lowercase-verb ban in `preset/templates/spec-addendum.md`
- [ ] T010 [US1] Add order/complexity footnote (Where→While→When→If/Then→SHALL, WHILE+WHEN example, >3-escape) in `preset/templates/spec-addendum.md`
- [ ] T011 [US1] Add misuse pointer (WHEN event / WHILE state / IF faults-second-pass / WHERE variant-not-location, Tier-1 vs Tier-2) in `preset/templates/spec-addendum.md`
- [ ] T012 [US1] Add language-agnostic guard sentence (no framework default, negative-example only) in `preset/templates/spec-addendum.md`
- [ ] T013 [US1] Add EARS-row gate assertions (spec contract probes) in `scripts/self-gate.sh`

**Checkpoint**: At this point, User Story 1 should be fully functional and testable independently (spec resolve shows EARS table; gate probes pass).

---

## Phase 4: User Story 2 — Map requirements to correctness properties in the plan (Priority: P1)

**Goal**: Plan template gains a Correctness Properties section mapping each testable requirement to a `for any …` property, with explicit opt-out and a framework-decision record (FR-006, FR-009, FR-012-record).

**Independent Test**: Generate a plan from the composed template for a trial spec with ≥8 requirements incl. ≥2 non-mappable ones; verify each testable requirement has a `for any …` property row and each non-mapped requirement carries an explicit opt-out reason (SC-002: 100% mapped XOR opted-out).

### Implementation for User Story 2

- [ ] T014 [P] [US2] Add Correctness Properties table skeleton (Property ID|Requirement|for-any|Non-mapped reason|notes) in `preset/templates/plan-addendum.md`
- [ ] T015 [US2] Add for-any syntax + 1:many + decidable-oracle guidance in `preset/templates/plan-addendum.md`
- [ ] T016 [US2] Add opt-out rule (no P-ID, one-line reason, never both/neither) in `preset/templates/plan-addendum.md`
- [ ] T017 [US2] Add framework-decision record fields (detected/version/signal/adopt-vs-fallback) in `preset/templates/plan-addendum.md`
- [ ] T018 [P] [US2] Add per-ecosystem PBT signal table as detection instruction (never defaults) in `preset/templates/plan-addendum.md`
- [ ] T019 [US2] Add traceability note (requirement→property→test linkage, defect definitions) in `preset/templates/plan-addendum.md`
- [ ] T020 [US2] Add skill-independence + lean-limitation note in `preset/templates/plan-addendum.md`
- [ ] T021 [US2] Add plan-section gate assertions (Correctness Properties + for-any + opt-out + framework-decision) in `scripts/self-gate.sh`

**Checkpoint**: At this point, User Stories 1 AND 2 should both work independently (spec EARS + plan properties compose; SC-002 audit passes on a trial spec).

---

## Phase 5: User Story 3 — Get property-based test tasks naming the project framework (Priority: P2)

**Goal**: Tasks template emits one property-based test task per correctness property, naming the plan-recorded framework (never hardcoded), co-located with its story (FR-007, FR-012-follow).

**Independent Test**: Generate tasks from a plan containing correctness properties; verify each property has a PBT task tracing FR-ID + P-ID and naming the project's framework/decision, with zero hardcoded framework names in kit-owned text (SC-003).

### Implementation for User Story 3

- [ ] T022 [US3] Add one-PBT-task-per-property rule (FR-ID + P-ID tracing + plan-recorded framework naming) in `preset/templates/tasks-addendum.md`
- [ ] T023 [US3] Add co-location rule (property tests sit with story behaviour, no trailing phase) in `preset/templates/tasks-addendum.md`
- [ ] T024 [US3] Add fallback-following rule (adopt-vs-fallback followed verbatim) in `preset/templates/tasks-addendum.md`
- [ ] T025 [US3] Add T003-style worked PBT example (Objective/FR/P-ID/framework/Verification/Completion) in `preset/templates/tasks-addendum.md`
- [ ] T026 [US3] Extend Requirement Coverage note to P-IDs (every P-ID has a task; every PBT task traces a P-ID) in `preset/templates/tasks-addendum.md`
- [ ] T027 [US3] Add tasks-rule gate assertions (per-property rule + P-ID + framework + no-hardcode negative test) in `scripts/self-gate.sh`

**Checkpoint**: All user stories should now be independently functional (spec + plan + tasks resolve with new sections; SC-003 grep empty).

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Mirror-set sync, docs, version, and end-to-end verification (SC-001..SC-005).

- [ ] T028 Re-sync installed mirror copy in `.specify/presets/spec-driven-development/templates/spec-addendum.md` (plus plan/tasks/constitution addenda + `preset.yml`)
- [ ] T029 [P] Update layout/counts/limitation notes in `README.md`
- [ ] T030 [P] Fix D1 ×3→×4 + gate/doc mirror notes in `BUILD_PLAN.md`
- [ ] T031 Bump preset version (patch/minor, quoted strings, 4-target append-only intact) in `preset/preset.yml`
- [ ] T032 Record EARS self-demonstration audit (this spec's FR pattern labels + checklist Tier-1/Tier-2 note) in `specs/001-ears-executable-specs/checklists/requirements.md`
- [ ] T033 Run full gate + E2E composition + marker-once + 3-run fixed point (SC-005) via `scripts/self-gate.sh`
- [ ] T034 Run skill-unloaded scratch-repo trial per Scenario 2 (SC-004 + SC-001) in `specs/001-ears-executable-specs/quickstart.md`
- [ ] T035 Run SC-002 coverage audit + SC-003 zero-hardcode grep (Scenario 4 guardrails) in `specs/001-ears-executable-specs/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately.
- **Foundational (Phase 2)**: Depends on Setup — BLOCKS all user stories (shared SHALL / P-ID / no-hardcode wording).
- **User Stories (Phase 3+)**: All depend on Foundational completion.
  - US1 (P1) + US2 (P1) are joint MVP — implement in order US1 → US2 (properties reference EARS shapes), or in parallel once T004–T007 agreed.
  - US3 (P2) depends on US2's table/decision shape (task rules reference P-ID + framework-decision fields); can start after T014–T017 drafted.
- **Polish (Phase 6)**: Depends on all desired user stories being complete (mirror-sync + docs + gate need final addenda text).

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational — no dependencies on other stories.
- **User Story 2 (P1)**: Can start after Foundational — references US1's pattern names but independently testable via its own table.
- **User Story 3 (P2)**: Needs US2's P-ID + framework-decision shape; otherwise independently testable.

### Within Each User Story

- Template text before gate assertions (T008–T012 → T013; T014–T020 → T021; T022–T026 → T027).
- Tables/skeletons before rules/examples that reference them.
- Story complete (template + its probes) before moving to next priority.

### Parallel Opportunities

- T002 + T003 (different files: `preset/preset.yml` vs `.github/workflows/self-gate.yml`).
- T014 + T018 (same file but disjoint sections; merge carefully — or sequence to avoid conflicts).
- T029 + T030 (different files: `README.md` vs `BUILD_PLAN.md`).
- Once Foundational completes, US1 and US2 template edits can proceed in parallel (different files) by different implementers; US3 follows once P-ID shape is stable.

---

## Parallel Example: User Story 2

```bash
# Launch skeleton + signal table together (disjoint sections of plan-addendum.md):
Task: "Add Correctness Properties table skeleton in preset/templates/plan-addendum.md"
Task: "Add per-ecosystem PBT signal table in preset/templates/plan-addendum.md"
```

## Parallel Example: Polish docs

```bash
# Different files, no conflicts:
Task: "Update layout/counts/limitation notes in README.md"
Task: "Fix D1 ×3→×4 + gate/doc mirror notes in BUILD_PLAN.md"
```

---

## Implementation Strategy

### MVP First (User Stories 1 + 2 Only)

1. Complete Phase 1: Setup (T001–T003).
2. Complete Phase 2: Foundational (T004–T007 — CRITICAL, blocks all stories).
3. Complete Phase 3: US1 EARS guidance (T008–T013).
4. Complete Phase 4: US2 Correctness Properties (T014–T021).
5. **STOP and VALIDATE**: run `scripts/self-gate.sh --no-e2e` + `specify preset resolve spec-template | grep -i EARS` + `resolve plan-template | grep "Correctness Properties"`; trial spec with ≥8 reqs (SC-002 audit).
6. Deploy/demo if ready (MVP: executable requirements + verifiable properties).

### Incremental Delivery

1. Setup + Foundational → conventions ready.
2. Add US1 → EARS guidance composes → validate (SC-001 spot check).
3. Add US2 → properties + opt-out + framework decision → validate (SC-002).
4. Add US3 → per-property task rules → validate (SC-003 zero-hardcode grep).
5. Polish → mirror-sync + docs + full gate both OSes (SC-004/SC-005).

### Parallel Team Strategy

With multiple developers (after Setup + Foundational together):

- Developer A: US1 (`preset/templates/spec-addendum.md` + its probes).
- Developer B: US2 (`preset/templates/plan-addendum.md` + its probes).
- Developer C: US3 prep (`preset/templates/tasks-addendum.md` skeleton, finalises once P-ID shape lands).
- Integrate: gate assertions → mirror-sync → docs → full verification.

---

## Notes

- [P] tasks = different files, no dependencies (T014+T018 share a file — coordinate to avoid merge conflicts).
- [Story] label maps task to its user story for traceability (US1 → spec guidance, US2 → plan properties, US3 → tasks rules).
- Each user story is independently completable and testable via its resolve + grep + trial.
- Gate assertions are bash-3.2-safe (no assoc arrays, `mapfile`, `wait -n`, `${var,,}`); quoted versions stay quoted.
- Commit after each task or logical group; stop at any checkpoint to validate.
- Avoid: hardcoding any concrete PBT framework outside the allowlisted negative-example line; new preset entries; core-template forks; skill-dependent wording.
- Framework names (Hypothesis, fast-check, proptest, …) appear ONLY as (a) research R4 signal-table instruction in `plan-addendum.md`, (b) one "do NOT hardcode (e.g., Hypothesis)" negative-example sentence per addendum, (c) the gate allowlist for (b). Nowhere else.

---

<!--
  Appended by the spec-driven-development preset (strategy: append).
  The core task format above (phases, [P] markers, [Story] labels, checkpoints,
  dependency ordering) remains authoritative. This addendum adds the per-task detail
  block that makes each task traceable and independently verifiable.
-->

## Correctness Properties (this feature — dogfood)

| Property ID | Requirement | for-any statement | Non-mapped reason | Notes |
| --- | --- | --- | --- | --- |
| P-001 | FR-001 | for any of the five EARS patterns, `spec-addendum.md` shows its syntax shape plus ≥1 example | — | Verified by T013 probes (SC-001) |
| P-002 | FR-002 | for any triggered-response requirement, its shape is `WHEN <trigger> THE SYSTEM SHALL <response>` | — | T008 + T013 |
| P-003 | FR-003 | for any state-dependent requirement, its shape is `WHILE <state> THE SYSTEM SHALL <response>` | — | T008 + T013 |
| P-004 | FR-004 | for any unwanted-condition requirement, its shape is `IF <unwanted> THEN THE SYSTEM SHALL <mitigation>` | — | T008 + T013 |
| P-005 | FR-005 | for any optional-capability requirement, its shape is `WHERE <feature> THE SYSTEM SHALL <response>` | — | T008 + T013 |
| P-006 | FR-006 | for any testable EARS requirement, the plan section holds ≥1 `for any <domain>, <property>` row | — | T014/T015 + T021 (SC-002) |
| P-007 | FR-007 | for any correctness property, the tasks template yields ≥1 PBT task tracing FR-ID + P-ID and naming the plan-recorded framework | — | T022 + T027 (SC-003) |
| P-008 | FR-008 | for any kit-owned normative template text, zero concrete PBT framework names appear outside the allowlisted negative-example line | — | T006/T012 + T027/T035 (SC-003) |
| — | FR-009 | — | qualitative / non-quantifiable requirements cannot carry a decidable oracle; opt-out with reason instead of vacuous property | T016 + T021 (SC-002) |
| P-010 | FR-010 | for any of spec/plan/tasks-template resolves, the append layer composes with no skill loaded | — | T020 + T034 (SC-004) |
| P-011 | FR-011 | for any requirement/property/test triple, IDs link FR→P→T so unbuilt and scope-creep are detectable | — | T005/T019/T026 |
| P-012 | FR-012 | for any target project with/without a PBT framework, the plan records detected/version/adopt-vs-fallback and tasks follow it verbatim | — | T017/T024 + T021 |

Coverage: 11 mapped + 1 opted-out (FR-009) = 12/12 = 100% accounted for.

## Task Detail Block

```markdown
## T003: [Task Name]

- **Objective**: What this task achieves, in one line.
- **Addresses requirement(s)**: FR-004
- **Implements design decision(s)**: Where the design said this belongs.
- **Depends on**: T001, T002
- **Likely files**: Path or component, without guessing every file.
- **Scope boundaries**: What must NOT change while doing this.
- **Expected output**: Observable result.
- **Verification**: The exact command or check that proves it works.
- **Completion conditions**: tests pass; FR-004 acceptance criteria satisfied.
- **Risks / rollback**: What could go wrong, and how to undo it.
```

### Worked example

```markdown
## T003: Reject expired invitations during acceptance

- **Objective**: Reject expired invitations at acceptance time.
- **Addresses requirement(s)**: FR-004
- **Implements design decision(s)**: Validation happens in the service layer.
- **Depends on**: T001, T002
- **Likely files**: invitation service, invitation acceptance tests
- **Scope boundaries**:
  - Do not change the invitation expiry duration.
  - Do not alter email delivery.
- **Expected output**:
  - Expired invitations return the defined error.
  - Valid invitations continue to work.
- **Verification**: unit test for expired invitation; regression test for valid invitation.
- **Completion conditions**: tests pass; FR-004 acceptance criteria satisfied.
- **Risks / rollback**: Reversible by reverting the service-layer change; no migration.
```

## Key Task Details (non-trivial tasks expanded)

### T004: Shared SHALL-only boilerplate

- **Objective**: Fix the single RFC 2119/Shall-only sentence all addenda reuse.
- **Addresses requirement(s)**: FR-001 (P-001)
- **Implements design decision(s)**: Research R2 (SHALL-only); plan Must-Not-Change (no MUST/SHALL interchange).
- **Depends on**: T001, T002
- **Likely files**: `preset/templates/spec-addendum.md` (boilerplate lives here; plan/tasks addenda quote it).
- **Scope boundaries**: Do not add per-pattern examples here (T008); do not touch core `.specify/templates/*.md`.
- **Expected output**: One agreed boilerplate line + lowercase-verb ban.
- **Verification**: Inspect line; `grep -q "RFC 2119" preset/templates/spec-addendum.md`.
- **Completion conditions**: Wording agreed; US1–US3 authors copy it verbatim.
- **Risks / rollback**: Trivial text revert; no migration.

### T008: Five-pattern EARS table

- **Objective**: Author the compact guidance table planners/authors copy from.
- **Addresses requirement(s)**: FR-001..FR-005 (P-001..P-005)
- **Implements design decision(s)**: Research R1 canonical shapes; plan Major Component "EARS guidance block"; `contracts/spec-addendum-contract.md` MUST-1.
- **Depends on**: T004, T005
- **Likely files**: `preset/templates/spec-addendum.md`.
- **Scope boundaries**: Do not name any concrete PBT framework; do not fork core spec-template; keep ~30 lines (plan bloat risk).
- **Expected output**: 5 rows (Pattern|Keyword|Shape|Use-when|Example) with generic `<system>`/`<trigger>` placeholders.
- **Verification**: Contract probes — `grep -q "WHEN <trigger>" preset/templates/spec-addendum.md` (×5 patterns); self-gate T013 passes.
- **Completion conditions**: All five shapes + ≥1 example each present; SC-001 convertible.
- **Risks / rollback**: Bloat → authors skip; mitigate with compact table. Revert single hunk.

### T013: EARS-row gate assertions

- **Objective**: Lock US1 template text with grep probes so later edits cannot silently regress it.
- **Addresses requirement(s)**: FR-001..FR-005 (P-001..P-005)
- **Implements design decision(s)**: Plan Gate content assertions; `contracts/preset-contract.md` new-assertion rule.
- **Depends on**: T008–T012
- **Likely files**: `scripts/self-gate.sh` (bash-3.2-safe; §3/§5 area).
- **Scope boundaries**: Do not break existing 4-target/E2E/idempotency assertions; do not use bash-4+ syntax.
- **Expected output**: EARS probes from `contracts/spec-addendum-contract.md` Gate probe block, passing.
- **Verification**: `./scripts/self-gate.sh --no-e2e` → `SELF-GATE: PASS`.
- **Completion conditions**: Probes present and green; `bash -n scripts/self-gate.sh` clean under bash 3.2.
- **Risks / rollback**: Regex false positives — scope to normative text. Revert hunk.

### T014/T015: Correctness Properties table + for-any rule

- **Objective**: Give planners the reviewable table and quantifier syntax that make specs executable.
- **Addresses requirement(s)**: FR-006 (P-006)
- **Implements design decision(s)**: Research R5; plan Major Component "Correctness Properties section"; `contracts/plan-addendum-contract.md` MUST-1.
- **Depends on**: T004–T007
- **Likely files**: `preset/templates/plan-addendum.md`.
- **Scope boundaries**: Properties live in plan, not spec (rejected alternative); no separate properties file.
- **Expected output**: `## Correctness Properties` + `| Property ID | Requirement | for-any statement | Non-mapped reason | notes |` + `for any <domain>, <property>` rule with 1:many note.
- **Verification**: `grep -q "## Correctness Properties" preset/templates/plan-addendum.md && grep -q "for any" preset/templates/plan-addendum.md`.
- **Completion conditions**: Table + syntax rule present; SC-002 trial auditable.
- **Risks / rollback**: Vacuous properties — mitigated by T016 opt-out. Revert hunk.

### T016: Opt-out rule

- **Objective**: Make non-mappable requirements explicitly accounted-for instead of forced.
- **Addresses requirement(s)**: FR-009 (opt-out; no P-ID)
- **Implements design decision(s)**: Research R5 non-mappable kinds; plan opt-out rows rule.
- **Depends on**: T014
- **Likely files**: `preset/templates/plan-addendum.md`.
- **Scope boundaries**: Opt-out rows mint NO P-ID; never both statement + reason, never neither.
- **Expected output**: One-line-reason rule + qualitative example ("tone is welcoming — no decidable oracle; manual review instead").
- **Verification**: `grep -qi "opt-out\|non-mapped" preset/templates/plan-addendum.md`.
- **Completion conditions**: Coverage rule mappable-XOR-opted-out = 100% statable (SC-002).
- **Risks / rollback**: Authors abuse opt-out to dodge properties — checklist review catches it.

### T017/T018: Framework-decision record + signal table

- **Objective**: Record per-project PBT choice without hardcoding any default.
- **Addresses requirement(s)**: FR-012 (P-012), FR-008 (P-008)
- **Implements design decision(s)**: Research R4 signal table; plan framework-decision record; detection is two greps.
- **Depends on**: T006
- **Likely files**: `preset/templates/plan-addendum.md`.
- **Scope boundaries**: Instruction + signal table only — no registry YAML, no auto-generated test code, no kit default.
- **Expected output**: `detected framework / version / signal / decision (use-detected | adopt-<name> | example-based-fallback-with-reason)` + 10-row ecosystem table as prose.
- **Verification**: `grep -qi "framework.*decision\|detected framework" preset/templates/plan-addendum.md`; SC-003 grep (T035) excludes these lines from hardcode hits only via the negative-example allowlist where applicable.
- **Completion conditions**: Agent can detect framework with two greps; missing-framework path recorded.
- **Risks / rollback**: Registry drift — avoided by instruction-only design.

### T022: One-PBT-task-per-property rule

- **Objective**: Close the property→test loop with per-property traceability.
- **Addresses requirement(s)**: FR-007 (P-007)
- **Implements design decision(s)**: Research R6; plan Major Component "Property-test task rules"; `contracts/tasks-addendum-contract.md` MUST-1.
- **Depends on**: T014–T017 (P-ID + decision shape stable)
- **Likely files**: `preset/templates/tasks-addendum.md`.
- **Scope boundaries**: Co-located per story (T023), not a trailing phase; no mega-task; no generated test code.
- **Expected output**: Rule sentence matching tasks-contract probe (`one property-based test … per … propert*`) + FR-ID + P-ID + framework-naming requirement.
- **Verification**: `grep -qi "per correctness property\|one property-based test.*per.*propert" preset/templates/tasks-addendum.md && grep -q "P-ID\|P-001" preset/templates/tasks-addendum.md`.
- **Completion conditions**: SC-003 satisfiable: every P-ID maps to a task naming the recorded framework.
- **Risks / rollback**: Unreviewable mega-task temptation — rejected. Revert hunk.

### T027: Tasks-rule + no-hardcode gate assertions

- **Objective**: Lock US3 rules and the FR-008 guard in the gate.
- **Addresses requirement(s)**: FR-007 (P-007), FR-008 (P-008), FR-011 (P-011)
- **Implements design decision(s)**: Plan Gate negative test with allowlisted negative-example line.
- **Depends on**: T022–T026
- **Likely files**: `scripts/self-gate.sh`.
- **Scope boundaries**: Bash-3.2-safe; allowlist ONLY the documented "do NOT hardcode" line; scope greps to normative text to avoid R4 signal-table false positives.
- **Expected output**: Per-property + P-ID + framework probes green; hardcode grep empty (quickstart Scenario 4).
- **Verification**: `./scripts/self-gate.sh --no-e2e` PASS + Scenario 4 greps as documented.
- **Completion conditions**: SC-003 enforced by gate, not just review.
- **Risks / rollback**: False positives on signal-table names — mitigated by allowlist + scoping.

### T028: Mirror re-sync

- **Objective**: Keep the committed installed copy identical so the gate verifies what ships.
- **Addresses requirement(s)**: FR-010 (append delivery); preset-contract mirror-set.
- **Implements design decision(s)**: Plan Must-Change mirror list; installer sync model.
- **Depends on**: T008–T027 (all addenda final)
- **Likely files**: `.specify/presets/spec-driven-development/templates/*.md`, `.specify/presets/spec-driven-development/preset.yml`.
- **Scope boundaries**: Copy only — no independent edits in the mirror; do not touch `agent-context` internals.
- **Expected output**: Mirror diff empty (`diff -r preset/templates .specify/presets/spec-driven-development/templates` clean except intended version).
- **Verification**: E2E `specify preset resolve` ×4 shows append layer (gate §5).
- **Completion conditions**: SC-005 composition passes on scratch repo.
- **Risks / rollback**: Drift → green gate, broken composition; fix by re-sync. Re-copy.

### T033/T034/T035: End-to-end verification

- **Objective**: Prove SC-001..SC-005 with evidence, not compilation.
- **Addresses requirement(s)**: All FRs via SC-001 (T034), SC-002 (T035), SC-003 (T035), SC-004 (T034), SC-005 (T033).
- **Implements design decision(s)**: Plan Validation Strategy; `quickstart.md` Scenarios 1–4.
- **Depends on**: T028–T032
- **Likely files**: `scripts/self-gate.sh` (T033), `specs/001-ears-executable-specs/quickstart.md` (T034/T035 procedures).
- **Scope boundaries**: Methodology skill UNLOADED for T034; `lean` bypass is documented-not-defective (never asserted).
- **Expected output**: `SELF-GATE: PASS` both OSes; scratch trial shows EARS + properties + PBT tasks; SC-002 100%; SC-003 grep empty.
- **Verification**: The runs themselves; paste `SELF-GATE: PASS` + trial excerpts into the completion report.
- **Completion conditions**: All five SC rows in quickstart Pass-criteria table checkable.
- **Risks / rollback**: No code risk; re-run trials on failure. Scratch repos are disposable.

## Task Rules

- Order tasks by dependency; keep them small enough to review in one pass.
- Put tests next to the behaviour they verify, not in a trailing phase (T013 with US1, T021 with US2, T027 with US3).
- Every task traces to a requirement or an approved design decision (see detail blocks + coverage table).
- Do not create tasks for unapproved future work (linter binary, registry YAML, auto-generated tests — all rejected in plan Alternatives).
- Distinguish implementation, test, migration, documentation, and validation work (T008–T012 implementation vs T013 test; T033–T035 validation; T029–T031 docs/version; no migrations).
- State the evidence that marks a task complete (grep / gate / trial, not "looks right").
- Identify migrations and sequencing constraints explicitly (no migrations; sequencing: Foundational → US1 → US2 → US3 → Polish).

## Requirement Coverage

| Requirement | Tasks | Covered? |
| --- | --- | --- |
| FR-001 | T008, T009, T013 | ☐ |
| FR-002 | T008, T013 | ☐ |
| FR-003 | T008, T013 | ☐ |
| FR-004 | T008, T013 | ☐ |
| FR-005 | T008, T013 | ☐ |
| FR-006 | T014, T015, T021, T033 | ☐ |
| FR-007 | T022, T025, T027, T033 | ☐ |
| FR-008 | T006, T012, T018, T027, T035 | ☐ |
| FR-009 | T016, T021 | ☐ |
| FR-010 | T020, T028, T033, T034 | ☐ |
| FR-011 | T005, T019, T026 | ☐ |
| FR-012 | T017, T018, T024, T021 | ☐ |

Coverage: every FR has ≥1 implementation task + ≥1 verification task; FR-009 intentionally has no P-ID (opt-out). A requirement with no task is unbuilt; a task with no requirement is scope creep — checked above.
