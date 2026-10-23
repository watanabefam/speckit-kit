# Feature Specification: Reliability Hardening — the Gate Proves Behaviour, the Guards Cannot Vanish

**Feature Branch**: `004-reliability-hardening`

**Created**: 2026-10-21

**Status**: Accepted (owner asked for execution to completion; reversible, in-scope)

**Input**: User description: "Iteratively execute until completed well and without defects. Research online and on CiteKit for best practice and best implementation if and as necessary."

## Document Status

**Workflow:** full spec-driven · **Companion:** `research.md` (informative; points at the two research passes)
**Normative sections:** User Scenarios & Testing, Requirements, Success Criteria.

## Normative Status

**Normative:** User Scenarios & Testing, Requirements, Success Criteria. Everything else in this
document is informative.

### Which document wins

This spec is authoritative for behaviour. `research.md` is informative: it carries the two research
passes and their sources, and where the two disagree, this spec prevails.

## Problem / Opportunity

Two research passes (repo code analysis + CiteKit + primary-source review) found that the kit's
*safety evidence* is weaker than its *safety claims*. Confirmed at HEAD `abf1dba`:

- `scripts/self-gate.sh:30` — `skip()` calls itself. On a machine without `specify` or PyYAML the
  gate recurses instead of reporting.
- `hooks/speckit-hooks.yaml:51,138,225,278` — every guard does `command -v jq || exit 0`. Without
  `jq` the mechanical layer is inert, and the installer never checks.
- `bin/speckit-init:212-221` — an existing `opencode.json` is never given the permission block;
  the installer only prints advice. The most common (brownfield) install has no boundary.
- `bin/speckit-check` — reports "current" while `specify integration status` warns about six
  modified managed files and while the permission block / contract / `verify` may be absent.
- `bin/speckit-init:111-113` — prints "re-running init to refresh" but never calls `specify init`
  or `specify integration upgrade` in that branch.
- `bin/speckit-resume` — trusts any `Task N: complete` line and never checks the ledger belongs to
  the plan it is resuming.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A skipped check cannot read as a pass (Priority: P1)

An operator runs the gate on a machine missing an optional dependency. The gate names the skipped
section and exits non-zero under `--strict`; it never hangs and never prints a bare PASS.

**Acceptance Scenarios**

1. **Given** `specify` is absent, **When** `self-gate.sh --strict` runs, **Then** it reports the skip
   by name and exits non-zero.
2. **Given** the gate runs normally with no skips, **When** it finishes, **Then** it prints
   `SELF-GATE: PASS` and exits 0.
3. **Given** any skipped section, **When** the verdict prints, **Then** the word PASS is not used.

### User Story 2 - The guards cannot silently disappear (Priority: P1)

The four guards run with only `python3` available (no `jq`), still block the actions they name, and
refuse — rather than allow — when a payload cannot be parsed. A brownfield install receives the
permission boundary without any existing key being altered.

**Acceptance Scenarios**

1. **Given** a valid payload for `git commit --no-verify`, **When** the hook body runs with no `jq`
   on `PATH`, **Then** it exits 2.
2. **Given** a malformed payload, **When** a guard runs, **Then** it exits 2 and says it could not
   parse the payload.
3. **Given** an `opencode.json` with unrelated keys, **When** `speckit-init` runs, **Then** the
   permission block is added and every pre-existing key is byte-identical.
4. **Given** an `opencode.json` that already has a `permission` key, **When** `speckit-init` runs,
   **Then** that key is left unchanged and the installer says so.

### User Story 3 - Drift and resume are computed from evidence (Priority: P2)

`speckit-check` fails when the contract, permission boundary, `verify`, or the preset prepends are
missing. `speckit-resume` refuses a ledger that names a different plan.

**Acceptance Scenarios**

1. **Given** a removed autonomy contract, **When** `speckit-check` runs, **Then** it reports drift
   and exits 1.
2. **Given** a composed command with its prepend removed, **When** `speckit-check` runs, **Then** it
   reports drift.
3. **Given** `progress.md` naming another plan, **When** `speckit-resume` runs, **Then** it exits 2
   and prints no `RESUME` line.

### User Story 4 - Re-install is truthful and idempotent (Priority: P2)

Running the installer twice leaves the project in the same state, and the refresh message describes
what actually happens.

**Acceptance Scenarios**

1. **Given** a project already initialised, **When** `speckit-init` runs again, **Then** the
   composed commands still carry the prepends, the permission block is still present, and the
   second run's exit code is 0.
