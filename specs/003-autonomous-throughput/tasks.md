# Tasks: Autonomous Throughput and a Mechanical Boundary

**Input**: Design documents from `/specs/003-autonomous-throughput/`

**Prerequisites**: `plan.md` (required), `spec.md` (required), `research.md`, `data-model.md`, `contracts/`, `quickstart.md`

**Tests**: Included. The spec's Validation Plan and the plan's Correctness Properties require them
(FR-014); `plan.md` §Framework decision is **fallback** — example-based tests plus loop-generated
fixture corpora, **no property-testing framework**.

**Organization**: Grouped by user story for independent implementation and testing.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: US1 / US2 / US3 / US4
- Exact file paths are included

## Path Conventions

Single project — the kit repository. All paths are repo-relative: `bin/`, `commands/`, `preset/`,
`global/`, `hooks/`, `scripts/`, `specs/`.

---

## Phase 1: Setup

**Purpose**: Establish the baseline before any change.

- [x] T001 Record the baseline: run `./scripts/self-gate.sh` and save the output

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: One shared mechanism both US1 and US2 write through.

**⚠️ CRITICAL**: No user story work begins until T002 is complete.

- [x] T002 Extract the `AGENTS.md` marker-replacement logic in `bin/speckit-init` into a reusable
      `write_managed_block <file> <start-marker> <end-marker>` helper; rewire the existing
      `SPECKIT-BRIDGE` writer to use it with **no behaviour change**

**Checkpoint**: The helper exists and the bridge output is byte-identical — US1 and US2 can now proceed.

---

## Phase 3: User Story 1 — Mechanical boundary (Priority: P1) 🎯 MVP

**Goal**: Routine work runs without prompts; irreversible actions are refused at the tool layer; the
autonomy contract is installed once; rule-file drift is reported.

**Independent Test**: In a scratch project, a denied command is refused and a routine command runs
without a prompt; changing a managed block is reported on the next install.

### Tests for User Story 1

> Write these FIRST; confirm they FAIL before implementation.

- [x] T003 [P] [US1] Gate: static assertions that `bin/speckit-init` contains the permission-block
      logic and the deny list, and that **no** `preset/commands/*.prepend.md` carries the four-bucket
      contract prose (FR-004) (`scripts/self-gate.sh`, §1-family + §3b)
- [x] T004 [P] [US1] Gate: e2e assertion that a scratch install writes `opencode.json` carrying every
      deny rule (`scripts/self-gate.sh` §5), plus the denied-command negative harness
- [x] T005 [P] [US1] Property **P-003**: fixture-loop asserting every action on the fixed irreversible
      list is matched by a `deny` rule (see `contracts/permission-block.md`)
- [x] T006 [P] [US1] Property **P-002**: fixture corpus of pre-existing `opencode.json`, `hooks.yaml`,
      and `AGENTS.md`; assert the installer never rewrites a user-owned region

### Implementation for User Story 1

- [x] T007 [US1] New installer step §2d: create `opencode.json` with the permission block if absent;
      print the block + merge instruction if present (`bin/speckit-init`)
- [x] T008 [US1] Add `global/autonomy-contract.md`; copy it to `.opencode/autonomy-contract.md`
      (create-if-absent) (`bin/speckit-init`)
- [x] T009 [US1] Add exactly one pointer line to the `SPECKIT-BRIDGE` block
      (`bin/speckit-init` embedded heredoc)
- [x] T010 [US1] Report drift when a managed block differs from the installed one (FR-015)
      (`bin/speckit-init`)
- [x] T011 [US1] `bin/speckit-uninit`: remove the autonomy contract; reverse `opencode.json` only when
      the kit created it
- [x] T012 [US1] Property **P-001**: fixture-loop running `speckit-init` twice and diffing the project

**Checkpoint**: US1 is independently testable — S1, S2, S3, S4, S5, S10 in `quickstart.md`.

---

## Phase 4: User Story 2 — One-command verification (Priority: P1) 🎯 MVP

**Goal**: The stack's commands are recorded once and exposed as a single `verify` entry point that a
task's Verification line names.

**Independent Test**: On a detectable stack, `./scripts/verify` runs the detected commands in order; a
generated task names it; an undetectable stack records `unresolved` and generates no `verify`.

### Tests for User Story 2

