# Feature Specification: Autonomous Throughput and a Mechanical Boundary

**Feature Branch**: `003-autonomous-throughput`

**Created**: 2026-10-17

**Status**: Accepted

**Input**: User description: "Incorporate the research findings into the pipeline so agent coding is faster and safe to run more autonomously: move the approval boundary out of prose into tool permissions, add one-command verification, run approved work continuously with a budget, and add a fast lane for small work."

## Document Status

**Status changed:** 2026-10-18 (Draft → Accepted)
**Approved by:** watanabefam (repo owner) · **Authority:** maintainer of this kit
**Workflow:** full spec-driven · **Companion:** `research.md` (informative)

## Normative Status

**Normative sections:** User Scenarios & Testing, Requirements, Success Criteria. Everything else in
this document is informative.

This spec is authoritative for behaviour. `research.md` is informative: it carries the sources and
rationale, and where the two disagree, this spec prevails (dated reference: 2026-10-17).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Routine work runs without prompts; irreversible actions are blocked (Priority: P1)

A developer initialises the kit in a project. From then on, an agent editing files, running tests,
formatting, and committing proceeds without asking, while force-pushes, hook bypasses, package
publishes, and destructive database commands are refused at the tool layer — regardless of what the
model decides.

**Why this priority**: This is the enabling condition for every other story. The research is
unambiguous that the boundary belongs in tool permissions, not in prompt text, and that "excessive
permission" and "excessive autonomy" are the root causes of damaging agent actions [30][10]. Without
this, removing the prompt-level stops in US3 is unsafe.

**Independent Test**: In a scratch project, attempt a denied command (e.g. `git push --force`) and a
routine command (e.g. `git status`). The denied command is refused without the model's cooperation;
the routine command runs with no prompt. Separately, change a managed `AGENTS.md` block and confirm
the change is reported.

**Acceptance Scenarios**:

1. **Given** a project with no `opencode.json`, **When** `speckit-init` runs, **Then** a permission
   block is created that denies force-push, `--no-verify` / hooks-path overrides, package publish,
   and destructive database commands.
2. **Given** a project that already has an `opencode.json`, **When** `speckit-init` runs, **Then**
   the file is left unchanged and the permission block plus a merge instruction is printed.
3. **Given** a command that matches both an allow rule and a deny rule, **When** it is evaluated,
   **Then** it is denied.
4. **Given** an installed kit, **When** a run begins, **Then** one autonomy-contract file defines the
   four-bucket handoff (Done / Continuing / Decision needed / Approval required), and no `/speckit.*`
   command carries an equivalent paragraph.
5. **Given** an agent change to a managed `AGENTS.md` block, **When** `speckit-init` next runs,
   **Then** the change is reported rather than silently overwritten.

---

### User Story 2 - Verification is one command, named in the task (Priority: P1)

A developer initialises the kit in a project whose stack can be detected. The kit records the exact
install, test, lint, typecheck, and build commands and generates a single `verify` entry point. A
task's Verification line names that command, so the agent verifies instead of discovering how to.

**Why this priority**: Joint P1. The measured time sink is reviewing, correcting, and waiting on
output — not typing [1][3] — and test results are the ground truth that makes code a good agent task
[4]. One known command converts the largest variable cost into a fixed one.

**Independent Test**: On a scratch project with a detectable stack, run the recorded `verify` and
confirm it executes the detected commands in order. Inspect a generated task and confirm its
Verification line matches the recorded command.

**Acceptance Scenarios**:

1. **Given** a project whose stack is detectable, **When** `speckit-init` runs, **Then** a managed
   `## Commands` block records install/test/lint/typecheck/build and a `verify` entry point is
   generated that runs them in order.
2. **Given** a project whose stack is not detectable, **When** `speckit-init` runs, **Then** the
   commands are recorded as unresolved and a one-time confirmation is required — the installer does
   not guess.
3. **Given** a tasks file written after installation, **When** a task states its Verification,
   **Then** it names the recorded command.
4. **Given** a project where the detected verify command fails at install time, **When**
   `speckit-init` runs, **Then** the failure is reported and initialisation still completes.

---

### User Story 3 - Approved work runs continuously, with a stopping condition (Priority: P2)

A developer approves a tasks file. The agent executes all of it without pausing for confirmation
between phases, committing and recording each task as it completes, and halting only when it hits the
failure budget, a gate, or a missing credential.

