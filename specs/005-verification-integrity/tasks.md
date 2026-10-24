---
description: "Task list — 005-verification-integrity"
---

# Tasks: Verification Integrity — a Green Result Must Be Earned

**Input**: Design documents from `/specs/005-verification-integrity/`

**Prerequisites**: [plan.md](plan.md) (required), [spec.md](spec.md) (required for user stories), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Test tasks **are** included. The specification asks for them explicitly: SC-001 requires four vacuity fixtures plus a clean control, each story carries an Independent Test, and the only test suite this project actually runs is `scripts/self-gate.sh`. Property tests follow the plan's **fallback** decision — example-based fixtures plus small stdlib generators, no property framework, because adopting one would add a test-time dependency to a gate that must run on a stock macOS `python3`.

**Organization**: tasks are grouped by user story so each story is independently implementable and testable. US1 is the MVP; US2 is the second half of the thesis and ships with it.

## Generation note — the stopping rule, declared before round 1

Recorded here because the kit now requires it (`commands/speckit.md`, *Declare the stopping rule before iterating*).

- **A round** = one full pass of the Requirement Coverage table against the task list.
- **A finding** = a requirement with no task, a task with no requirement, a task without a runnable Verification line, or a task whose stated outcome is not single and verifiable.
- **Stop** after two consecutive rounds add none of those. **Boundary**: coverage of spec 005 as written, on 2026-10-22. This is not a claim that the decomposition is optimal or complete against future amendments.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

Single project at the repository root, per the plan's Structure Decision: `bin/` (executables), `scripts/` (the gate and the generated wrapper), `evals/` (measurement harnesses and fixtures), `preset/` (the shipped commands and templates), `specs/` (these artifacts). No new root directories.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create the three executables, the measurement harness and the fixture corpus that every later task edits, following the conventions the plan recorded (`#!/usr/bin/env bash`, a `# —` doc line, `set -euo pipefail`, `BASH_SOURCE` root resolution, plain `printf` output like `speckit-check`).

- [ ] T001 Create `bin/speckit-verify` skeleton: shebang, doc line, `set -euo pipefail`, root resolution, `--help`, and an exit-2 usage path for an unknown flag. → verify: `bash -n bin/speckit-verify` and `bin/speckit-verify --help` exits 0, `bin/speckit-verify --nonsense` exits 2
- [ ] T002 [P] Create `bin/speckit-ledger` skeleton with `append` / `read` / `verify` subcommands dispatching to usage errors. → verify: `bash -n bin/speckit-ledger`; `bin/speckit-ledger` with no subcommand exits 2
- [ ] T003 [P] Create `bin/speckit-security` skeleton with `observe` / `changed` / `block`. → verify: `bash -n bin/speckit-security`; no subcommand exits 2
- [ ] T004 [P] Create `evals/run-passk.py` skeleton: argv parsing, a `--help`, and a refusal path with no arguments. → verify: `python3 evals/run-passk.py --help` exits 0
- [ ] T005 [P] Create the fixture corpus builder `evals/fixtures/verify/make-fixtures.sh`, generating six throwaway projects: zero tests, self-referential oracle, skipped section, clean control, one-file change set, and a two-branch ledger merge simulator. → verify: running it twice in a temp dir succeeds and is idempotent
- [ ] T006 Register the three new executables in `bin/speckit-init`'s install list and `bin/speckit-uninit`'s removal list, and `chmod +x` them. → verify: `grep -c speckit-verify bin/speckit-init bin/speckit-uninit` is ≥1 in each; gate §"uninit restored the repo to its pre-install state" still passes

**Checkpoint**: four runnable skeletons and one fixture builder; nothing wired yet.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: the manifest, adapters, verdict, report, append writer, wrapper and seeding. Every user story reads from these; none of them belongs to a single story.

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T007 Implement the manifest loader and all-or-nothing validator in `bin/speckit-verify`: `version` must be `1`; `id` matches `^[a-z0-9][a-z0-9-]{0,63}$` and is unique; `kind` and `runner` are enum members; per-kind required fields (`control` for `test`/`property`, `falsify` and `spec_rule` for `property`/`schema`); `paths` non-empty. An invalid manifest exits 2 and records nothing. → verify: gate fixture rejects a manifest with a duplicate id and one with no `oracle`, exit 2 both times
- [ ] T008 [P] Implement the adapter contract in `bin/speckit-verify`: each adapter returns `examined=<n>` and `status=<pass|fail|no-items|not-run>`, with per-runner exit-code tables mapping "collected nothing" (pytest `5`, jest "no tests", an empty selection) to `no-items`, and `examined=unknown` when output cannot be parsed. → verify: adapter fixture table asserts `no-items` for each mapped code and `unknown` for unparsable output
- [ ] T009 [P] Implement the concrete adapters — `pytest`, `jest`, `cargo`, `go`, `make`, `command` — in `bin/speckit-verify`, each printing the adapter name alongside the count. → verify: one fixture project per adapter, asserting the printed count matches the fixture's known test count
- [ ] T010 Implement verdict computation in `bin/speckit-verify`: `PASS` only when `examined > 0`, `failures = 0`, `skips = 0`, `vacuous = 0`, `unmatched = 0` and the record is durable; `FAIL` dominates every other state; `INCOMPLETE` otherwise; `NOT-RUN` folds into `INCOMPLETE` at the verdict. Exit `0`/`1`/`3` accordingly. → verify: verdict truth-table fixture over all state combinations
- [ ] T011 [P] Implement the report renderer in `bin/speckit-verify`: human output plus `--json`; prints the examined total, per-check outcomes, mode, and selection when scoped. → verify: `--json` output validates against `contracts/ledger-record.schema.json` for the record half; human output contains `examined=`
- [ ] T012 Implement `bin/speckit-ledger append` (FR-010, FR-011, FR-014): open `O_APPEND`, `flock`, write exactly one `\n`-terminated line, `fsync`; carry the record fields from `contracts/ledger-record.schema.json`; refuse a record without `command` or `exit`; refuse a command matching a secret-shaped pattern. A write failure leaves the report printed, the run `INCOMPLETE` with `note: record not durable`, exit non-zero. → verify: gate fixture asserts a prose-only record is refused and a full one is appended once
- [ ] T013 Replace the generated `scripts/verify` **only** when it is byte-identical to the form `bin/speckit-init` writes, using `exec bin/speckit-verify "$@"`; otherwise print a migration note and leave the file untouched. → verify: gate installs into a scratch repo with a hand-written `scripts/verify` and asserts it is unchanged
- [ ] T014 Seed `.specify/verify.json` from the detected `## Commands` block in `bin/speckit-init`, validating the seed against the schema before writing, and add `--no-manifest` to skip seeding. → verify: fresh scratch install produces a manifest that `bin/speckit-verify --help`'s loader accepts; an unresolvable Commands block seeds checks with `examined: unknown` semantics rather than a false pass