- [x] T013 [P] [US2] Gate: e2e assertion for the `SPECKIT-COMMANDS` block and the generated
      `scripts/verify`, including the `unresolved` case (`scripts/self-gate.sh` §5)
- [x] T014 [P] [US2] Property **P-004**: re-running the installer leaves exactly one
      `SPECKIT-COMMANDS` marker pair

### Implementation for User Story 2

- [x] T015 [US2] Command detector: read `package.json` scripts, `pyproject.toml`, `Cargo.toml`,
      `go.mod`, `Makefile` (`bin/speckit-init`)
- [x] T016 [US2] Write the `SPECKIT-COMMANDS` managed block via `write_managed_block`
      (`bin/speckit-init`)
- [x] T017 [US2] Generate `scripts/verify` in the target project (create-if-absent; non-zero on first
      failure) (`bin/speckit-init`)
- [x] T018 [US2] Extend `preset/commands/speckit.tasks.prepend.md` so a task's Verification line names
      the recorded command
- [x] T019 [US2] `bin/speckit-uninit`: remove the Commands block and `scripts/verify`

**Checkpoint**: US1 and US2 both work independently — S6, S7 in `quickstart.md`.

---

## Phase 5: User Story 3 — Continuous execution with a budget (Priority: P2)

**Goal**: Approved work executes without per-phase confirmation, committing and ledgering per task,
halting on a budget.

**Independent Test**: A three-task plan completes without a confirmation; a failing plan halts at the
budget and leaves the failing task unticked; a resumed run repeats nothing.

### Tests for User Story 3

- [x] T020 [P] [US3] Gate: extend the `expected` rule-marker dict and the §5 `check_cmd` calls for the
      new implement markers (`scripts/self-gate.sh` §3b, §5)
- [ ] T021 [P] [US3] Property **P-005**: ledger-resume fixture test — interrupt mid-run, resume,
      assert no completed task repeats

### Implementation for User Story 3

- [x] T022 [US3] Append the continuous-execution + execution-budget rule to
      `preset/commands/speckit.implement.prepend.md`
- [x] T023 [US3] Update the implement command description in `preset/preset.yml`
- [x] T024 [US3] Update the implement row in `skill/spec-driven-development/SKILL.md`

**Checkpoint**: US3 works independently — S9 in `quickstart.md`.

---

## Phase 6: User Story 4 — Fast lane (Priority: P2)

**Goal**: Small, well-understood work runs without spec/plan/tasks artifacts and promotes on overrun.

**Independent Test**: A one-line fix produces one log entry and no artifacts; an overrunning change
stops and promotes.

### Tests for User Story 4

- [x] T025 [P] [US4] Gate: assert `commands/speckit.quick.md` exists with its needles and is copied by
      the installer (`scripts/self-gate.sh` §1d-family, §5)

### Implementation for User Story 4

- [x] T026 [US4] Create `commands/speckit.quick.md` (see `contracts/quick-command.md`)
- [x] T027 [US4] Installer copies it like `commands/speckit.md` (`bin/speckit-init` §2b)
- [x] T028 [US4] Route to it from the `/speckit` entry point (`commands/speckit.md` §3)
- [x] T029 [US4] Sweep: add the `quick` row to the embedded bridge table (`bin/speckit-init`), and
      update `README.md`, `QUICKSTART.md`, `blog/spec-driven-development.md`

**Checkpoint**: US4 works independently — S8 in `quickstart.md`.

---

## Phase 7: Polish & Cross-Cutting Concerns

