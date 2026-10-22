# Feature Specification: Workflow Orchestration — Unattended Work That Cannot Collide

**Feature Branch**: `006-workflow-orchestration`

**Created**: 2026-10-22

**Status**: Draft (awaiting owner approval)

**Input**: User description: "Keep 005 as the integrity cluster, run the incorporation audit, then a 006 for the workflow cluster."

## Document Status

**Workflow:** full spec-driven · **Companion:** `docs/research/incorporation-decisions-2026-10.md` (the audit that produced every item below)
**Normative sections:** User Scenarios & Testing, Requirements, Success Criteria.

**Revised**: 2026-10-22 after `docs/research/spec-vs-research-check-2026-10-22.md` (findings H-04, H-05,
M-09…M-12, L-06…L-09).

**Relationship to 005:** `005-verification-integrity` answers *"does a green result mean anything?"* This
spec answers *"can two unattended workers run at once without destroying each other's work, and can the
work survive being stopped?*" 005 is useful alone, and so is 006 — with **one** exception, stated here
rather than hidden: FR-007 needs a definition of "evidence that a check ran", and it takes that definition
from 005 FR-001…FR-005. That is a *definition* dependency, not a shipping order: if 005 has not landed,
FR-007 falls back to "an executed command with a recorded exit code and a nonzero count of items examined",
which is exactly what 005 makes precise. Everything else here is independent.

## Problem / Opportunity

The audit found that four projects dismissed in an earlier one-line table carry distinct, adoptable
mechanics. This kit executes its verification doctrine and ships none of the orchestration mechanics
below, while each of the four ships at least one. Orchestration is the part that does not matter while
one agent works alone, and matters completely the moment two do, or the moment a session stops early.

Measured and read evidence for each problem below:

- **Two lanes collide silently.** Nothing in the kit declares that a task is being worked. SpecWeave
  ships `task claim` precisely because its `pickup` needs to show *claims held by others*.
- **Work is lost when a session stops.** SpecWeave's `handoff` exists because sessions run out of
  context or tokens mid-task: it releases claims, records *why you stopped*, and pushes the branch plus
  a snapshot of uncommitted edits. The kit has no equivalent, and for this owner — who works with agents
  and hits limits — that is the most common interruption.
- **Task boundaries are advisory at most.** cc-sdd makes them structural: a File Structure Plan in
  `design.md` drives task boundaries, tasks carry `_Boundary:_` and `_Depends:_`, and review looks for
  **boundary violations** — not style. The kit's `plan.md` lists tasks with no statement of what each
  one may touch.
- **Test-first is advice, so it is skipped under pressure.** superpowers enforces it as a mechanic —
  *"Deletes code written before tests"* — and still gates the whole thing behind a flag, conceding that
  test-first is not always wanted.
- **Review is rejected or unbounded.** An earlier verdict rejected "model-as-judge" and, too broadly,
  the reviewer alongside it. cc-sdd runs an independent reviewer per task with two stages (spec
  compliance first, then code quality); SpecWeave runs a fresh context or **another model family**, cites
  `path:line`, and returns **exit 3** for "fix first" — a third state, not a verdict.
- **Spec files are rewritten instead of amended.** OpenSpec records a change as `## ADDED Requirements`
  deltas and archives it by date (`changes/archive/2025-01-23-add-dark-mode/`). The kit's answer to a
  changed requirement is to edit `spec.md` in place, erasing what the requirement used to be.
- **Working on a broken baseline.** superpowers verifies a clean test baseline *before* starting work.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Two workers cannot collide (Priority: P1)

Two agents are set to work the same plan at the same time. Each announces the task it is taking before
touching anything; the second one is told the task is held, and moves to something it is allowed to do.
No file is edited by both.

**Why this priority**: This is the safety core. Everything else in this spec is convenience; this one
prevents corruption, and corruption discovered later is unrecoverable — the two edits are already merged.

**Independent Test**: Start two workers from separate checkouts against one plan and confirm the second
either takes a different task or refuses, with the first worker's held tasks named; confirm a task
declaring a boundary is refused when its edits fall outside it; and confirm that when both declare the
same unclaimed task at once, one declaration succeeds and the other fails with a readable error rather
than overwriting it.

**Acceptance Scenarios**:

1. **Given** a task already claimed by worker A, **When** worker B attempts to claim it, **Then** B is refused and told who holds it.
2. **Given** a task declares the files it may touch, **When** an edit falls outside that set, **Then** the edit is reported as a boundary violation and the task is not recorded complete.
3. **Given** two tasks with a stated dependency between them, **When** the dependent task is claimed first, **Then** it is refused until its dependency is complete.
4. **Given** a claim exists and the worker disappears, **When** a second worker starts, **Then** the stale claim is visible as stale, with its age, and can be reclaimed with the takeover recorded rather than silently overwritten.
5. **Given** two workers in separate checkouts declare the same unclaimed task at the same instant, **When** both declarations execute, **Then** exactly one succeeds and the other fails on a precondition, never both.
6. **Given** two workers hold two different tasks, **When** they work, **Then** each works in its own checkout and neither writes into the other's working tree.

---

### User Story 2 - Work survives being stopped (Priority: P1)

An owner runs out of context or tokens mid-task. They stop with one word; the claims are released, the
reason is recorded, and the branch plus unfinished edits are preserved. In another tool, or on another
machine, they pick it up and are handed the next task with its acceptance criteria — with nothing to
copy or paste.

**Why this priority**: The kit's whole promise is unattended runs, and an unattended run that cannot be
resumed is a run that gets abandoned. This is the most frequent real interruption for this owner.

**Independent Test**: Stop mid-task, then resume in a fresh session with no state carried in memory, and
confirm the next task and its criteria are printed, the unfinished edits are present, and the released
claims are visible.

**Acceptance Scenarios**:

1. **Given** work in progress with uncommitted edits, **When** the owner stops, **Then** claims are released, a reason is recorded, and the edits are preserved for the next session.
2. **Given** a handoff happened, **When** work resumes in a different tool or machine, **Then** the next task and its acceptance criteria are printed without the owner restating scope.
3. **Given** an interrupted task, **When** it is resumed, **Then** it is clear whether the interruption left the work in a verified state or not.
4. **Given** a resumed session, **When** it reports status, **Then** it distinguishes work that existed before the interruption from work done after it.
5. **Given** a handoff snapshot would carry a credential-shaped string, **When** it is written or pushed, **Then** the string is redacted and the handoff says so, and if redaction cannot run nothing is pushed.

---

### User Story 3 - Test-first is a mechanic, not a request (Priority: P2)

An owner asks for test-first work. Implementation that was written before its failing test is discarded
and rewritten, because a test written afterwards proves nothing about whether it can fail.

**Why this priority**: It converts 005's negative-control idea into a build discipline, but it is only
usable once US1 and US2 make an unattended run safe to leave alone. The justification is mechanistic —
an unobserved test cannot demonstrate that it can fail — not empirical: the defect-reduction literature
on test-first is contested, and no gain is claimed here.

**Independent Test**: Ask for test-first on a task whose implementation already exists, and confirm the
pre-existing implementation is discarded, the test is observed to fail first, and the final state passes.

**Acceptance Scenarios**:

1. **Given** test-first is requested, **When** a task starts, **Then** the test is written and observed failing before implementation begins.
2. **Given** implementation exists before its test, **When** test-first is requested, **Then** that implementation is discarded rather than kept.
3. **Given** test-first is not requested, **When** a task runs, **Then** nothing is discarded and the mode is reported as not applied.
4. **Given** work starts, **When** the project's tests are already failing, **Then** the run refuses to begin until the baseline is clean or the owner explicitly accepts it.

---

### User Story 4 - Review files findings instead of passing judgement (Priority: P2)

An owner gets a review they can act on: two stages — does it match the plan, then is the code any good —
with each finding pointing at a file and line, carrying how it was established and how confident it is.
Findings never block by themselves; the owner decides.

**Why this priority**: High value once parallel work exists, since a worker reviewing its own output is
the weakest possible check. But it is worthless before claims exist, because there is nothing to review
independently of.

**Independent Test**: Produce a change that violates its declared boundary and a change with a style
problem, and confirm the first is reported at the specification-compliance stage, the second at the
quality stage, and neither is silently converted into a pass/fail.

**Acceptance Scenarios**:

1. **Given** a change and its plan, **When** review runs, **Then** it reports specification compliance separately from code quality.
2. **Given** a finding, **When** it is reported, **Then** it cites a file and line.
3. **Given** findings exist, **When** the review ends, **Then** its outcome is one of a small set of distinct states (nothing to fix / fix before merging / could not review) and never a bare pass.
4. **Given** the reviewer cannot run, **When** the outcome is reported, **Then** it says so — an unavailable reviewer is not a clean review.
5. **Given** a reviewer whose measured precision has never been recorded, **When** its findings are reported, **Then** they are marked unmeasured and are not treated as a signal.