**Checkpoint**: the engine runs a manifest, selects nothing (no selection yet), prints a verdict, and appends a record. US1 can begin.

---

## Phase 3: User Story 1 - A green result cannot come from nothing (Priority: P1) 🎯 MVP

**Goal**: A verification run refuses to report success when it examined nothing, when a check points its oracle at the code under test, or when a check's own negative control passes — and says which.

**Independent Test**: Run the verification command against four fixtures (zero tests, self-referential oracle, skipped section, clean control) and confirm each of the first three produces a distinct non-green outcome with a nonzero exit, while the control passes.

### Tests for User Story 1 (OPTIONAL - only if tests requested) ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T015 [P] [US1] Gate section for the four vacuity fixtures plus clean control in `scripts/self-gate.sh`, asserting distinct non-green outcomes and a passing control. → verify: the section fails against the unimplemented engine, then passes (SC-001)
- [ ] T016 [P] [US1] Property test P-003 — for any runner exit code in the "collected nothing" set, the verdict is not `PASS` and the exit is non-zero — in `evals/fixtures/verify/`. → verify: property passes, then remove the `no-items` mapping and confirm it fails

### Implementation for User Story 1

- [ ] T017 [US1] Execute each check's declared `control` before the check itself; a control that **passes** marks the check `vacuous`, forces `INCOMPLETE`, and reports "control did not fail". A control that cannot run is `not-run`, never `pass`. → verify: fixture with a constant-true control is reported vacuous with exit 3 (FR-005)
- [ ] T018 [US1] Enforce the `oracle` declaration: absent, or `implementation`, excludes the check from evidence with a named reason; the exclusion is printed. → verify: fixture with `oracle: implementation` is excluded and named; the same fixture with `oracle: spec` is included (FR-004)
- [ ] T019 [US1] Implement the zero-examined path: total `examined = 0` reports "nothing was examined" as its own state and exits 3 — distinct from a failure. → verify: zero-test fixture exits 3 with that phrasing, not `PASS` and not `FAIL` (FR-002, FR-006)
- [ ] T020 [US1] Property test P-004 — for any combination of skipped and failed checks, `PASS` is printed only when there are zero skips and zero failures — in `evals/fixtures/verify/`. → verify: property passes; then make `PASS` reachable with one skip and confirm it fails (FR-003)

**Checkpoint**: US1 fully functional and independently testable. A vacuous run can no longer be reported as green.

---

## Phase 4: User Story 2 - The report counts what it checked against the plan (Priority: P1)

**Goal**: Completion reports carry an `n/m` criteria tally with every gap named, refuse when the spec declares no criteria, and treat an unknown criterion id as an error.

**Independent Test**: Run against a spec with three criteria of which one is evidenced, then against a spec with none; confirm `1/3` with the two gaps named, and refusal in the second case.

### Tests for User Story 2 (OPTIONAL - only if tests requested) ⚠️

- [ ] T021 [P] [US2] Gate section asserting the tally format and refusal paths against two fixture specs. → verify: fails before T022–T024, passes after

### Implementation for User Story 2

- [ ] T022 [US2] Parse acceptance criteria from `specs/*/spec.md` and render the tally as `n/m` with every unevidenced criterion named. → verify: three-criteria fixture prints `1/3` and names the two gaps (FR-007)
- [ ] T023 [US2] Refuse to report completion when `m = 0`, with exit **3** — distinct from `speckit-resume`'s exit 2 for a mismatched ledger. → verify: criteria-free spec exits 3 and says which section is missing (FR-008)
- [ ] T024 [US2] Treat a reference to a nonexistent criterion id as an error with exit 2, not an uncounted task. → verify: record naming `SC-999` exits 2 and names the id (FR-009)
- [ ] T025 [US2] Add `--criteria` to `bin/speckit-resume`, printing the same tally and reusing the same exit-3 refusal. → verify: `bin/speckit-resume --criteria` on 005 prints `n/11`; on a criteria-free fixture exits 3 (FR-007, FR-008)
- [ ] T026 [US2] Property test P-006 — for any set of criteria and evidence records, the tally equals the number evidenced and the gaps are named — in `evals/fixtures/verify/`. → verify: property passes; then count a record twice and confirm it fails

**Checkpoint**: US1 and US2 together close the thesis: nothing examined, and nothing declared, both stop a green report.

---

## Phase 5: User Story 3 - The evidence trail survives being merged (Priority: P2)

**Goal**: Two branches appending results merge without loss, duplication or ambiguity; an in-place edit is detected; duplicate ids fail CI.

**Independent Test**: Append on two branches, merge, and confirm no record is lost or duplicated and that read order is chronological; then edit a record in place and confirm the tampering is reported.

