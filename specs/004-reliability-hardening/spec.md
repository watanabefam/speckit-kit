# Feature Specification: Reliability Hardening — the Gate Proves Behaviour, the Guards Cannot Vanish

**Feature Branch**: `004-reliability-hardening`

**Created**: 2026-10-21

**Status**: Accepted (owner asked for execution to completion; reversible, in-scope)

**Input**: User description: "Iteratively execute until completed well and without defects. Research online and on CiteKit for best practice and best implementation if and as necessary."

## Document Status

**Workflow:** full spec-driven · **Companion:** `research.md` (informative; points at the two research passes)
**Normative sections:** User Scenarios & Testing, Requirements, Success Criteria.

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

## Non-Goals

- Migrating to Spec Kit workflows/extensions, worktree isolation, or parallel task dispatch.
- Replacing the mutation/differential evidence layers (research recommends them; they are a later
  feature).
- Repeating eval runs to report `pass^k` — the current harness is single-run by design; adding
  repeats changes its cost model and is a separate change.