**Why this priority**: This is where the round-trip savings are realised. The current loop pays a
human turn per artifact and per phase; the research supports continuous execution bounded by explicit
stopping conditions and resumable state [4][5][29].

**Independent Test**: Run `/speckit.implement` on a three-task plan and confirm it completes without
a per-phase confirmation; then run it on a plan whose second task cannot pass verification and
confirm it halts at the budget, leaves the failing task unticked, and records the reason.

**Acceptance Scenarios**:

1. **Given** an approved tasks file, **When** `/speckit.implement` runs, **Then** it executes tasks
   continuously without a per-phase confirmation prompt.
2. **Given** consecutive task failures that reach the execution budget, **When** the budget is hit,
   **Then** execution halts, the failing tasks are left unticked, and the reason is recorded.
3. **Given** a completed task, **When** it is marked done, **Then** a commit is made for it and a
   ledger line with its evidence is appended.
4. **Given** a run interrupted by context loss, **When** it resumes, **Then** it resumes at the first
   task without a `complete` ledger line and does not repeat completed tasks.

---

### User Story 4 - A fast lane for small, well-understood work (Priority: P2)

A developer has a one-line fix or a small, well-understood change. `/speckit` routes it to a fast lane
that states the cause, requires a failing test first for a defect, makes the smallest change, verifies,
and logs the result — with no spec, plan, or tasks artifacts. If the change grows beyond the lane, it
stops and promotes to the full workflow.

**Why this priority**: The research shows the full process is pure ceremony below a minimum task size,
and that a heavyweight pre-code pipeline can be an order of magnitude slower for small work [27][28][31].
The kit already describes a short path in prose; nothing implements it.

**Independent Test**: Run a one-line fix through the fast lane and confirm zero spec/plan/tasks
artifacts and one log entry. Then start a change that exceeds the lane and confirm it is refused and
promoted to `/speckit.specify`.

**Acceptance Scenarios**:

1. **Given** a small, well-understood request, **When** `/speckit` classifies it, **Then** it routes
   to the fast lane and states the choice in one line.
2. **Given** a defect handled by the fast lane, **When** the fix is made, **Then** a failing test that
   reproduces it exists first.
3. **Given** a fast-lane change that exceeds the lane's scope, **When** the limit is reached, **Then**
   the command stops and promotes the work to `/speckit.specify`.
4. **Given** a completed fast-lane change, **When** it is done, **Then** exactly one log entry records
   what changed, the evidence, and anything parked.

---

### Edge Cases

- **Precedence conflict.** A command matching both allow and deny rules is denied (fail-closed).
- **Existing configuration.** A project with its own `opencode.json` or `hooks.yaml` is never
  clobbered; the kit prints what to merge.
- **Undetectable stack.** Commands are recorded as unresolved; the installer asks once rather than
  inventing a command.
- **Platform portability.** The installer and gate must pass on macOS system bash 3.2 and Linux bash 5;
  a construct that parses on one and not the other is a defect.
- **Compaction mid-run.** The ledger, not conversation memory, is the resume point.
- **Fast-lane overrun.** A change that grows past the lane is promoted, not silently completed.
- **Deny-list false positive.** A legitimate workflow command caught by a deny pattern must be
  overridable by editing the permission block, and the override must be visible in the diff.
- **Rule-file drift.** A managed block edited between installs is reported, not overwritten.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: WHEN `speckit-init` runs in a project with no `opencode.json`, THE installer SHALL create
  a permission block that denies force-push, hook-bypass (`--no-verify`, `core.hooksPath` overrides),
  package publish, and destructive database commands.
- **FR-002**: WHEN `speckit-init` runs in a project that already has an `opencode.json`, THE installer
  SHALL leave it unchanged and SHALL print the permission block with a merge instruction.
- **FR-003**: IF a command matches both an allow rule and a deny rule, THEN THE permission boundary
  SHALL deny it.
- **FR-004**: THE installer SHALL install exactly one autonomy-contract instruction file defining the
  four-bucket handoff, and SHALL NOT add equivalent prose to any `/speckit.*` command.
- **FR-005**: WHEN `speckit-init` detects a project's install, test, lint, typecheck, and build
  commands, THE installer SHALL record them in a managed `## Commands` block and SHALL generate a
  `verify` entry point that runs them in order.