### Tests for User Story 3 (OPTIONAL - only if tests requested) ⚠️

- [ ] T027 [P] [US3] Gate section running the merge simulator for 100 rounds and asserting zero lost, duplicated or order-ambiguous records. → verify: fails before T028/T029, passes after (SC-003)
- [ ] T028 [P] [US3] Property test P-001 — for any two sets of records merged in any order, reading yields the same sequence sorted by (`at`, `id`) — in `evals/fixtures/verify/`. → verify: passes; then sort by file order and confirm it fails (FR-013)

### Implementation for User Story 3

- [ ] T029 [US3] Implement `bin/speckit-ledger read`: order by `at` then `id`, independent of append order; report clock-skew ambiguity instead of hiding it. → verify: shuffled fixture prints the same sequence as the sorted fixture; a skewed pair is flagged (FR-013)
- [ ] T030 [US3] Implement `bin/speckit-ledger verify`: duplicate ids and malformed records fail (exit 1 and exit 2 respectively); the append-only ratio is computed from `git log --numstat` and a shrinking history is reported. → verify: in-place edit fixture is caught; duplicate-id fixture exits 1 (FR-010, FR-012)
- [ ] T031 [US3] Wire `bin/speckit-ledger verify` into `bin/speckit-check` and into CI so it runs before merge. → verify: a repo with a duplicate id makes `bin/speckit-check` report drift; CI job runs it (FR-012)
- [ ] T032 [US3] Property test P-002 — for any sequence of appends the file only grows and no id appears twice — in `evals/fixtures/verify/`. → verify: passes; then allow a rewrite path and confirm it fails (FR-010, FR-012)

**Checkpoint**: the trail is merge-safe and tamper-evident.

---

## Phase 6: User Story 4 - Verification cost tracks the size of the change (Priority: P2)

**Goal**: Default verification runs the checks a change can plausibly affect, names the selection, and never implies the whole suite is green; a changed-line figure states which coverage profile produced it.

**Independent Test**: Change one module, run the selected set, and compare time and result against a full run on the same commit; confirm the report's wording is scoped to the selection.

### Tests for User Story 4 (OPTIONAL - only if tests requested) ⚠️

- [ ] T033 [P] [US4] Gate section for selection wording and the unmatched-file path, plus the SC-004 timing fixture recording both numbers on this machine. → verify: fails before T034–T037, passes after; both timings recorded in the completion note
- [ ] T034 [P] [US4] Property test P-005 — for any changed set, every changed file is matched by a check or named as unmatched, and the report names the selection — in `evals/fixtures/verify/`. → verify: passes; then drop the unmatched-name path and confirm it fails (FR-015, FR-017)

### Implementation for User Story 4

- [ ] T035 [US4] Implement change-scoped selection: `git diff` against a base, manifest `paths` globs (`**` any depth), an unmatched changed file reported as `INCOMPLETE` with the file named, and a shared/configuration file change (glob list `selection.select_all_on`) selecting every check and stating `fallback:` rather than selecting only the checks that name it. → verify: single-file fixture selects two checks and names them; an unmatched file exits 3; a `conftest.py` change selects both checks and a private module still selects one (FR-015)
- [ ] T036 [US4] Implement `--all` and document the nightly job that runs it, keeping it out of the per-change path. → verify: `--all` runs every check; the documented job is referenced from README (FR-016)
- [ ] T037 [US4] Render mode-specific wording: a selected run may never say "all tests pass"; only `--all` may claim the suite. → verify: fixture asserts the selected report contains no "all tests" phrasing (FR-017)
- [ ] T038 [US4] Record a failure that passes on one re-run as `flaky-classified`, retaining both outcomes. → verify: flaky fixture shows both results and the label, neither `pass` nor `fail` (FR-018)
- [ ] T039 [US4] Implement `--coverage PATH --profile full|selected`: report changed lines reached and not reached, always naming the profile, and refuse the "file/module/project" or "no test executes this" reading from a selected profile. → verify: full-profile fixture with an unexecuted new line reports it unexercised; selected-profile fixture refuses the stronger claim (FR-033, FR-034)
- [ ] T040 [US4] Property test P-008 — for any changed-line report, provenance is stated and a selected profile never yields "no test executes" — in `evals/fixtures/verify/`. → verify: passes; then drop the provenance line and confirm it fails

**Checkpoint**: changed mode is fast, scoped, and honest about its scope.

---

## Phase 7: User Story 5 - Mutation results are review prompts, not a percentage (Priority: P3)

**Goal**: An opt-in, changed-files-only mutation run produces a bounded list of named candidates with kill status, no threshold, equivalent and unknown mutants distinguished, and unmeasurable modules reported as unmeasured.

**Independent Test**: Run on a fixture with one surviving mutant and confirm one named candidate with file, line and operator, and no percentage presented as a target.

### Tests for User Story 5 (OPTIONAL - only if tests requested) ⚠️

- [ ] T041 [P] [US5] Gate section over the mutation fixtures: one survivor, one crash-killed, one equivalent, one unmeasured module. → verify: fails before T042–T046, passes after
- [ ] T042 [P] [US5] Property test P-010 — for any mutant whose compiled form equals the original, it is labelled equivalent and is not a candidate — in `evals/fixtures/verify/`. → verify: passes; then count an equivalent as a candidate and confirm it fails (FR-022)
- [ ] T043 [P] [US5] Property test P-011 — for any killed mutant, the status distinguishes assertion from crash — in `evals/fixtures/verify/`. → verify: passes; then collapse the two statuses and confirm it fails (FR-038)

### Implementation for User Story 5

