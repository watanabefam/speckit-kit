# Feature Specification: Verification Integrity — a Green Result Must Be Earned

**Feature Branch**: `005-verification-integrity`

**Created**: 2026-10-22

**Status**: Draft (awaiting owner approval)

**Input**: User description: "Research iteratively until convergence whether existing tools would take software work to production quality unattended or should be incorporated; validate the plan; then write the spec."

## Document Status

**Workflow:** full spec-driven · **Companion:** `docs/research/verification-tooling-2026-10.md` (informative; 452 lines, five validation rounds, §10 authoritative)
**Normative sections:** User Scenarios & Testing, Requirements, Success Criteria.
**Relationship to 004:** `004-reliability-hardening` repaired the *kit's own* gate (its recursion, its skips, its ledger trust). This feature addresses a different subject: whether a **downstream project's** verification report means anything. Where the two overlap, 004's three-state verdict (`scripts/self-gate.sh:1477-1490`) is the precedent to copy, not to change.

## Problem / Opportunity

Five rounds of validation (literature + upstream source + local measurement on this machine) converged on one finding: **the dominant failure mode of automated verification is not a missed bug — it is a report that says "pass" without having examined anything.**

Measured locally, on this machine, during research:

- A 31-mutant run over a module at **100% line coverage** left **11 of 18 mutants alive**. Coverage said "done"; behaviour said otherwise.
- `pytest` with **zero collected tests exits 5** — a state most wrappers report as "not a failure". Nothing ran, nothing was checked, and no number was printed.
- A comparable tool (SpecWeave 3.1.5) accepted `--evidence "reviewed it myself, looks fine"` with **no command executed**, returning success; and with no acceptance criteria declared it printed `ACs 0/0` and **passed**.
- Two independent 2026 papers name the same two vacuity classes: *examined nothing* ("vacuous pass") and *compared the code to itself* ("oracle anchoring").
- A pinned security scanner suite missed a hand-written production password in **8 of 8** probe variants; the ones that fired only recognised **vendor token shapes**. False-positive rates for secret scanners in the literature run **25–99%**.

The kit cannot presently distinguish "verified" from "did not look". This feature makes a green result cost something.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A green result cannot come from nothing (Priority: P1)

An owner runs the project's verification command on a change that adds no tests, or on a harness whose check compares the code to itself. The command refuses to report success and says what was examined and what was not. The owner never again reads "pass" as "checked".

**Why this priority**: This is the whole thesis. It is independent of every other story, costs almost nothing to build, and all later detection work is worthless while a vacuous pass is possible.

**Independent Test**: Run the verification command against four fixtures — zero tests, a check whose oracle is the implementation, a harness with a skipped section, and a clean negative control — and confirm each produces a distinct non-green outcome with a nonzero exit.

**Acceptance Scenarios**:

1. **Given** a project with collected tests equal to zero, **When** verification runs, **Then** it reports "nothing was examined" as a distinct state and exits nonzero.
2. **Given** a check whose expected value is computed by the same code it is testing, **When** verification runs, **Then** the oracle-anchoring guard flags it and does not count it as evidence.
3. **Given** an optional tool is absent so a section is skipped, **When** the full report is printed, **Then** the verdict reads `INCOMPLETE` and never `PASS`, and a strict mode exits nonzero.
4. **Given** a deliberately broken fixture (negative control), **When** verification runs, **Then** it fails — proving the harness can still detect failure.

---

### User Story 2 - The report counts what it checked against the plan (Priority: P1)

An owner asks "is this feature actually done?" and gets a number, not an adjective. Each acceptance criterion is either evidenced or listed as unproven; a plan with **zero** criteria refuses to report completion.

**Why this priority**: Same principle as US1 on a second axis. It closes the specific hole measured in a comparable tool (`ACs 0/0` → pass) and needs no new infrastructure.

**Independent Test**: Run against a spec with three criteria of which one is evidenced, and against a spec with no criteria at all; confirm `1/3` with named gaps in the first case, and refusal in the second.