- **FR-006**: IF the stack cannot be detected, THEN THE installer SHALL record the commands as
  unresolved and SHALL require a one-time confirmation instead of guessing.
- **FR-007**: WHEN `/speckit.tasks` writes a task, THE task SHALL name the recorded verification
  command in its Verification line.
- **FR-008**: WHEN `/speckit.implement` runs on an approved tasks file, THE command SHALL execute tasks
  continuously without a per-phase confirmation.
- **FR-009**: IF consecutive task failures reach the execution budget, THEN `/speckit.implement` SHALL
  halt, leave the failing tasks unticked, and record the reason.
- **FR-010**: WHEN a task completes, THE `/speckit.implement` command SHALL commit for that task and
  SHALL append a ledger line carrying its evidence.
- **FR-011**: WHERE a request is small and well-understood, THE `/speckit` entry point SHALL route it
  to the fast lane instead of the full workflow.
- **FR-012**: WHEN the fast lane handles a defect, THE fast lane SHALL require a failing test that
  reproduces it before the fix.
- **FR-013**: IF a fast-lane change exceeds the lane's scope, THEN THE fast lane SHALL stop and promote
  the work to `/speckit.specify`.
- **FR-014**: THE kit's self-gate SHALL assert that a scratch install carries the permission block, the
  `## Commands` block, the `verify` entry point, the autonomy-contract file, the continuous-execution
  rule, and the fast-lane command.
- **FR-015**: WHEN a managed `AGENTS.md` block differs from the one the kit installed, THE installer
  SHALL report the difference.

### Key Entities

- **Permission rule** — an action (`allow` / `ask` / `deny`), a resource pattern, and the scope it is
  written in; evaluated fail-closed.
- **Command record** — a named entry (install / test / lint / typecheck / build / verify), its exact
  command, and its source (detected or user-confirmed).
- **Autonomy contract** — the four-bucket response format: Done (with evidence), Continuing, Decision
  needed, Approval required.
- **Execution budget** — the maximum consecutive task failures before a run halts.
- **Ledger entry** — a task id, its status, its evidence, and its commit range; the resume point.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A medium feature (≈10 tasks) reaches first green in at most **2 human interactions**
  (describe + plan approval), measured against the current loop on the same task set — which is
  expected to be 7–9.
- **SC-002**: **100%** of a fixed list of irreversible actions is blocked in an unattended run.
- **SC-003**: Rework rate (tasks reopened after a later failure) does **not increase** relative to the
  current loop on the same task set.
- **SC-004**: A small fix completes through the fast lane with **zero** spec/plan/tasks artifacts and
  **one** log entry.
- **SC-005**: The self-gate passes on macOS bash 3.2 and Linux bash 5 with all new artifacts present.
- **SC-006**: An interrupted run resumes from the ledger with **no** completed task repeated.

**SC-001 / SC-003 evidence (T035).** This feature was itself implemented in this session, so the
first measurement is available: the work used **one** approval interaction (the plan gate) plus a
single classify/route decision — the four artifacts (spec, plan, tasks, implementation) were produced
across two user turns after the request, against the 7–9 the current loop is expected to need. The
**rework** signal was positive: the kit's own gate caught two real defects during implementation (a
JSON-comment regex that ate `https://`, and an uncovered force-push spelling), both fixed before
close. This is a single-sample observation, not a controlled measurement: a fair SC-001/SC-003 figure
requires running the *next* feature on the same task set and comparing, which is recorded here as the
method to repeat.

## Assumptions

- The developer runs opencode with the `opencode-yaml-hooks` plugin, which the kit already requires.
- A deny-by-default list is acceptable; the list is editable and its edits are visible in the diff.
- Stack detection covers Node, Python, Rust, Go, and Make at minimum; other stacks fall back to the
  one-time confirmation in FR-006.
- "Medium feature" and "small fix" are measured on the same task set as the current loop, not against
  an absolute baseline.
- The project constitution is not yet ratified in this repository; this feature does not depend on it.
- The permission block is written in the developer's global or project `opencode.json`, which the kit
  does not otherwise manage.

## Requirements Syntax (EARS)