- [ ] T044 [US5] Implement `--mutation` as opt-in and scoped to changed files; absent the flag nothing mutation-related runs. → verify: default run records no mutation check; `--mutation` runs only changed files (FR-019)
- [ ] T045 [US5] Render the bounded candidate list — file, line, operator, kill status — honouring `mutation.limit`, and refuse to render any percentage as a verdict (a budget line beside the count is allowed). → verify: fixture prints one candidate and no `%` in the verdict line (FR-020, FR-021)
- [ ] T046 [US5] Apply the trivial-compiler-equivalence pre-filter and label anything neither provably equivalent nor classified as `unknown`, never `equivalent`. → verify: fixture with one provably equivalent and one unclassified mutant shows the two labels (FR-022)
- [ ] T047 [US5] Derive kill status from the mutant's exit: `killed-by-assertion` vs `killed-by-crash`; only the former counts as evidence that a test would notice the change. → verify: crash fixture is labelled and excluded from evidence (FR-038)
- [ ] T048 [US5] Report a module with no tests as `unmeasured`, not `0%` and not `100%` clean. → verify: no-tests fixture prints `unmeasured` (FR-023)
- [ ] T049 [US5] Implement `--extreme` whole-method mode, labelled less precise, never the default, never overwriting an operator-level result for the same tasks. → verify: extreme fixture's report carries the label; a prior operator-level record is unchanged (FR-039)
- [ ] T050 [US5] Property test P-007 — for any mutation result set, no percentage is emitted as a pass/fail threshold — as a gate fixture rather than a generator. → verify: fixture asserts the rendering and exit code; deliberately render a threshold and confirm it fails (FR-021). *Not generated: the property is a wording and exit-code assertion over a rendered report, which the plan records as `review-only`.*

**Checkpoint**: the expensive check produces prompts a human can act on, and no number to chase.

---

## Phase 8: User Story 6 - Security scanning is staged so it can be trusted (Priority: P3)

**Goal**: A broad scheduled scan records a per-rule baseline; a change-scoped scan reports without blocking; blocking begins only for a confirmed-live credential on a class whose baseline exists, using pinned rules.

**Independent Test**: Run observe on a clean project (blocks nothing, records a baseline), then block on a confirmed-live fixture (fails), a pattern-only fixture (does not fail), and a clean tree (passes).

### Tests for User Story 6 (OPTIONAL - only if tests requested) ⚠️

- [ ] T051 [P] [US6] Gate section over the ladder: baseline recorded, block without baseline refused, pattern-only not blocking, confirmed-live blocking, offline `NOT-RUN`, unpinned rules refused. → verify: fails before T052–T058, passes after (SC-005, SC-009)
- [ ] T052 [P] [US6] Property test P-009 — for any finding set, a blocking exit occurs only for a confirmed-live finding on a class with a recorded baseline — in `evals/fixtures/verify/`. → verify: passes; then allow a pattern-only block and confirm it fails (FR-025, FR-035)

### Implementation for User Story 6

- [ ] T053 [US6] Implement `bin/speckit-security observe --all`: run the broad scan and write `.specify/security/baseline.json` with per-rule counts and `rules_sha256`; it never blocks. → verify: fixture writes a baseline; exit 0 with findings present (FR-024, FR-040)
- [ ] T054 [US6] Implement `block` requirements: refuse without a baseline (exit 3), refuse when `rules_sha256` no longer matches the committed rules, and block only a `confirmed-live` finding on a class with a baseline entry (exit 1). → verify: all three refusals and the one permitted block are asserted (FR-025)
- [ ] T055 [US6] Implement the confirmation tier behind `--confirm` and the `security.confirm` manifest field, distinguishing `confirmed-live`, `confirmed-dead` and `pattern-only`; off-network it is `NOT-RUN`. → verify: stub provider confirms one credential; the same match without confirmation stays `pattern-only` and never blocks (FR-035, FR-036)
- [ ] T056 [US6] Refuse to run when the rule set is not pinned to a committed file; never fetch a floating default. → verify: missing-rules fixture exits 3 with a refusal, and no network call is attempted (FR-026)
- [ ] T057 [US6] Report a tool-internal error as `scan-failed` (exit 3), never `clean`; report network-dependent tiers as `not-run` offline. → verify: failing-tool fixture says `scan-failed`; `--offline` fixture says `not-run` (FR-027, FR-028)
- [ ] T058 [US6] Implement `bin/speckit-security changed` as a diff-aware, non-blocking stage using the same pinned rule set as the broad scan. → verify: changed fixture reports without exit 1 and names the same rules hash (FR-041)
- [ ] T059 [US6] Print the environment-only credential rule as the control for hand-written credentials, and refuse to let a green scan imply it. → verify: report text names the control; SC-009 fixture asserts no green scan satisfies it (FR-042)

**Checkpoint**: the ladder can be switched on without teaching the owner to ignore it.

---

## Phase 9: User Story 7 - Generated tests are aimed by the specification (Priority: P3)

**Goal**: A property check names the specification rule it encodes, ships a demonstration that it can fail, and prints a minimized counterexample verbatim.

**Independent Test**: Generate from a spec with two stated rules and confirm two properties, each naming its rule, and one deliberately falsifiable demonstration.

### Tests for User Story 7 (OPTIONAL - only if tests requested) ⚠️

- [ ] T060 [P] [US7] Gate section: a manifest property check with no `spec_rule` is rejected; one with `spec_rule` and a failing `falsify` command is refused. → verify: fails before T061–T063, passes after

### Implementation for User Story 7