---

### User Story 5 - Changing a requirement leaves a trace (Priority: P2)

An owner discovers a requirement was wrong. The correction is recorded as an amendment — what was added,
what changed, what was removed — and the old version is kept in a dated archive rather than overwritten.

**Why this priority**: It is what makes "repair the earliest affected artifact" possible instead of
destructive, and it is cheap. But it does not protect a run, so it sits below the P1 pair.

**Independent Test**: Amend a requirement, confirm the amendment is expressed as added/changed/removed
against the previous version, then confirm the previous version remains readable in a dated archive.

**Acceptance Scenarios**:

1. **Given** an existing requirement, **When** it is changed, **Then** the amendment states what was added, changed and removed.
2. **Given** an amendment is accepted, **When** it is applied, **Then** the previous version is preserved in a dated archive, not overwritten.
3. **Given** work in flight, **When** its plan is inspected, **Then** in-flight change plans are distinguishable from settled specifications.
4. **Given** an amendment contradicts an earlier one, **When** both are read, **Then** the contradiction is detectable rather than silently resolved by file order.
5. **Given** two specifications in the same batch claim the same responsibility, **When** the batch is checked, **Then** the overlap is reported before either is worked.

---

### User Story 6 - Findings arrive where the work is (Priority: P3)

An owner sees findings attached to the lines they concern, at the moment the change is proposed, rather
than reading a log and hunting for the file.

**Why this priority**: Pure delivery convenience — genuinely useful, and useless until US4 produces
findings worth delivering.

**Independent Test**: Propose a change with a known finding and confirm the finding appears against the
relevant line of the change, and that a clean change produces no annotation.

**Acceptance Scenarios**:

1. **Given** a finding on a changed line, **When** the change is proposed, **Then** the finding is shown against that line.
2. **Given** a clean change, **When** it is proposed, **Then** no annotation is produced.
3. **Given** the cheapest checks, **When** they can run locally, **Then** they run before the change is proposed rather than after.

---

### User Story 7 - Notes and decisions outlive the session (Priority: P3)

An owner returns to a project after a week, or with a different agent. The decisions taken and the facts
learned are still there, in the repository, not in one tool's private memory.

**Why this priority**: Lowest urgency, but it compounds: every session that starts by re-deriving
decisions is a session partly wasted.

**Independent Test**: Record a decision and a note, start a fresh session with no history, and confirm
both are surfaced with the work they belong to.

**Acceptance Scenarios**:

1. **Given** a decision was taken, **When** it is recorded, **Then** it is written into the repository and readable by any tool.
2. **Given** a note was left on one piece of work, **When** related work is opened, **Then** the note is surfaced.
3. **Given** a recorded decision, **When** later work contradicts it, **Then** the contradiction is detectable.

---

### Edge Cases

- **Two workers claim the last two tasks and both claim the same one at the same instant**: one wins; the loser is refused with a name, never both proceeding.
- **A claim is held by a machine that no longer exists**: visible as stale and reclaimable, with the age shown.
- **Handoff with nothing uncommitted**: reported as a clean stop, not as a handoff with missing work.
- **Test-first requested on a task with no test framework present**: reported as not-applied, never as satisfied.
- **Amendment removes the requirement a completed task was built against**: flagged, not silently dropped.
- **Reviewer unavailable offline**: "could not review" — distinct from clean and from fix-first.
- **Boundary declared but empty**: a task that may touch nothing is an error, not a free pass.

## Requirements *(mandatory)*

### Functional Requirements

**Claims and boundaries (US1)**