2. **Given** the installer refreshes an existing project, **When** it prints its status, **Then**
   the message does not claim a CLI/template refresh it did not perform.

### Edge Cases

- **A machine with no `jq`.** Every guard currently exits 0 without it, which is the defect this
  feature closes; the edge case is the post-fix state: the guard must still allow a legitimate edit
  and must say that the mechanical layer is degraded, rather than silently permitting everything.
- **A machine with no `specify`.** The gate's `skip()` recursion triggers exactly here; after the fix
  the section reports `INCOMPLETE` and `--strict` exits non-zero.
- **A brownfield `opencode.json`** that already contains a `permission` object with the user's own
  rules: the installer merges additively and never replaces the object.
- **An `opencode.jsonc`** (comments): not auto-merged, because JSON-with-comments cannot be rewritten
  safely by the installer; the installer says so instead of corrupting it.
- **A ledger belonging to a different plan**: resume refuses rather than continuing against it.
- **A second install** with prepends already present: idempotent, no duplicated markers.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: WHEN a section is skipped, THE self-gate SHALL name it, SHALL NOT print a bare PASS,
  and SHALL exit non-zero when invoked with `--strict`.
- **FR-002**: THE hook bodies SHALL NOT depend on `jq`; where JSON must be read they SHALL use
  `python3`, and IF `python3` is absent or the payload cannot be parsed THEN the guard SHALL exit 2
  with a reason.
- **FR-003**: WHEN `opencode.json` exists and has no `permission` key, THE installer SHALL add the
  kit's permission block, SHALL preserve every pre-existing key, and SHALL write a `.bak` copy.
- **FR-004**: IF `opencode.json` already has a `permission` key, THEN THE installer SHALL leave it
  unchanged and SHALL report that it did so.
- **FR-005**: THE self-gate SHALL execute each guard body with a blocking payload, an allowing
  payload, and a malformed payload, and SHALL run at least the bash guard with no `jq` on `PATH`.
- **FR-006**: WHEN `speckit-check` runs on a kit project, IT SHALL report drift if the autonomy
  contract, the permission boundary, `scripts/verify`, or a preset prepend in a composed command is
  missing.
- **FR-007**: WHEN `speckit-resume` reads a ledger whose `# Progress — plan:` header names another
  plan, IT SHALL exit 2 without emitting `RESUME`.
- **FR-008**: WHEN `speckit-init` finds `.specify/` already present, IT SHALL describe only the work
  it actually performs.
- **FR-009**: THE self-gate SHALL assert that a second install leaves the prepends and the
  permission block present.
- **FR-010**: THE Commands block SHALL describe `scripts/verify` as running the recorded checks,
  not a fixed test → lint → typecheck sequence.

### Key Entities

- **Gate section** — a named block of assertions; a skipped section is neither pass nor fail.
- **Guard body** — the bash program a hook executes; its contract is exit 2 = block.
- **Permission boundary** — the `permission` object in `opencode.json`; additive, never destructive.
- **Ledger identity** — the plan path in `progress.md`'s first line.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The gate exits non-zero on any skipped section under `--strict`, and no skip path
  recurses (verified by running the gate with `specify` absent).
- **SC-002**: 7/7 guard-body probes produce the expected exit code (2 block, 2 allow, 2 malformed,
  1 no-`jq`).
- **SC-003**: A brownfield install preserves 100% of pre-existing `opencode.json` keys and adds the
  deny rules (verified by parsing the result).
- **SC-004**: `speckit-check` exits 1 for each of four removed artifacts (contract, permission,
  `verify`, prepend).
- **SC-005**: A second install is idempotent for prepends and the permission block.
- **SC-006**: `speckit-resume` exits 2 on a mismatched ledger header.

## Assumptions

- `python3` is already a hard dependency of the kit (the installer and `speckit-resume` use it).
- `opencode.json` is JSON; `opencode.jsonc` may contain comments and is therefore not auto-merged.
- The permission schema in use is the kit's existing `permission.bash` shape.

## Requirements Syntax

**Not applicable — this spec's requirements are not in EARS.** FR-001…FR-0xx use `MUST` in the
RFC 2119 sense, matching the other specs written before EARS arrived. Rewriting approved requirement
text into EARS is an amendment with its own review; the checkable shape EARS buys is carried here by
the gate assertions, which fail on the behaviour rather than on the wording.

## Carried Forward

What this artifact inherits from the work before it.

### Confirmed Decisions