**Acceptance Scenarios**:

1. **Given** a spec with no acceptance criteria section, **When** completion is reported, **Then** the report refuses and names the missing section.
2. **Given** a task that cites an acceptance criterion ID that does not exist, **When** the tally runs, **Then** it is an error, not a silently uncounted task.
3. **Given** a spec with five criteria and three evidenced, **When** the tally runs, **Then** the report shows `3/5` and names the two gaps.

---

### User Story 3 - The evidence trail survives being merged (Priority: P2)

Two people work in parallel and both append verification results. After merging, every result is still present exactly once, in a defensible order, and the history cannot be quietly rewritten.

**Why this priority**: The record is the only thing standing between "we verified it" and "we think we verified it" across time. But it is plumbing — valuable only once US1/US2 exist.

**Independent Test**: Append records on two branches, merge them, and confirm no record is lost, none is duplicated, and the read order is chronological; then attempt an in-place edit and confirm it is rejected.

**Acceptance Scenarios**:

1. **Given** two branches each appending results, **When** they are merged, **Then** all records survive and read order is by timestamp, not file-append order.
2. **Given** a record edited in place, **When** verification reads the trail, **Then** the tampering is detected and reported.
3. **Given** two records share an identifier, **When** the check runs, **Then** it fails in CI rather than letting one shadow the other.
4. **Given** a result record, **When** it is inspected, **Then** it identifies the command run, its exit code, and a content fingerprint — never prose alone.

---

### User Story 4 - Verification cost tracks the size of the change (Priority: P2)

A one-file change is verified against the tests that can plausibly be affected, in seconds; the full suite still runs on a schedule. The report says "changed tests pass", never "all tests pass".

**Why this priority**: The kit's own gate takes ~3.5 minutes; making that the price of every change is how owners learn to skip verification. But speed must not buy false confidence.

**Independent Test**: Change one module, run the selected set, and compare both time and result against a full run on the same commit; confirm the report's wording is scoped to the selection.

**Acceptance Scenarios**:

1. **Given** a change to one module with two dependent test files, **When** verification runs in default mode, **Then** only those files run and the report names the selection.
2. **Given** a full run is requested, **When** it completes, **Then** the report may claim full coverage of the suite, and only then.
3. **Given** a selection that misses a failing test elsewhere, **When** the report prints, **Then** it does not imply the whole suite is green.
4. **Given** a test fails once and passes on a single re-run, **When** the result is recorded, **Then** it is labelled as flaky-and-classified, not as either a pass or a failure.
5. **Given** lines were added or changed, **When** verification runs, **Then** it reports how many changed lines the executed tests actually reached and how many they did not — new code exercised by no test is "looked at nothing", scoped to the change.

---

### User Story 5 - Mutation results are review prompts, not a percentage (Priority: P3)

An owner runs the expensive check on changed files and gets a short list of specific, named weaknesses: "this comparison could be inverted and no test would notice". They do not get a score to chase.

**Why this priority**: High value, high cost, and the evidence says a threshold gate is counterproductive. It depends on US4's change set.

**Independent Test**: Run on a fixture with one surviving mutant, and confirm the output is one named finding pointing at a line and an operator, with no aggregate percentage shown as a target.

**Acceptance Scenarios**:

1. **Given** changed files, **When** mutation mode runs, **Then** output is a bounded list of named survivors, each with file, line, and operator.
2. **Given** the run completes, **When** the summary prints, **Then** no percentage is presented as a pass/fail threshold.
3. **Given** a mutant that is behaviourally identical to the original, **When** results are assembled, **Then** it is labelled equivalent-or-unknown rather than counted as a weakness.
4. **Given** the feature is not requested, **When** normal verification runs, **Then** mutation analysis does not run at all.

---

### User Story 6 - Security scanning is staged so it can be trusted (Priority: P3)