- **FR-001**: A worker MUST declare a task before working it, and the declaration MUST be visible to every other worker. The declaration MUST be acquired atomically: within one filesystem by an exclusive create, and across checkouts by a conditional update that fails when the claim already exists (`git update-ref --stdin`'s `create` was measured to fail with "reference already exists" rather than overwrite; the cross-machine equivalent is a ref update carrying an expected old value).
- **FR-002**: A second worker MUST NOT be able to take a task already declared, and MUST be told who holds it and since when.
- **FR-003**: A task MUST be able to declare the files or areas it may touch.
- **FR-004**: An edit outside a task's declared set MUST be reported as a violation and MUST prevent completion.
- **FR-005**: A task MUST be able to declare dependencies on other tasks, and MUST NOT be startable before they complete.
- **FR-006**: A declaration held by a worker that has stopped MUST be identifiable as stale, with its age, and MUST be reclaimable after a configurable lease; a takeover MUST be recorded as a new event, never as an edit of the original declaration.
- **FR-007**: A task MUST NOT be recorded complete without evidence of a check having run — an executed command with a recorded exit code and a nonzero count of items examined. Where `005-verification-integrity` is present, its FR-001…FR-005 govern what counts as evidence; where it is not, this sentence is the definition.

**Handoff and resumption (US2)**

- **FR-008**: Stopping work MUST release that worker's declarations and record why it stopped.
- **FR-009**: Stopping MUST preserve uncommitted work in a form another session can recover.
- **FR-010**: Resuming MUST print the next task with its acceptance criteria, in a session carrying no prior context.
- **FR-011**: Resuming MUST work from a checkout on a different machine or in a different tool.
- **FR-012**: A resumed report MUST distinguish pre-existing work from work produced after the resumption.
- **FR-013**: The system MUST support stopping automatically before a known session limit is reached, at a configurable threshold, and MUST be switchable off.

**Test-first discipline (US3)**

- **FR-014**: When test-first is requested, the test MUST be observed failing before implementation is written.
- **FR-015**: Implementation that existed before its test MUST be discarded, not retained.
- **FR-016**: Test-first MUST be a requestable mode, and NOT-applied MUST be reported as a distinct state from satisfied.
- **FR-017**: Work MUST NOT begin against a baseline whose existing checks are failing, unless the owner explicitly accepts that baseline.

**Review as findings (US4)**

- **FR-018**: Review MUST report specification compliance and code quality as separate stages.
- **FR-019**: Every finding MUST cite a file, a line, its stage, and a confidence class.
- **FR-020**: Review MUST end in one of a small set of distinct states including "could not review", and MUST NOT end in an indistinguishable pass.
- **FR-021**: A review that could not run MUST NOT be reported as a clean review.
- **FR-022**: Findings MUST NOT by themselves block completion; the owner decides.

**Amendments and archive (US5)**

- **FR-023**: A change to a requirement MUST be recorded as an amendment stating additions, changes and removals.
- **FR-024**: Applying an amendment MUST preserve the prior version in a dated archive.
- **FR-025**: In-flight change plans MUST be distinguishable from settled specifications.
- **FR-026**: Contradictions between amendments, and between specifications worked in the same batch, MUST be detectable.

**Delivery (US6)**

- **FR-027**: A finding on a changed line MUST be attachable to that line where the change is proposed.
- **FR-028**: A clean change MUST produce no annotation.
- **FR-029**: The cheapest checks MUST be runnable locally before a change is proposed.

**Notes and decisions (US7)**

- **FR-030**: Decisions MUST be recorded into the repository, readable by any tool without a session history.
- **FR-031**: A note MUST be attachable to a piece of work and surfaced when related work is opened.
- **FR-032**: A recorded decision contradicted by later work MUST be detectable.

### Requirements added by the independent check (2026-10-22)

Source: `docs/research/spec-vs-research-check-2026-10-22.md` and the audit's own adoption table. Four of these
are mechanics the audit assigned here and the first draft dropped; the rest close places where the spec
promised a property without a mechanism. They sharpen existing stories rather than adding an eighth.

*Claims and boundaries (US1)*

- **FR-033**: Each worker MUST work in its own checkout (`git worktree` per task), so two in-flight tasks never share a working tree.
- **FR-034**: A task declaring an empty boundary MUST be rejected when the plan is read, not at completion.
- **FR-035**: Starting a task MUST record the commit it began from, and completing it MUST record the commit range it produced.
- **FR-036**: Tasks with no dependency between them MUST be startable as a wave, so a plan's independent work is not serialised.

*Handoff and resumption (US2)*

- **FR-037**: A handoff snapshot MUST be scrubbed of credential-shaped content before it is written or pushed; if scrubbing cannot run, nothing is pushed.

*Review as findings (US4)*

- **FR-038**: A finding MUST record how it was established (an executed check, or a reading of the code), and only an executed check may be labelled confirmed.
- **FR-039**: A reviewer's precision MUST be measured on a labelled sample of at least twenty findings before its output is treated as a signal, and the measured precision MUST be reported with the review.

*Amendments and archive (US5)*

- **FR-040**: Deprecated and avoided terminology MUST be checkable across the specifications, with a nonzero exit in CI.

### Key Entities

- **Claim**: a task, the worker holding it, when it was taken, its lease age, and every takeover recorded against it.
- **Wave**: a set of tasks with no dependency between them, startable together.
- **Checkout**: one worker's working tree, created as a `git worktree` so no two workers share one.
- **Boundary**: the set of files or areas a task is permitted to touch.
- **Handoff**: why work stopped, what was uncommitted at that moment, and what the next task is.
- **Amendment**: additions, changes and removals against a previously settled requirement, with a date.
- **Finding**: stage (compliance or quality), file, line, severity, confidence class, how it was established (executed check or reading), and whether the reviewer ran at all.
- **Decision / Note**: a recorded choice or remark, attached to the work it belongs to.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Across ten overlapping-worker trials, **zero** cases of two workers editing the same file under different tasks.
- **SC-002**: **100%** of tasks started against a failing baseline are either refused or explicitly accepted by the owner — zero silent starts.
- **SC-003**: A handoff followed by a resume in a session with **no** carried context reproduces the next task and its criteria in **one** step, with zero re-explanation required.
- **SC-004**: Uncommitted work present at handoff is recoverable in **100%** of trials.
- **SC-005**: Review states are mutually distinguishable in **100%** of trials; "could not review" is never observed as a pass.
- **SC-006**: Every applied amendment leaves its prior version readable; **zero** overwritten requirements in the archive test.
- **SC-007**: **Zero** pre-test implementations survive a test-first task.
- **SC-008**: Across ten trials of two checkouts declaring the same task at the same instant, exactly **one** declaration succeeds every time; **zero** overwrites.
- **SC-009**: **100%** of recorded completions carry an executed command, its exit code and a nonzero examined count; **zero** completions rest on prose.
- **SC-010**: **Zero** credential-shaped strings appear in handoff snapshots across the fixture set, and a snapshot that cannot be scrubbed is never pushed.
- **SC-011**: Every review reports the measured precision of the reviewer it used, or states that it is unmeasured; **zero** reviews are presented as a signal without it.

## Out of Scope

- **Standards discovery and injection** (agent-os) — five markdown commands and a permanent standards-maintenance burden with no outcome evidence; the kit keeps a small always-injected `AGENTS.md` on purpose.
- **Task-graph management with a large tool surface** (task-master) — superseded by dependency annotations on tasks, at no extra tool count.
- **Persona/role ceremony** (BMAD) — no executable artefact.
- **A second spec layout** — the `AGENTS.md` marker collision makes coexistence unsafe.

## Decisions this spec makes explicit

- **What governs when the spec and the code disagree.** `spec.md` governs **intended behaviour**; the code governs **structure**. Where they disagree, the specification is repaired first and its dependents re-checked — the rule this repository already follows. (cc-sdd takes the opposite bet; recorded here so the choice is visible rather than accidental.)
- **Test-first is a mode, not a default.** superpowers gates it behind a flag; so do we.
- **Findings are advisory, gates are not.** Review informs; the executable gate decides. That separation is what keeps review useful instead of ignored.
- **A claim is a repository object, not a service.** Atomicity comes from git's own conditional ref update, so there is no daemon to run and no token to hold. Across machines that means the claim rides the remote; with no remote, claims are advisory across checkouts and the tool must say so rather than pretend.
- **A reviewer's output is evidence only after its precision is measured.** A reviewer that files findings avoids the verdict-flip failure mode but has its own — LLM reviewers are reported to over-reject correct implementations against stated requirements (Jin 2026) — so the first requirement on a reviewer is a measured precision, not a verdict.

## Assumptions

- Delivery is the kit's existing installer and command surface; no new runtime dependency.
- The kit remains agent-agnostic: every mechanic must work in a tool with no subagent support, degrading to sequential rather than failing.
- Two workers may be two agents, or one agent and one human.
- Session limits are discoverable where the host exposes them and unavailable elsewhere; where unavailable, the automatic stop is simply absent, never wrong.
- `specs/005-verification-integrity/` is expected to land first in practice. This spec depends on it only for FR-007's *definition* of evidence; the fallback in FR-007 keeps 006 implementable alone.
- Cross-checkout claims require a remote. Where the repository has no remote, claim acquisition is atomic only within one filesystem, and that limitation is reported rather than hidden.