- [ ] T061 [US7] Implement the `property` kind: require `spec_rule`, print it with the outcome, and reject a property check without one. → verify: fixture without `spec_rule` exits 2; with it, the report names the rule (FR-029)
- [ ] T062 [US7] Execute `falsify` before the property and refuse to count a property as evidence when its demonstration does not fail. → verify: fixture whose `falsify` passes is refused as vacuous (FR-030)
- [ ] T063 [US7] Print the minimized counterexample verbatim on failure, without truncation or re-wording. → verify: failing fixture prints the exact offending input (FR-029)
- [ ] T064 [US7] Add the `schemathesis` adapter and the documented `schema` manifest field; findings name the operation that produced them. → verify: OpenAPI fixture reports a finding annotated with its operation id (FR-037)
- [ ] T065 [US7] Add the `spec rule` column and a falsification command to `preset/templates/plan-addendum.md`'s Correctness Properties table, and the corresponding rule to `preset/commands/speckit.plan.prepend.md`. → verify: `specify preset resolve plan-template` shows the column; gate §3b asserts the prepend carries the rule (FR-029, FR-030)

**Checkpoint**: properties are traceable to spec text and provably able to fail.

---

## Phase 10: User Story 8 - Reliability is measured, not assumed (Priority: P3)

**Goal**: A task set's single-attempt and repeated-attempt success are reported side by side, with the pessimistic constant-difficulty bound and an explanation of the difference.

**Independent Test**: Run the same task set five times at a known success rate and confirm both figures plus the bound.

### Tests for User Story 8 (OPTIONAL - only if tests requested) ⚠️

- [ ] T066 [P] [US8] Gate section running `evals/run-passk.py` against a scripted success vector and a deterministic one. → verify: fails before T067, passes after; the deterministic case shows equal figures (SC-006)
- [ ] T067 [P] [US8] Property test P-012 — for any per-task success vector and `k`, both figures print and the bound is ≤ the empirical figure — in `evals/fixtures/verify/`. → verify: passes; then print only one figure and confirm it fails (FR-031, FR-032)

### Implementation for User Story 8

- [ ] T068 [US8] Implement `evals/run-passk.py`: `pass@1`, empirical `pass^k`, the constant-p bound, and a Wilson interval; print the difference between the two figures in one sentence, including the finite-sample case where the bound exceeds the empirical figure. → verify: `p=0.8, k=5` prints both figures with the bound as (mean pass@1)^k; `n=5, c=4, k=2` prints bound 0.64 > empirical 0.60 and names the reason (FR-031, FR-032)

**Checkpoint**: reliability has two numbers and a bound, not one hopeful one.

---

## Phase N: Polish & Cross-Cutting Concerns

**Purpose**: Improvements that affect multiple user stories, plus the release mechanics the constitution requires.