An owner turns on security scanning without drowning in alerts. The first stage only observes and records a baseline; blocking begins only on high-confidence classes, after the false-positive rate is known.

**Why this priority**: Real value, but the literature's 25–99% false-positive range makes an immediate blocking gate actively harmful — it teaches the owner to ignore it.

**Independent Test**: Run the observer stage on a known-clean project and confirm it blocks nothing and records a baseline; run the blocking stage and confirm it fails on a high-confidence class and passes a clean tree.

**Acceptance Scenarios**:

1. **Given** the first stage, **When** findings occur, **Then** nothing blocks and a baseline is recorded with counts by rule.
2. **Given** the tool reports an internal error, **When** the stage finishes, **Then** it reports "scan failed", never "clean".
3. **Given** the rule set is not pinned, **When** the scan starts, **Then** it refuses rather than fetching a floating default (a measured failure mode).
4. **Given** the project needs network access to resolve dependencies, **When** offline mode is requested, **Then** the network-dependent tier is reported as not-run, not as clean.
5. **Given** a credential-shaped match that a provider can confirm or deny, **When** the confirmation tier runs, **Then** confirmed matches are labelled live and pattern-only matches are never labelled confirmed.

---

### User Story 7 - Generated tests are aimed by the specification (Priority: P3)

An owner asks for property-based tests and gets tests that encode the spec's actual rules, each traceable to the rule it came from, plus a demonstration that the property can fail.

**Why this priority**: The measured gain comes from grounding in the spec, not from the test technique; without that grounding the output is generic and unverifiable.

**Independent Test**: Generate from a spec with two stated rules and confirm two properties, each naming its rule, and one deliberately falsifiable example.

**Acceptance Scenarios**:

1. **Given** a spec stating a conservation rule, **When** properties are generated, **Then** each property names the rule it encodes.
2. **Given** a generated property, **When** it is first run, **Then** a known-failing input demonstrates that it can fail.
3. **Given** a property fails, **When** the report prints, **Then** the minimized counterexample is shown verbatim.
4. **Given** a service with a machine-readable interface description, **When** property checks are requested, **Then** a schema-driven instance is offered and its findings name the operation they came from.

---

### User Story 8 - Reliability is measured, not assumed (Priority: P3)

An owner learns that a check passing once is not the same as a check that passes every time, and sees both numbers side by side.

**Why this priority**: Cheap, standalone, and it corrects a misreading the kit's own documentation risks causing. Not blocking for anything else.

**Independent Test**: Run the same task set five times at a known success rate and confirm both the single-attempt and repeated-attempt figures are reported, with the worst-case bound shown.

**Acceptance Scenarios**:

1. **Given** a task set and five repetitions, **When** the measurement runs, **Then** both single-attempt and five-repetition success are reported.
2. **Given** a deterministic task set, **When** measured, **Then** both figures are equal.
3. **Given** reported figures, **When** displayed, **Then** the pessimistic all-tasks-equally-hard bound accompanies the empirical number and the difference is explained.

---

### Edge Cases

- **Zero collected tests, zero declared criteria, and zero changed files at once**: the report must say "nothing to verify" and exit nonzero, never green.
- **A skipped section plus a genuine failure**: failure dominates; the verdict is `FAIL`, not `INCOMPLETE`.
- **A check that examines something but cannot fail** (a constant-true assertion): treated as vacuous; the negative control is what exposes it.
- **Trail merged with clock skew**: ordering falls back to record order and the ambiguity is reported rather than hidden.
- **Mutation run on a file with no tests**: reported as "unmeasured", not "0% mutated" and not "100% clean".
- **Scanner present but rule set missing offline**: not-run, distinct from clean.
- **Selected test file deleted between selection and execution**: reported as an error, not a silent skip.

## Requirements *(mandatory)*

### Functional Requirements

**Vacuity (US1)**