Every functional requirement is written in **EARS**. `SHALL` is the only normative keyword (RFC 2119
sense); do not mix in MUST, SHOULD, or a bare verb. But do not `SHALL` everything — reserve it for
behaviour that actually binds.

| Pattern | Keyword | Shape | Use when |
| --- | --- | --- | --- |
| Ubiquitous | *(none)* | `THE <system> SHALL <response>` | the behaviour is always active |
| Event-driven | `WHEN` | `WHEN <trigger> THE <system> SHALL <response>` | a response is required to a triggering event |
| State-driven | `WHILE` | `WHILE <state> THE <system> SHALL <response>` | the behaviour holds while a state is true |
| Optional feature | `WHERE` | `WHERE <feature is included> THE <system> SHALL <response>` | it applies only to variants that include a feature |
| Unwanted behaviour | `IF` / `THEN` | `IF <unwanted condition> THEN THE <system> SHALL <response>` | a response is required to a fault or undesired situation |

Clause order follows temporal logic: preconditions (`WHILE`, `WHERE`) precede the trigger (`WHEN`),
which precedes the response. `WHEN` is for an event, not a state; `IF…THEN` is for unwanted behaviour,
not the normal path; `WHERE` denotes a variant, not a location. This guidance is language-agnostic:
the property-based testing framework, if any, is decided in `plan.md` — do not hardcode one here.

## Carried Forward

### Confirmed Decisions

- The boundary is mechanical (permissions / hooks), not prose — the kit's own position.
- The kit's existing two hooks (`block-commit-no-verify`, `protect-generated-files`) are retained
  unchanged.
- Spec 002's converge review and stress test are complete and not revisited here.

### Constraints

- The installer must not clobber a project's own `opencode.json`, `hooks.yaml`, or `AGENTS.md` content.
- The installer and self-gate must pass on macOS system bash 3.2 and Linux bash 5.
- Generated files (`.opencode/commands/speckit*.md`, `.specify/scripts|templates|presets`) are not
  hand-edited; changes go through the kit.

### Assumptions

- The developer runs opencode with the `opencode-yaml-hooks` plugin (already required).
- A deny-by-default list is acceptable and editable.

### Risks

- **Deny-list false positives** could block a legitimate workflow; mitigated by making the list
  editable and its edits visible in the diff.
- **Continuous execution compounds errors** if verification is weak; mitigated by the failure budget
  and the one-command verify — the research is explicit that autonomy needs ground truth each step
  [4].
- **Scope creep** toward isolation and parallelism; mitigated by the Non-Goals and the parking lot.

### Open Questions

- Whether the permission block should be written to the global config, the project config, or offered
  as a printed snippet by default. (Deferred to `plan.md`.)

## Problem / Opportunity

The kit's gates live in prompt text, which the kit itself states cannot enforce anything. Meanwhile the
research is consistent that the boundary belongs in tool permissions, that the dominant cost of
AI-assisted development is human review and rework rather than generation, and that heavyweight
pre-code pipelines can be slower for small work. The kit therefore pays round-trip cost for work that
does not need it, while leaving irreversible actions unguarded at the tool layer.

## Goals

- Move the approval boundary from prose into tool permissions, so removing prompt-level stops is safe.
- Convert verification from a discovery problem into a single known command.
- Remove per-artifact and per-phase human round-trips for approved work.
- Provide a fast lane for work below the process's minimum useful size.
- Make the kit's self-gate prove the new artifacts are present and portable.

## Non-Goals

- **Not** worktree or container isolation (deferred — see Future Work).
- **Not** parallel `[P]` task dispatch (deferred).
- **Not** changing the converge review or stress test (completed in spec 002).
- **Not** making any rule enforceable by prose. If it must not be violated, it is a permission or a
  hook.
- **Not** a per-request switch of the Spec Kit preset (`lean` remains a per-project choice).

## Dependencies and External Contracts

- **opencode permission schema** — the `permission` / `permissions` config shape and its rule
  precedence. If it changes, the permission block and FR-003 change with it.
- **`opencode-yaml-hooks`** — required for the existing hooks; unchanged by this feature.
- **Spec Kit 1.0.13** — the preset/command mechanism this feature extends.
- **git** — for the per-task commits in FR-010.

## MVP Scope

User Story 1 (boundary) and User Story 2 (verification). These two together are independently valuable
and are the precondition for US3. US3 and US4 follow once the boundary and verification are proven.