- [ ] T069 [P] Bump `preset/preset.yml` to the next free minor version and add the `CHANGELOG.md` entry. **The plan said 1.15.0; that version was consumed on 2026-10-22 by the stopping-rule change**, so this task uses the next free minor and records why the plan's number was not available. → verify: gate §1c "preset version is the newest CHANGELOG release" passes
- [ ] T070 [P] Update `README.md` and `QUICKSTART.md` for the three new executables, the manifest, the ladder and the changed/full split. → verify: every command named in the docs resolves to a file that exists
- [ ] T071 [P] Extend `bin/speckit-check` to report the new artifacts (manifest, ledger, security baseline) and their drift. → verify: a repo missing `.specify/verify.json` is reported, not passed
- [ ] T072 [P] Extend `bin/speckit-uninit` to remove the three executables, the seeded manifest and the security directory, leaving adopter files alone. → verify: gate uninit fixture returns the repo to a clean tree
- [ ] T073 Run the gate under both bash 3.2 and bash 5 in CI, with the new sections in the matrix rather than behind a version check. → verify: both jobs green in `.github/workflows/self-gate.yml`
- [ ] T074 Run `quickstart.md`'s twelve scenarios end to end and record which pass, which need a tool that is absent, and which are `NOT-RUN`. → verify: a written result per scenario in `progress.md`
- [ ] T075 Run `./scripts/verify` and `bash scripts/check-section-integrity.sh` on the finished tree; confirm the verdict prints an examined count (FR-001 satisfied at the kit's own gate). → verify: gate green with `examined=N` in the verdict block, `N > 0`
- [ ] T076 Open `specs/005-verification-integrity/progress.md` with the identity line and write one `Task N: complete (<evidence>)` line per task as it closes. → verify: `bin/speckit-resume specs/005-verification-integrity` prints `COMPLETE` only when every task has a line
- [ ] T077 [P] Add the amendment's states to `bin/speckit-verify`: a changed line the report never mentions is `unmentioned` (never `unexercised`), an excluded line is named excluded, a file absent from the report is `unprofiled`, and a report whose summary contradicts its line lists is `inconsistent`; none of the four enters the denominator. → verify: `harness.py --case coverage-silence` and `--property P-013` pass, and both fail against an engine that classifies silence as unexercised (FR-043, SC-008)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies; starts immediately.
- **Foundational (Phase 2)**: depends on Setup; **blocks every user story**.
- **User Stories (Phases 3–10)**: all depend on Phase 2. US1 and US2 are P1 and ship first; the rest can proceed in parallel once Phase 2 lands.
- **Polish (final phase)**: depends on the stories it documents; T069–T072 may start as soon as their story is complete.

### User Story Dependencies

- **US1 (P1)**: independent. Nothing else is trustable until a vacuous pass is impossible.
- **US2 (P1)**: independent of US1 mechanically, but the two together are the thesis; ship them together.
- **US3 (P2)**: independent; needs only the append writer from T012.
- **US4 (P2)**: needs the engine (T007–T011) and, for its timing claim, no other story.
- **US5 (P3)**: needs US4's change set (T035) for "changed files only"; otherwise independent.
- **US6 (P3)**: independent of US4/US5; shares only the report and the record.
- **US7 (P3)**: needs the manifest (`spec_rule`, `falsify` fields) from T007 and US4's selection.
- **US8 (P3)**: fully independent — a standalone script in `evals/`.

### Within Each User Story

- Tests (the gate section and the property test) are written first and must fail.
- Manifest/contract fields before adapters; adapters before verdict paths that read them.
- Core behaviour before integration; the report wording last, because it is what a reader judges.

### Parallel Opportunities

- All Setup tasks marked `[P]` run together.
- In Phase 2, T008/T009 (adapters) and T011 (report) are independent of T012 (append writer).
- Once Phase 2 completes, US1, US2, US3 and US8 can start in parallel — they share no files beyond `bin/speckit-verify`, which only US1/US2/US4/US5/US7 edit.
- US6 and US8 touch disjoint files entirely (`bin/speckit-security`, `evals/run-passk.py`).

---

## Parallel Example: User Story 1

```bash
# Launch all tests for User Story 1 together (if tests requested):
Task: "Gate section for the four vacuity fixtures plus clean control in scripts/self-gate.sh"
Task: "Property test P-003 for no-items exit codes in evals/fixtures/verify/"

# Launch all models for User Story 1 together:
# There are no models in this feature — the equivalent batch is the implementation
# tasks that touch bin/speckit-verify, which run in dependency order:
Task: "Execute control before check; passing control is vacuous"        # T017
Task: "Enforce the oracle declaration and report exclusions"            # T018
Task: "Implement the zero-examined path with exit 3"                    # T019
Task: "Property test P-004 for the PASS precondition"                   # T020
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 → Phase 2.
2. US1 (T015–T020).
3. **Stop and validate**: run the four vacuity fixtures and the clean control. If any of the first three is green, the feature has failed its own thesis and nothing later matters.

### Incremental Delivery

1. US1 + US2 → a report that cannot be green without having looked, and cannot claim completion without criteria. This is the shippable increment.
2. US3 → the trail becomes merge-safe, which makes the records usable across branches.
3. US4 → verification becomes affordable per change, without overstating its scope.
4. US5 → the expensive check becomes a review aid.
5. US6 → security scanning is switchable without alert fatigue.
6. US7 + US8 → properties aimed by spec text, and reliability stated as two numbers.
7. Polish → release mechanics, docs, uninstall, and the kit's own gate printing what it examined.

### Parallel Team Strategy

One person on the engine (T007–T013), one on the security ladder (T053–T059), one on the measurement (`evals/`, T004, T068) — those three share no files. The gate sections are the contention point and should be serialised, because `scripts/self-gate.sh` is one file.

---

## Notes

- `[P]` marks tasks that cannot conflict: different files, no shared incomplete dependency.
- Every Verification line names `./scripts/verify` — the command recorded in the `## Commands` block — plus the specific fixture or section that proves this task.
- A task is ticked only when its named evidence has been produced. A property test that cannot fail is not evidence; the plan records the fallback decision that makes each one example-based plus a small generator.
- The gate section numbers mentioned above (`§1k` and later) are placeholders for whatever section the implementer adds; the gate's own header text is the record, not these labels.
- FR-037 lands as one adapter plus a manifest field — the lightest touch the plan allowed, recorded rather than expanded.
- **Recorded defect, not fixed here:** `scripts/check-section-integrity.sh` treats the template's placeholder
  heading `Phase N` and two comment lines inside its sample bash block as *required sections*. This list
  satisfies the checker literally instead of changing the checker mid-feature, so every adopter's `tasks.md`
  will carry placeholder text until that check is repaired at the source.

---

## Task Detail Block

The checkbox lines above give the plan. For any task that is not trivial, expand it using
this block. The point is that each task states **why it exists** and **how you will know it
is done** — not just what to edit.

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
- **Completion conditions**: What must be true to tick this off.
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

### Expanded blocks for the substantial tasks

```markdown
## T010: Verdict computation

- **Objective**: One place decides PASS / FAIL / INCOMPLETE / NOT-RUN, and no caller can supply it.
- **Addresses requirement(s)**: FR-002, FR-003
- **Implements design decision(s)**: The vocabulary is copied from `scripts/self-gate.sh:1477-1491`; FAIL dominates.
- **Depends on**: T007, T008
- **Likely files**: `bin/speckit-verify`
- **Scope boundaries**: Do not add a fifth verdict state; do not let a mode change the arithmetic.
- **Expected output**: A truth table over (examined, failures, skips, vacuous, unmatched, durable) that matches the data model's state diagram exactly.
- **Verification**: verdict fixture over all combinations; then break one precondition and confirm the fixture fails.
- **Completion conditions**: `PASS` is unreachable with `examined = 0`, `skips > 0`, `vacuous > 0`, `unmatched > 0`, or a non-durable record.
- **Risks / rollback**: Localised to one function; revert the file.

## T012: Append writer

- **Objective**: Appending a record is atomic and never rewrites an existing line.
- **Addresses requirement(s)**: FR-010, FR-011, FR-014
- **Implements design decision(s)**: `O_APPEND` + `flock` + `fsync`; no rewrite path exists in the code.
- **Depends on**: T002
- **Likely files**: `bin/speckit-ledger`
- **Scope boundaries**: No compaction, no sorting on write, no migration of existing lines.
- **Expected output**: One line per append, `\n`-terminated; a refusal for a record without `command`/`exit`; a refusal for a secret-shaped command.
- **Verification**: append 100 records, assert 100 lines and an unchanged prefix hash; attempt a prose-only append and assert refusal.
- **Completion conditions**: kill -9 during append leaves either the full line or no line, never a partial one.
- **Risks / rollback**: Delete the file in a fixture; never in a real repo.

## T013: Wrapper replacement

- **Objective**: Projects get the new engine without losing a hand-written `scripts/verify`.
- **Addresses requirement(s)**: carried-forward decision (004 FR-010: the Commands entry point does not change)
- **Implements design decision(s)**: Replace only a byte-identical generated form; otherwise print a migration note.
- **Depends on**: T006, T001
- **Likely files**: `bin/speckit-init`
- **Scope boundaries**: Do not touch `.specify/`; do not overwrite anything that differs by one byte.
- **Expected output**: Fresh install writes `exec bin/speckit-verify "$@"`; a hand-written file is untouched with a note.
- **Verification**: two scratch installs — one clean, one with a custom `scripts/verify` — asserting content in both.
- **Completion conditions**: the custom-file install prints the note and leaves the file's hash unchanged.
- **Risks / rollback**: Reversible by editing the installed file; no state outside the repo.

## T035: Change-scoped selection

- **Objective**: Select the checks a change can affect, and name what was selected.
- **Addresses requirement(s)**: FR-015, FR-017
- **Implements design decision(s)**: `git diff` plus manifest globs; an unmatched file is INCOMPLETE, never skipped.
- **Depends on**: T007, T010
- **Likely files**: `bin/speckit-verify`
- **Scope boundaries**: No heuristics beyond declared globs; no guessing a check for an unmatched file.
  A glob bounds a private module's effect, not `conftest.py`'s — the shared-file list widens to every
  check instead of guessing, and says so.
- **Expected output**: A one-file change selects the two checks whose globs match, prints the selection, and reports an unmatched file by name.
- **Verification**: fixture with two dependent test files; fixture with one file matched by nothing.
- **Completion conditions**: selected run names the selection; unmatched run exits 3; shared-file
  run prints `fallback:` and examines the whole suite (case `shared-file`).
- **Risks / rollback**: Selection is read-only; revert the file.

## T039: Coverage provenance

- **Objective**: A changed-line figure always says which profile produced it, and refuses the stronger reading.
- **Addresses requirement(s)**: FR-033, FR-034
- **Implements design decision(s)**: `--profile full|selected` is explicit; guessing is the defect the spec names.
- **Depends on**: T035
- **Likely files**: `bin/speckit-verify`
- **Scope boundaries**: Read `coverage.json`; never write it; no adapters beyond Python in this feature.
- **Expected output**: "changed lines reached n/m (profile: full)" and, for a selected profile, no sentence claiming a line is untested.
- **Verification**: full-profile fixture with one unexecuted new line; selected-profile fixture asserting the refusal.
- **Completion conditions**: property P-008 passes and fails when provenance is removed.
- **Risks / rollback**: Pure reporting; revert.

## T045: Candidate rendering

- **Objective**: Mutation output is a list a reviewer can act on, never a number to chase.
- **Addresses requirement(s)**: FR-020, FR-021
- **Implements design decision(s)**: Bounded candidates; a percentage is a budget beside the count, never a threshold.
- **Depends on**: T044
- **Likely files**: `bin/speckit-verify`
- **Scope boundaries**: No aggregate score in the verdict line; no exit code influenced by a percentage.
- **Expected output**: One line per candidate with file, line, operator, status; at most `mutation.limit`.
- **Verification**: fixture with three survivors and a limit of two prints two and says the list is bounded.
- **Completion conditions**: P-007's gate fixture passes; no `%` appears in a PASS/FAIL position.
- **Risks / rollback**: Reporting only; revert.

## T054: Block-stage requirements

- **Objective**: The blocking tier cannot run without a baseline, and cannot block on a stale one.
- **Addresses requirement(s)**: FR-025, FR-026
- **Implements design decision(s)**: Baseline + `rules_sha256` match + confirmed-live, all three.
- **Depends on**: T053
- **Likely files**: `bin/speckit-security`
- **Scope boundaries**: Do not add a rule class to the blocking set without a recorded baseline; do not block on pattern-only.
- **Expected output**: exit 3 without a baseline; exit 3 on a hash mismatch; exit 1 only for a confirmed-live finding on a baselined class.
- **Verification**: four fixtures — no baseline, stale baseline, pattern-only finding, confirmed-live finding.
- **Completion conditions**: property P-009 passes and fails when the baseline check is removed.
- **Risks / rollback**: The stage is opt-in; disabling is removing the CI step.

## T068: pass^k measurement

- **Objective**: Report single-attempt success, repeated-attempt success, and the pessimistic bound together.
- **Addresses requirement(s)**: FR-031, FR-032
- **Implements design decision(s)**: Both figures always; the bound is printed with an explanation of why it differs.
- **Depends on**: T004
- **Likely files**: `evals/run-passk.py`
- **Scope boundaries**: Stdlib only; no task runner, no model calls.
- **Expected output**: `pass@1`, empirical `pass^k`, Wilson interval, constant-p bound, one sentence on the gap.
- **Verification**: deterministic vector (equal figures) and a `p=0.8, k=5` vector (bound ≤ empirical).
- **Completion conditions**: P-012 passes; the deterministic case is exactly equal.
- **Risks / rollback**: Standalone script; delete to roll back.
```

## Task Rules

- Order tasks by dependency; keep them small enough to review in one pass.
- Put tests next to the behaviour they verify, not in a trailing phase.
- Every task traces to a requirement or an approved design decision.
- Do not create tasks for unapproved future work.
- Distinguish implementation, test, migration, documentation, and validation work.
- State the evidence that marks a task complete.
- Identify migrations and sequencing constraints explicitly.

## Property-Based Test Tasks

If `plan.md` carries a **Correctness Properties** table, every property gets exactly one
property-based test task.

- **One task per P-ID.** A property with no task is unbuilt. Do not batch several properties into
  one task — a failing property must point at a single task.
- **Trace both IDs.** Each such task states its `P-xxx` **and** the `FR-xxx` the property maps to,
  so a failure is traceable back to a requirement.
- **Name the framework the plan recorded — never one of your own choosing.** The plan's Framework
  decision is authoritative. Do not hardcode a framework name, and do not add a dependency the
  plan did not decide on.
- **Follow the fallback verbatim.** If the plan decided `fallback`, write example-based tests and
  say why in the task. Do not silently introduce property-based testing the plan rejected.
- **Co-locate.** A property test sits in the same phase as the story behaviour it covers — not in
  a trailing "testing" phase.

### Worked example

```markdown
## T009: Property test — expired tokens are always rejected

- **Objective**: Prove that any request with an expired token is rejected.
- **Addresses requirement(s)**: FR-004 (P-003)
- **Implements design decision(s)**: Plan's Framework decision — `adopt`, using the framework
  the plan recorded.
- **Depends on**: T007
- **Likely files**: the property-test file for this area
- **Scope boundaries**: Do not change token expiry semantics; test only.
- **Expected output**: Property `for any expired token, the response is 401`.
- **Verification**: the property test runs and passes; then break the guard and confirm it fails.
- **Completion conditions**: P-003 passes, and the property fails when the behaviour is removed.
- **Risks / rollback**: Test-only; revert the file.
```

A property test that cannot fail is not evidence. If removing the behaviour does not fail the
property, the property is wrong — fix the property before trusting it.

## Requirement Coverage

A requirement with no task is unbuilt. A task with no requirement is scope creep. Check
before starting, not after. Every property from `plan.md` appears here too: a P-ID with no task is
unbuilt, and a property-test task with no P-ID is scope creep.

| Requirement | Property | Tasks | Covered? |
| --- | --- | --- | --- |
| FR-001 | — (reporting obligation: examined total in the report and verdict) | T011, T019, T075 | ☐ |
| FR-002 | P-003 | T010, T019, T016 | ☐ |
| FR-003 | P-004 | T010, T020 | ☐ |
| FR-004 | — (configuration: `oracle` declaration is checkable, anchoring is not) | T007, T018 | ☐ |
| FR-005 | — (configuration: control command must fail) | T017 | ☐ |
| FR-006 | P-003 | T008, T019 | ☐ |
| FR-007 | P-006 | T022, T025 | ☐ |
| FR-008 | — (covered by P-006's refusal branch and an example fixture) | T023, T025 | ☐ |
| FR-009 | — (covered by an example fixture; a property would restate it) | T024 | ☐ |
| FR-010 | P-002 | T012, T030 | ☐ |
| FR-011 | — (schema contract, `contracts/ledger-record.schema.json`) | T012 | ☐ |
| FR-012 | P-002 | T030, T031 | ☐ |
| FR-013 | P-001 | T029, T028 | ☐ |
| FR-014 | — (writer refusal, example fixture) | T012 | ☐ |
| FR-015 | P-005 | T035 | ☐ |
| FR-016 | — (mode + scheduled job, documentation-checkable) | T036 | ☐ |
| FR-017 | P-005 | T035, T037 | ☐ |
| FR-018 | — (example fixture: both outcomes retained) | T038 | ☐ |
| FR-019 | — (configuration: opt-in and scoped) | T044 | ☐ |
| FR-020 | — (rendering, example fixture + P-007) | T045 | ☐ |
| FR-021 | P-007 | T045, T050 | ☐ |
| FR-022 | P-010 | T046 | ☐ |
| FR-023 | — (reporting branch, example fixture) | T048 | ☐ |
| FR-024 | — (ladder base, example fixture) | T053 | ☐ |
| FR-025 | P-009 | T054, T052 | ☐ |
| FR-026 | — (refusal branch, example fixture) | T056, T054 | ☐ |
| FR-027 | — (error mapping, example fixture) | T057 | ☐ |
| FR-028 | — (tier mapping, example fixture) | T057, T055 | ☐ |
| FR-029 | — (manifest field + rendering) | T061, T063, T065 | ☐ |
| FR-030 | — (falsification command, example fixture) | T062, T065 | ☐ |
| FR-031 | P-012 | T068 | ☐ |
| FR-032 | P-012 | T068 | ☐ |
| FR-033 | P-008 | T039 | ☐ |
| FR-034 | P-008 | T039, T040 | ☐ |
| FR-035 | P-009 | T055, T059 | ☐ |
| FR-036 | — (network tier, example fixture) | T055, T057 | ☐ |
| FR-037 | — (adapter + field, example fixture) | T064 | ☐ |
| FR-038 | P-011 | T047 | ☐ |
| FR-039 | — (mode label, example fixture) | T049 | ☐ |
| FR-040 | — (scheduled scan, documented + fixture) | T053 | ☐ |
| FR-041 | — (diff-aware stage, example fixture) | T058 | ☐ |
| FR-042 | — (report text, SC-009 fixture) | T059 | ☐ |
| FR-043 | P-013 | T077 | ☐ |

**Property coverage**

| Property | Requirement | Task | Check method |
| --- | --- | --- | --- |
| P-001 | FR-013 | T028 | property-test |
| P-002 | FR-010, FR-012 | T032 | property-test |
| P-003 | FR-002, FR-006 | T016 | property-test |
| P-004 | FR-003 | T020 | property-test |
| P-005 | FR-015, FR-017 | T034 | property-test |
| P-006 | FR-007 | T026 | property-test |
| P-007 | FR-021 | T050 | review-only — gate fixture |
| P-008 | FR-033, FR-034 | T040 | property-test |
| P-009 | FR-025, FR-035 | T052 | property-test |
| P-010 | FR-022 | T042 | property-test |
| P-011 | FR-038 | T043 | property-test |
| P-012 | FR-031, FR-032 | T067 | property-test |
| P-013 | FR-043 | T077 | property-test |

Every property task uses the plan's **fallback** decision: an example-based fixture plus a small stdlib generator, never a third-party property framework.