- **FR-001**: Every verification run MUST report the number of items examined (tests executed, assertions evaluated, criteria checked).
- **FR-002**: A run examining zero items MUST NOT report success and MUST exit nonzero.
- **FR-003**: The system MUST distinguish a "skip" state from a pass in its verdict, following the three-state precedent in `scripts/self-gate.sh:1477-1490`.
- **FR-004**: The system MUST detect a check whose expected value is produced by the code under test, and MUST exclude it from evidence.
- **FR-005**: Each mandatory check MUST declare a negative control — a known-bad input it is expected to reject — and the control's rejection MUST be reported.
- **FR-006**: A test-runner exit code indicating "no tests collected" MUST map to the zero-examined state, not to success.

**Criteria tally (US2)**

- **FR-007**: Completion reports MUST show evidenced criteria as `n/m` and MUST name each unevidenced criterion.
- **FR-008**: The system MUST refuse to report completion when `m` is zero.
- **FR-009**: A reference to a nonexistent criterion identifier MUST be an error.

**Evidence trail (US3)**

- **FR-010**: Each verification result MUST be appended as a single immutable record; existing records MUST NOT be edited or reordered.
- **FR-011**: Each record MUST carry a unique identifier, a timestamp, the command executed, its exit code, and a content fingerprint.
- **FR-012**: Duplicate identifiers MUST fail a check that runs before merge or in CI.
- **FR-013**: Reading the trail MUST order by timestamp, independent of merge order.
- **FR-014**: Free-text evidence without an executed command and exit code MUST NOT satisfy a requirement.

**Change-scoped verification (US4)**

- **FR-015**: Default verification MUST select a subset based on the change set and MUST name what was selected.
- **FR-016**: A full-suite mode MUST exist and MUST be runnable on a schedule.
- **FR-017**: Reports from a selected run MUST state that the selection — not the whole suite — is green.
- **FR-018**: A test that fails then passes on one re-run MUST be recorded as classified-flaky, with both outcomes retained.

**Mutation as review (US5)**

- **FR-019**: Mutation analysis MUST be opt-in and MUST be scoped to changed files.
- **FR-020**: Output MUST be a bounded list of named survivors with location and operator.
- **FR-021**: No mutation percentage MUST be presented as a pass/fail threshold.
- **FR-022**: Behaviourally equivalent or unclassified mutants MUST be labelled as such and MUST NOT count as weaknesses.
- **FR-023**: A module with no tests MUST report "unmeasured" rather than a ratio.

**Security ladder (US6)**

- **FR-024**: Scanning MUST support an observe-only stage that records a baseline by rule and blocks nothing.
- **FR-025**: A blocking stage MUST be limited to high-confidence classes and MUST NOT be enabled before a baseline exists.
- **FR-026**: Rule sets MUST be pinned and committed; an unpinned default MUST be refused.
- **FR-027**: Tool-internal errors MUST NOT be reported as clean.
- **FR-028**: Network-dependent checks MUST report "not-run" in offline mode, never clean.

**Specification-grounded tests (US7)**

- **FR-029**: Generated properties MUST name the specification rule each one encodes.
- **FR-030**: Each generated property MUST be accompanied by a demonstration that it can fail.

**Reliability measurement (US8)**

- **FR-031**: The system MUST report single-attempt and repeated-attempt success separately.
- **FR-032**: The pessimistic constant-difficulty bound MUST accompany the empirical repeated-attempt figure, with the difference explained.

### Requirements added by the incorporation audit (2026-10-22)

These came from re-examining the tool sweep rather than from the verification rounds. They sharpen
existing stories instead of adding a ninth. Source: `docs/research/incorporation-decisions-2026-10.md`.

*Change-scoped verification (US4)*

- **FR-033**: A selected run MUST report how many changed lines the executed tests reached, and how many they did not.
- **FR-034**: A changed-line result MUST NOT be presented as coverage of the file, the module, or the project.

*Security ladder (US6)*