- [x] T030 [P] Bump `preset/preset.yml` to `1.12.0` and add `## [1.12.0]` to `CHANGELOG.md`
- [x] T031 [P] Update `README.md` component/command tables and layout (the count "prepend on 5
      commands" is now stale)
- [ ] T032 Run the full self-gate e2e on macOS (bash 3.2) and Linux (bash 5) — FR-014, SC-005
- [ ] T033 Run `quickstart.md` scenarios S1–S12 and record the evidence
- [x] T034 Fill the Task column in `spec.md` Requirement Traceability; reconcile `plan.md` if the
      design shifted during implementation
- [x] T035 Record SC-001/SC-003 evidence: count the human interactions used to implement 003 itself,
      record the comparison method against the current loop, and note that a fair measurement needs a
      second feature run after this ships
- [x] T036 Add a `Makefile` (`test:` → `./scripts/self-gate.sh`) so the kit's own `## Commands` block
      is meaningful and its `scripts/verify` runs the gate (added during implementation; the kit had
      no detectable stack, so its own Commands block would have read `unresolved`)

---

## Close-out notes

- **T004 / T021 / T033 (partial).** The mechanical halves are done and gated: the permission boundary
  is written and its deny coverage is asserted (P-003); the continuous-execution and ledger-resume
  *rules* are asserted present (§3b, §5). The behavioural halves — a live denied command, an
  interrupted implement run resuming from the ledger, and the fast lane on a real one-line fix — are
  manual scenarios (S4, S8, S9) and were **not** executed in this environment. They require a running
  opencode session.
- **T032 (partial).** The full gate passed on macOS bash 3.2 (`3.2.57(1)-release`). Linux bash 5 was
  **not** run here; CI (`.github/workflows/self-gate.yml`) is the remaining check.
- **Scope addition:** T036 (Makefile) and the third hook `block-force-push` were not in the original
  task list. The hook is the R5 mitigation the plan named; the Makefile makes the kit's own Commands
  block meaningful. Both are recorded here rather than silently added.
- **Not committed.** The work is on `main`, uncommitted, so the ledger lines carry no commit ranges.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies.
- **Foundational (Phase 2)**: after Setup — **blocks US1–US4** (the helper is shared by US1 and US2).
- **US1 (Phase 3)** and **US2 (Phase 4)**: after Foundational; independent of each other.
- **US3 (Phase 5)**: after Foundational; independent, but its value depends on US1 (the boundary makes
  continuous execution safe).
- **US4 (Phase 6)**: after Foundational; independent.
- **Polish (Phase 7)**: after all shipped stories.

### Within Each User Story

- Tests are written and **fail** before implementation.
- Source-of-truth files (kit sources) before the installer that copies/uses them.
- Installer step before the uninit reverse.
- Story complete before the next priority starts.

### Task-level dependencies

| Task | Depends on |
| --- | --- |
| T002 | T001 |
| T003–T006 | T002 |
| T007 | T002, T003 |
| T008, T009 | T002 |
| T010 | T002, T009 |
| T011 | T007, T008 |
| T012 | T007 |
| T013, T014 | T002 |
| T015 | T013 |
| T016, T017 | T015 |
| T018 | T016 |
| T019 | T016, T017 |
| T020 | T001 |
| T021 | T022 |
| T022, T023, T024 | T020 |
| T025 | T001 |
| T026 | T025 |
| T027 | T026 |
| T028 | T026 |
| T029 | T027, T028 |
| T030–T034 | all shipped stories |

---

## Parallel Opportunities

- **Phase 3 tests**: T003, T004, T005, T006 all touch different regions/files — run together.
- **Phase 4 tests**: T013, T014 together.
- **Phase 5 tests**: T020, T021 together (different files: gate vs fixture).
- **Phase 6 test**: T025 alone.
- **Phase 7**: T030 and T031 together (different files).
- **Across stories**: once Foundational completes, US1/US2/US3/US4 are file-disjoint at the
  source level (installer vs preset vs commands) and can be worked in parallel **only if** the
  installer edits (US1 §2d, US2 §6b, US4 copy) are serialized — they touch the same file
  (`bin/speckit-init`) and must not be dispatched concurrently.

### Parallel example — Phase 3 tests

```text
Task: "Gate static assertions for the permission block"        (scripts/self-gate.sh §1-family)
Task: "Gate e2e assertion for opencode.json + negative deny"   (scripts/self-gate.sh §5)
Task: "Property P-003 deny-coverage fixture-loop"
Task: "Property P-002 no-clobber fixture corpus"
```

---

## Implementation Strategy

### MVP First (US1 + US2)

1. Phase 1 Setup → Phase 2 Foundational.
2. Phase 3 US1 (boundary) → validate S1–S5, S10.
3. Phase 4 US2 (verification) → validate S6, S7.
4. **STOP and VALIDATE** both independently. This is the MVP the spec defines.

### Incremental Delivery

1. MVP (US1+US2) → the safety precondition and the biggest rework reducer.
2. US3 (continuous execution) → the round-trip savings; safe now that the boundary exists.
3. US4 (fast lane) → removes ceremony below the process's useful size.
4. Polish → version, docs, gate, quickstart evidence.

### Risk-ordered sequencing

Because R1 (config precedence), R2 (`permission` honoured), and R5 (glob flag position) are validation
unknowns, run **T004 + S4/S5 before T010 and the rest of US1's polish** — if the boundary does not
actually hold, the design changes before more is built on it.

---

## Notes

- `[P]` tasks touch different files with no dependency.
- Every task traces to a requirement or an approved design decision.
- Commit after each task or logical group; append a ledger line with evidence.
- Never hand-edit a generated file (`.opencode/commands/speckit*.md`, `.specify/**`) — the hooks block it.
- Avoid: vague tasks, same-file conflicts across parallel tasks, cross-story dependencies.

---

## Correctness Property Traceability

`FR-xxx → P-xxx → T0xx`. A property with no task is unbuilt; a property test with no requirement is
scope creep.

| Property | Requirement | Task | Check method |
| --- | --- | --- | --- |
| P-001 (idempotence) | FR-001, FR-005, FR-014 | T012 | fixture-loop in `self-gate.sh` |
| P-002 (no-clobber invariant) | FR-002, FR-015 | T006 | fixture corpus |
| P-003 (deny coverage) | FR-001, FR-003 | T005 | fixture-loop over the irreversible list |
| P-004 (marker-once) | FR-005 | T014 | marker-count assertion |
| P-005 (resume, no repeat) | FR-010 | T021 | ledger-resume fixture |
| FR-004, FR-007 | document presence | T003, T009, T013, T018 | direct gate assertions |
| FR-008, FR-009 | prompt behaviour | T020, T022 | gate marker + manual S9 |
| FR-011, FR-012, FR-013 | routing judgement | T025–T028 | gate presence + manual S8 |

---

## Phase 8: Convergence

Findings from `/speckit.converge` (independent review by a fresh context + the gate's negative
tests). Each carries a reproduction. Ordered CRITICAL/HIGH first.

- [x] T037 Soften the [1.12.0] CHANGELOG claims to match reality: the permission block is **inert
      without the `opencode-yaml-hooks` plugin**, and `uninit` removes the boundary by a
      blank-line-tolerant comparison and `scripts/verify` by a heuristic, not by byte-identity per
      `contradicts` (F8)
- [x] T038 Normalise quotes before token comparison in **both** hook predicates (`block-commit-no-verify`
      and `block-force-push`): `git push '-f' origin main` and `git commit "--no-verify" -m x` are
      ALLOW today per `contradicts` (F1) — add both as permanent §1f regression fixtures
- [x] T039 Broaden the destructive deny globs with a leading wildcard so wrappers and infixes match:
      `npx supabase db push`, `pnpm -r publish`, `npx prisma migrate reset` resolve to ALLOW today
      per `partial` (F2)
- [x] T040 Replace `uninit`'s `scripts/verify` substring heuristic with a generated-shape check (every
      non-blank line matches the generated grammar), so a user-customised verify is kept per
      `contradicts` (F3)
- [x] T041 Close the FR-005 gap: the detector sets no `install` command and no lint/typecheck for
      Python/Rust/Go, while `contracts/commands-block.md` lists `ruff`/`mypy`/`cargo check`/`go vet`
      signals per `partial` (F5) — implement, or narrow the contract to what is implemented
- [x] T042 Validate the permission block against a **live** opencode session (quickstart S4/S5): if
      opencode resolves rules first-match rather than last-match, the boundary is inert while the gate
      still passes per `partial` (F4, R1/R2); record the result and soften any claim until verified
- [x] T043 Tighten `uninit`'s command removal from the `speckit*.md` glob to the kit-owned names
      (`speckit.md`, `speckit.*.md`), so a user file like `speckit-notes.md` is not deleted per
      `partial` (F6)
- [x] T044 Strengthen the gate: assert FR-015 drift reporting, and give the uninit fixture a
      `package.json` so `scripts/verify` removal is actually exercised per `partial` (F7)
- [x] T045 Fix the two **pre-existing** CI failures found while validating T032 (neither caused by
      this feature): the runner-hang test resolved `speckit-init` from `PATH` (absent in CI), and the
      drift-checker section ran in a job that does not install `specify` per `contradicts` (F9)