- The gate is three-state (`PASS` / `FAIL` / `INCOMPLETE`) and `--strict` turns every `INCOMPLETE`
  into a non-zero exit; a skipped section is never a pass.
- Guard bodies exit 2 to block and 0 to allow, and a malformed event is blocked rather than allowed.
- The permission block is merged additively into an existing `opencode.json`; `opencode.jsonc` is
  reported, not rewritten.
- `speckit-check` verifies artifacts rather than reporting "current" from optimism.

### Constraints

- `python3` is already a hard dependency, so the installer and `speckit-resume` may use it; `jq` is
  not, so a guard that needs it must handle its absence.
- No workflow/extension migration, no worktree isolation, no parallel dispatch — recorded as
  `## Non-Goals` above.
- The mutation and differential evidence layers are out of scope here (they became spec 005).

### Assumptions

Carried from `## Assumptions` above: `python3` present, `opencode.json` is JSON, and the permission
schema in use is the kit's existing `permission.bash` shape.

### Risks

- **A guard that blocks legitimate work.** Mitigated by 7/7 probe coverage (SC-002) including the
  allow cases, not only the block cases.
- **An installer that corrupts a brownfield config.** Mitigated by additivity plus the parse check in
  SC-003, and by refusing `opencode.jsonc`.
- **A gate that reports `INCOMPLETE` and still exits 0.** This was the original defect; SC-001 asserts
  the exit code, not the printed word.

### Open Questions

None open. The one that could have reopened the feature — whether to add the mutation and differential
layers here — was answered by keeping them out and specifying them separately (005), which is recorded
in `## Non-Goals`.

## Goals

- A skipped check cannot read as a pass, and the gate's exit code says what its output says.
- The guards cannot silently disappear: a missing `jq` degrades loudly, and the mechanical layer is
  not inert by accident.
- Drift, resume and install are computed from evidence rather than assumed.
- Re-install is truthful and idempotent.

## Non-Goals

- Migrating to Spec Kit workflows/extensions, worktree isolation, or parallel task dispatch.
- Replacing the mutation/differential evidence layers (research recommends them; they are a later
  feature — 005).
- Repeating eval runs to report `pass^k` — the current harness is single-run by design; adding
  repeats changes its cost model and is a separate change (delivered in 005).

## Dependencies and External Contracts

- **`opencode.json` / `opencode.yaml` hooks** — the guard contract is exit 2 = block.
- **`specify`** — present or absent; absence must produce `INCOMPLETE`, not recursion.
- **`jq`** — optional, and its absence must be visible.
- **`python3`** — required, used by the installer, `speckit-resume` and `speckit-check`.

## MVP Scope

The gate's three-state verdict with `--strict`, the seven guard-body probes, additive permission merge
with a parse check, `speckit-check`'s artifact re-verification, and `speckit-resume`'s ledger identity
check. Nothing else from the research passes is in scope.

## Future Work (parking lot)

| # | Idea | Noticed during | Why deferred | Revisit when |
| --- | --- | --- | --- | --- |
| 1 | Mutation and differential evidence layers | Research | Wall-clock cost and a different subject; specified as 005 | Done — 005 implements the bounded mutation stage |
| 2 | Repeating eval runs to report `pass^k` | Research | Changes the harness cost model | Done — `evals/run-passk.py` in 005 |
| 3 | A `speckit-check` mode that also verifies the manifest and ledger | Implementing 005 | Needed the engine first | Done — `speckit-check` reports ledger drift |

### Parking lot vs Non-Goals

A **Non-Goal** is refused here: workflow migration, worktree isolation, parallel dispatch. A **parked
idea** is deferred and, in this case, all three were later picked up by 005 — which is the point of
parking them: the row records *where the work went*, so a reader does not mistake deferral for
rejection.

## Validation Plan

- **Automated** — `scripts/self-gate.sh` with `specify` absent asserts the skip path reports and does
  not recurse; the guard-body probes assert 7/7 expected exit codes.
- **Brownfield trial** — install over an existing `opencode.json` with user keys and parse the result
  (SC-003); a second install asserts idempotence (SC-005).
- **Removal trial** — delete each of the four artifacts and assert `speckit-check` exits 1 (SC-004).
- **Evidence required for approval** — the above plus a mismatched-ledger resume exiting 2 (SC-006).

## Requirement Traceability

FR-001…FR-0xx map to tasks in `specs/004-reliability-hardening/tasks.md` → *Requirement Coverage*;
SC-001…SC-006 map to the gate assertions named in `## Validation Plan` above.