- **FR-035**: A finding that a provider can confirm live MUST be distinguished from a pattern-only match, and a pattern-only match MUST NEVER be labelled confirmed.
- **FR-036**: Credential confirmation MUST live in the network-enabled tier and MUST report not-run when offline, never clean.

*Specification-grounded tests (US7)*

- **FR-037**: Where a machine-readable interface description exists, a schema-driven property instance MUST be offered, and its findings MUST name the operation that produced them.

### Key Entities

- **Verification Result**: one immutable record — identifier, timestamp, what ran, exit code, fingerprint, examined-count, verdict (`PASS`/`FAIL`/`INCOMPLETE`/`NOT-RUN`).
- **Criteria Tally**: the set of acceptance criteria in a spec, each with evidenced/unproven state and its evidence references.
- **Change Set**: the files modified relative to a base, from which the selected check set is derived.
- **Mutant Finding**: file, line, operator, status (survived / killed / equivalent-or-unknown), and whether the module was measurable at all.
- **Baseline**: the recorded per-rule finding counts a stage compares against before it may block.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Across four vacuity fixtures (zero tests, self-referential oracle, skipped section, clean control), **zero** produce a green verdict; the clean control still passes.
- **SC-002**: **100%** of completion reports contain an `n/m` tally with `m > 0`, or refuse to report.
- **SC-003**: A hundred simulated parallel-merge rounds produce **zero** lost, duplicated, or order-ambiguous records.
- **SC-004**: Default verification on a single-file change completes in **≤25%** of the full-suite time (baseline: full gate ≈3.5 minutes).
- **SC-005**: The blocking security stage is not enabled for any rule class whose measured false-positive baseline has not been recorded.
- **SC-006**: Reliability reporting shows both figures on every run; a deterministic task set yields them **equal**.
- **SC-007**: Every claim in this feature's evidence trail is either a citation or a measurement reproducible with a recorded command — **zero** unsourced assertions in the research companion.
- **SC-008**: **100%** of change-scoped runs report changed-line reachability; a change whose new lines no test executes is reported as unexercised, not as verified.
- **SC-009**: **Zero** pattern-only credential matches are labelled confirmed across the full fixture set.

## Out of Scope

Deliberately excluded, with reasons recorded in the research companion §10:

- **Model-as-judge *verdicts*** — a model returning pass/fail **as the gate**. Verdicts flip on harmless reordering (~13.6%), which makes it unfit to decide a gate. **This is not a rejection of a reviewer that files findings** for a human to act on (cc-sdd's independent reviewer; SpecWeave's `review` returning `0` ship / `3` fix-first) — different mechanism, different failure mode. That belongs to `specs/006-workflow-orchestration/`, not here.
- **A second spec framework alongside this one** — marker collisions make coexistence unsafe.
- **Bundled third-party eval frameworks** — the measurement we need is ~30 lines.
- **Test-to-criterion traceability matrices** — no empirical support found for improved fault detection.
- **Mutation percentage thresholds** — contradicted by industrial practice and by the equivalent-mutant rate.
- **Blocking on secret scanning** — vendor-shaped tokens only; a design rule (secrets come from the environment) is the real control.

## Evidence Base

Full citations, measurements, and the five validation rounds: `docs/research/verification-tooling-2026-10.md` §6 (measurements), §10 (validation table and corrections). This spec states *what* and *why*; that document carries the *how we know*.

## Assumptions

- The kit's existing installer and command surface are the delivery mechanism; no new package manager or runtime dependency is introduced.
- Optional tools remain optional: absence produces `NOT-RUN`/`INCOMPLETE`, never a failure that blocks work on a machine that cannot install them.
- Downstream projects may use any language; the vacuity guard must be expressible per-runner rather than assuming one test framework.
- The owner prefers a smaller true signal over a larger noisy one; the staged security ladder and the no-threshold mutation rule both encode this.
- `scripts/verify` in this repository has **not yet** been measured against FR-001/FR-002; establishing that baseline is the first implementation task, not an assumption of current correctness.