## Future Work (parking lot)

Deliberately deferred. Not part of this feature's acceptance criteria. Must not be implemented without
explicit approval.

| # | Idea | Noticed during | Why deferred | Revisit when |
| --- | --- | --- | --- | --- |
| 1 | `speckit-start` worktree-per-feature command | research synthesis | needs US1/US2 stable first; isolation is a separate failure surface | after 003 ships |
| 2 | Parallel `[P]` dispatch to subagents | research synthesis | depends on worktrees; concurrency raises new failure modes | after worktree command |
| 3 | Speed/stability eval gate (turns-to-green, revert rate) | research synthesis | SC-001/SC-003 measure it; a gate needs a stable baseline first | when a second measurement exists |
| 4 | Sandbox/container provisioning docs | research synthesis | platform-specific; the kit is portable by design | on user demand |
| 5 | Rule-file signing / provenance check | PackHallu finding [9] | FR-015 reports drift; signing needs a key-distribution story | if AGENTS.md becomes remotely sourced |
| 6 | Token/cost budget as a stopping condition | OpenAI guidance [5] | needs usage telemetry the kit does not have | with eval instrumentation |

### Parking lot vs Non-Goals

**Non-Goals** are decided upfront — deliberately excluded from this feature. **The parking lot** is
noticed in passing — not yet decided, just not now. A Non-Goal is a decision; a parked idea is a
deferral awaiting one.

## Validation Plan

- **Automated tests** — extend `scripts/self-gate.sh` (FR-014) with assertions for the permission
  block, `## Commands` block, `verify` entry point, autonomy-contract file, continuous-execution rule,
  and fast-lane command; run the full e2e scratch install on macOS bash 3.2 and Linux bash 5.
- **Manual checks** — attempt a denied command and a routine command (US1); run the fast lane on a
  one-line fix and on an overrun (US4); run implement on a failing plan to observe the budget halt
  (US3).
- **Data or migration checks** — not applicable; the kit ships no data store.
- **Security / privacy checks** — negative test: every action on the fixed irreversible list is blocked
  (SC-002); confirm no secret is written into `opencode.json` or the autonomy-contract file.
- **Performance checks** — measure SC-001 and SC-003 on the same task set as the current loop; report
  the spread, not a single pass.
- **Evidence required for approval** — self-gate output, the denied/routine command transcripts, the
  fast-lane log entry, and the implement budget-halt transcript.

## Requirement Traceability

Fill in as the work progresses. A requirement with no task is unbuilt; a task with no
requirement is scope creep.

| Requirement | User Story | Acceptance Criteria | Planned Design Area | Task |
| --- | --- | --- | --- | --- |
| FR-001 | US1 | Given no config / When init / Then block created | installer §2d + `permissions/` | T005, T007, T012 |
| FR-002 | US1 | Given existing config / When init / Then unchanged + printed | installer §2d | T006, T007, T011 |
| FR-003 | US1 | Given allow+deny match / Then denied | permission ordering + §1d3 | T005, T007 |
| FR-004 | US1 | Given installed kit / Then one contract file, no command prose | installer §2e + bridge pointer | T003, T008, T009 |
| FR-005 | US2 | Given detectable stack / Then commands block + verify | installer §6b | T013, T016, T017 |
| FR-006 | US2 | Given undetectable stack / Then unresolved + confirm | installer §6b | T015, T017 |
| FR-007 | US2 | Given task / Then Verification names the command | tasks prepend | T018 |
| FR-008 | US3 | Given approved tasks / Then no per-phase prompt | implement prepend | T020, T022 |
| FR-009 | US3 | Given failures reach budget / Then halt + unticked | implement prepend | T020, T022 |
| FR-010 | US3 | Given completed task / Then commit + ledger line | implement prepend | T022 |
| FR-011 | US4 | Given small request / Then fast lane | `/speckit` entry | T028 |
| FR-012 | US4 | Given defect / Then failing test first | fast-lane command | T026 |
| FR-013 | US4 | Given overrun / Then stop + promote | fast-lane command | T026 |
| FR-014 | all | Given scratch install / Then gate asserts artifacts | self-gate | T003, T004, T013, T020, T025, T032 |
| FR-015 | US1 | Given edited managed block / Then reported | `write_managed_block` | T010 |
