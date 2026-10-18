# Implementation Plan: Autonomous Throughput and a Mechanical Boundary

**Branch**: `003-autonomous-throughput` | **Date**: 2026-10-17 | **Spec**: [`spec.md`](./spec.md)

**Input**: Feature specification from `/specs/003-autonomous-throughput/spec.md`

**Note**: This plan is filled in by `/speckit.plan`; its definition describes the execution workflow.

## Summary

Move the kit's approval boundary from prompt prose into a mechanical permission block installed by
`bin/speckit-init`, add a detected `## Commands` block plus a generated `scripts/verify`, run
`/speckit.implement` continuously under an execution budget, and add a `/speckit.quick` fast lane
routed from the `/speckit` entry point. All rules remain in the kit's own sources — `preset/commands/*.prepend.md`,
`commands/`, `hooks/`, `bin/` — never in generated files. The self-gate proves each artifact is
present and portable.

## Technical Context

**Language/Version**: Bash 3.2+ (installer, self-gate — must parse on macOS system bash and Linux
bash 5); Markdown (agent commands and the autonomy contract); YAML (hooks, preset manifest);
JSON/JSONC (`opencode.json`); Python 3 (embedded blocks in the installer and gate).

**Primary Dependencies**: `specify-cli` 1.0.13; the `opencode-yaml-hooks` plugin (already required);
`git`; `jq` (optional — the hooks degrade gracefully without it); `python3` (already required by the
installer and gate). No new dependency.

**Storage**: N/A — the kit has no data store. All state is files in the target project.

**Testing**: `scripts/self-gate.sh` (bash 3.2-compatible) with embedded Python assertion blocks, plus
a `--no-e2e`-gated scratch install that exercises the installer end to end.

**Target Platform**: macOS (system bash 3.2) and Linux (bash 5); agent hosts opencode and
Freebuff/Codebuff.

**Project Type**: CLI installer + agent-command kit (single project).

**Performance Goals**: N/A for throughput; `speckit-init` must remain idempotent and complete in
seconds excluding the `specify init` step it already runs.

**Constraints**: zero new runtime dependencies; portable bash; never clobber a user-owned file;
generated files are hook-protected and must not be hand-edited; the preset cannot create a new
command (so `/speckit.quick` must be installer-copied).

**Scale/Scope**: one new installer step, one new command, one new instruction file, one command
prepend edit, one new managed AGENTS.md block, ~6 self-gate assertions, one version bump.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

`.specify/memory/constitution.md` is **still the unratified template** (`[PROJECT_NAME]`,
`[PRINCIPLE_1_NAME]`). It therefore imposes no gates. In its place this plan is checked against the
kit's de facto principles, stated in `README.md` and `BUILD_PLAN.md`:

| De facto principle | Source | Status |
| --- | --- | --- |
| Append, never replace, upstream templates | `README.md` "Why append, not replace" | PASS — no template is replaced; one prepend is extended |
| Rules live in the command that runs the step | `README.md` "Why the rules live in the commands" | PASS — the continuous-execution rule goes in the implement prepend |
| Only a hook or a permission can enforce | `SKILL.md` "Where the rules live" | PASS — the boundary is a permission block |
| Zero runtime dependencies | `README.md` "MCP … zero dependencies" pattern | PASS — bash + python3 only |
| Portable across bash 3.2 and 5 | `.github/workflows/self-gate.yml` | PASS — assertions use the existing compatible helpers |

No violations; Complexity Tracking is empty. **Note for the user:** the constitution has never been
ratified in this repository. This feature does not depend on it, but `/speckit.constitution` remains
unrun and is worth doing separately.

## Project Structure

### Documentation (this feature)

```text
specs/003-autonomous-throughput/
├── plan.md              # This file
├── research.md          # Phase 0 output (evidence + decisions)
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output
│   ├── permission-block.md
│   ├── commands-block.md
│   ├── autonomy-contract.md
│   ├── quick-command.md
│   └── ledger-and-budget.md
└── tasks.md             # Phase 2 output (/speckit.tasks — not created here)
```

### Source Code (repository root)

```text
bin/
├── speckit-init         # + §2d permission block, §6b Commands block, copy quick + contract
├── speckit-uninit       # + reverse for opencode.json edits, Commands block, scripts/verify
└── speckit-check        # unchanged (drift checker)
commands/
├── speckit.md           # + fast-lane route in §3
└── speckit.quick.md     # NEW — the fast lane (installer-copied, like speckit.md)
preset/
├── preset.yml           # + version 1.12.0; implement description updated
├── commands/
│   └── speckit.implement.prepend.md   # + continuous-execution + budget rule
└── templates/           # unchanged
global/
├── working-agreements.md   # unchanged (routing only)
└── autonomy-contract.md    # NEW — the single contract file
hooks/
└── speckit-hooks.yaml   # unchanged
scripts/
└── self-gate.sh         # + §1-family, §3b, §5 assertions
CHANGELOG.md             # + [1.12.0]
```

**Structure Decision**: single project. The kit is one repository whose "components" are the installer,
the command/preset sources, the hooks, and the self-gate. No new directory is introduced except the
per-project `scripts/verify` the installer generates into a *target* project (not this repo).

## Complexity Tracking

> No Constitution Check violations — section intentionally empty.

---

## Carried Forward

### Confirmed Decisions

- The boundary is mechanical (permission block), not prose — spec US1, and the kit's own position.
- The kit's two existing hooks are retained unchanged.
- Spec 002's converge review is complete and not revisited.

### Constraints

- The installer must not clobber `opencode.json`, `hooks.yaml`, or existing `AGENTS.md` content.
- Generated files are hook-protected; every change lands in a kit source.
- Bash 3.2 portability is mandatory (the gate runs on macOS and Linux).
- A preset cannot create a new command — `/speckit.quick` must be installer-copied.

### Assumptions

- Project-level `opencode.json` overrides the user's global `permission` setting. **Verify in
  validation** (Risk R1).
- `permission` (singular, object syntax) is honoured by the installed opencode version; `permissions`
  (the newer ruleset array) is the forward path (Risk R2).
- Stack detection covers Node, Python, Rust, Go, Make at minimum.

### Risks

- **R1 — config precedence.** If a global `permission: "allow"` wins over the project block, the
  boundary is inert. Mitigation: an explicit validation step that attempts a denied command.
- **R2 — schema drift.** opencode marks `permission` deprecated in favour of `permissions`. The block
  is written in the documented form; a validation step confirms it is honoured.
- **R3 — deny false positives.** A deny pattern could block legitimate work. Mitigation: the block is
  editable and its edits are visible in the diff; the list is small and reviewed.
- **R4 — scope creep** toward isolation/parallelism. Mitigation: Non-Goals + parking lot.

### Open Questions

- Resolved in Phase 0: the permission block is written to the **project** `opencode.json`, created if
  absent and printed if present. No `[NEEDS CLARIFICATION]` remains.

## Scope Confirmation

### In Scope

- US1 — permission block, autonomy-contract file, rule-file drift reporting.
- US2 — `## Commands` block, generated `scripts/verify`, tasks name the command.
- US3 — continuous implement with an execution budget, per-task commit and ledger.
- US4 — `/speckit.quick` fast lane and routing.
- FR-014 — self-gate assertions; FR-015 — drift reporting.

### Out of Scope

- Worktree/container isolation, parallel `[P]` dispatch, sandbox provisioning (parked).
- The converge review (spec 002) and the EARS preset (spec 001).
- Any change to generated files.

### Requirements Affected

- Addressed: FR-001 … FR-015 (all).
- Deliberately not addressed: none. FR-015 is scoped to *reporting* drift, not preventing it.

## Repository Findings

Filled from inspection of the kit **before** proposing changes (sweep performed across the whole
repository, not just the obvious components).

### Relevant Components

- `bin/speckit-init` (326 lines) — installer; helper functions `say`/`warn`/`die` (`:55`–`:57`);
  marker constants `BRIDGE_START`/`BRIDGE_END` (`:26`–`:27`); numbered sections §1–§6 and §8 (there is
  no §7). Managed-block writer for `AGENTS.md` at `:229`–`:300`.
- `bin/speckit-uninit` — reverse installer; strips the two AGENTS.md blocks (`:60`–`:76`) and
  `speckit*.md` (`:80`–`:93`).
- `scripts/self-gate.sh` (730 lines) — section structure §1, §1b, §1b2, §1d, §1f, §1g, §1e, §1c, §2,
  §3, §3b, §3c, §4, §5; helpers `ok`/`bad`/`hdr` (`:21`–`:23`).
- `preset/preset.yml` — `provides: templates:` list; five `type: "command"` entries (all
  `strategy: "prepend"`) and four `type: "template"` entries (`strategy: "append"`); version at `:6`.
- `preset/commands/speckit.implement.prepend.md` — the implement step rules.
- `commands/speckit.md` — the `/speckit` entry point; routing table at `:56`–`:63`.
- `hooks/speckit-hooks.yaml` — two hooks; blocking contract is `exit 2` blocks the call, `action: stop`
  aborts the session.
- `AGENTS.md` — the `SPECKIT-BRIDGE` block is **generated** from `bin/speckit-init:229`–`:277`.

### Existing Behavior

- The installer writes: `.opencode/commands/speckit.md` (copy, `:94`–`:105`),
  `.opencode/hook/hooks.yaml` (copy, no-clobber, `:124`–`:139`), and the `SPECKIT-BRIDGE` block in
  `AGENTS.md` (`:285`–`:300`). It **reads** `opencode.json`/`opencode.jsonc` only to detect the hooks
  plugin (`:120`–`:123`) — it never writes one.
- No `opencode.json`, no `## Commands` block, no `scripts/verify`, and no stack detection exist
  anywhere in the kit.

### Existing Tests

- The self-gate asserts: installer parses; hooks present and behaviourally tested; the entry point is
  copied and carries required needles; the preset manifest is valid and every command entry is a
  prepend; each command prepend carries named rule markers (`self-gate.sh:424`–`:439`); the changelog
  has an entry for the current version and it is the newest (`:260`–`:280`); an e2e scratch install
  materialises the commands with frontmatter intact (`:643`–`:661`) and asserts each managed marker
  appears exactly once (`:688`–`:691`).
- **Not covered today:** anything about `opencode.json`, a Commands block, `scripts/verify`, the
  autonomy contract, or the fast lane.

### Project Conventions

- Rules go in the command that runs the step (prepends), not the skill.
- Enforcement is only via hooks or permissions — never claimed for prose.
- New installer steps follow the section-per-concern layout and reuse `say`/`warn`/`die`.
- New managed AGENTS.md blocks use paired HTML-comment markers and idempotent replacement.
- Version bumps require a CHANGELOG entry that sorts newest-first.

### Constraints Discovered

- **A preset cannot create a new command** (`bin/speckit-init:83`–`:85`): a `type: "command"` entry
  naming a command that does not exist is silently ignored. Therefore `/speckit.quick` must be copied
  by the installer, exactly as `speckit.md` is.
- **The gate extracts the no-verify awk predicate by regex** (`self-gate.sh:105`–`:113`) — changing
  that block's indentation breaks the gate's behavioural test. This feature does not touch it.
- **`speckit-uninit` has no reverse** for an installer-created `opencode.json`, the Commands block, or
  `scripts/verify`; adding them without a reverse would leave uninit incomplete.

### Files that re-list the same set (the sweep — all must be updated or they go stale)

| File:line | Re-listed set | Action |
| --- | --- | --- |
| `bin/speckit-init:263`–`:274` | step → command-file table (source of the AGENTS bridge) | add a `quick` row |
| `bin/speckit-init:310`–`:326` | "Next steps" command list | mention the fast lane |
| `commands/speckit.md:56`–`:63` | routing table | add fast-lane routing (FR-011) |
| `preset/preset.yml:49`–`:53` | implement command description | update for continuous execution |
| `skill/spec-driven-development/SKILL.md:34`–`:40` | "the command carries" table | update implement row; add fast lane |
| `README.md:17`, `:63`–`:69`, `:166`–`:176`, `:278`–`:288` | component/command tables + layout | update counts and rows |
| `QUICKSTART.md:68`–`:74` | two-commands table + loop | mention the fast lane |
| `scripts/self-gate.sh:424`–`:430`, `:653`–`:661` | expected rule-marker dict + e2e `check_cmd` calls | extend |
| `blog/spec-driven-development.md:118`–`:122` | command-carries table (marketing) | update |
| `AGENTS.md` bridge block | generated | do **not** hand-edit — edit `bin/speckit-init` |

## Architecture Overview

The change is four installer-owned artifacts plus one rule, all flowing through the kit's existing
mechanisms:

1. **Permission block** — new installer step §2d, modelled on the hooks copy (`:124`–`:139`): create
   `opencode.json` if absent (with `permission` and `instructions`), never clobber; if present, print
   the block and a merge instruction.
2. **`## Commands` block + `scripts/verify`** — a third managed AGENTS.md block
   (`SPECKIT-COMMANDS START/END`) written by the same Python marker-replacement as the bridge, plus a
   generated `scripts/verify` in the target project (create if absent; print if present).
3. **Autonomy contract** — one file installed to `.opencode/autonomy-contract.md`, pointed at by one
   line in the bridge block (FR-004 forbids equivalent prose in any command).
4. **Fast lane** — `commands/speckit.quick.md` copied like `speckit.md`, and routed from
   `commands/speckit.md` §3.
5. **Continuous execution** — a new rule appended to `preset/commands/speckit.implement.prepend.md`.

Nothing new is introduced conceptually: every mechanism already exists in the kit and is reused.

## Major Components

- **Permission block writer** (`bin/speckit-init` §2d) — create/print, never clobber.
- **Command detector** (`bin/speckit-init` §6b) — read `package.json` scripts, `pyproject.toml`,
  `Cargo.toml`, `go.mod`, `Makefile`; produce a command record set.
- **`## Commands` managed block** — same marker mechanism as the bridge.
- **`scripts/verify` generator** — a bash script that runs the detected commands in order, exits
  non-zero on first failure.
- **Autonomy-contract file** (`global/autonomy-contract.md` → `.opencode/autonomy-contract.md`).
- **Fast-lane command** (`commands/speckit.quick.md`).
- **Continuous-execution rule** (`preset/commands/speckit.implement.prepend.md`).
- **Self-gate assertions** (`scripts/self-gate.sh`).
- **Uninit reverse** (`bin/speckit-uninit`).

## Data Flow

`speckit-init` reads the target project → detects stack → writes `opencode.json` (permission +
instructions), the `## Commands` block in `AGENTS.md`, `scripts/verify`, `.opencode/autonomy-contract.md`,
and copies `speckit.quick.md`. At run time: an agent reads `AGENTS.md` (routing + pointer) → loads the
autonomy contract → runs a task → runs `scripts/verify` → commits and writes a ledger line. The
permission block is consulted by opencode before every bash tool call, independently of the model.

## Interfaces and Contracts

- **Permission block** — see `contracts/permission-block.md`.
- **Commands block + `scripts/verify`** — see `contracts/commands-block.md`.
- **Autonomy contract** — see `contracts/autonomy-contract.md`.
- **Fast lane** — see `contracts/quick-command.md`.
- **Ledger + execution budget** — see `contracts/ledger-and-budget.md`.

## Dependencies

None new. The feature reuses `python3` (already required), the `opencode-yaml-hooks` plugin (already
required), and `git`. `jq` remains optional.

## Error Handling

- **Stack undetectable** → the Commands block records `unresolved` entries and the installer prints a
  one-time prompt; no `scripts/verify` is generated (FR-006).
- **`opencode.json` present** → printed, not written (FR-002).
- **`scripts/verify` already exists** → printed, not written.
- **Detected verify fails at install time** → reported; initialisation still completes (US2 scenario 4).
- **Budget reached during implement** → halt, leave failing tasks unticked, record the reason (FR-009).
- **Managed block edited between installs** → reported (FR-015).

## Security and Privacy

Relevant, and the point of the feature. The permission block denies force-push, hook bypass,
package publish, and destructive database commands, and `ask`-gates push/reset/clean. It is written
in the project config, which is reviewable and version-controllable. The autonomy-contract file
contains no secrets; the installer must not write any credential into `opencode.json`. The existing
rule-file injection risk (PackHallu [9]) is partially mitigated by FR-015's drift reporting; full
signing is parked. Privacy: N/A — no personal data.

## Performance and Reliability

N/A for throughput; the kit is interactive. Reliability matters: every write is idempotent, and the
gate asserts marker-once so re-running the installer cannot duplicate a block.

## Validation Strategy

- **Automated** — extend `scripts/self-gate.sh`; run the full e2e scratch install on macOS bash 3.2
  and Linux bash 5 (FR-014).
- **Manual** — attempt a denied command and a routine command (US1, and the R1/R2 checks); run the
  fast lane on a one-line fix and on an overrun (US4); run implement against a failing plan to observe
  the budget halt (US3).
- **Security** — negative test: every action on the fixed irreversible list is matched by a deny rule
  (SC-002).
- **Data/migration** — N/A.
- **Evidence for approval** — gate output, the denied/routine transcripts, the fast-lane log entry,
  and the budget-halt transcript.

## Correctness Properties

| Property ID | Requirement | Scope | `for any …` statement | Check method | Non-mapped reason |
| --- | --- | --- | --- | --- | --- |
| P-001 | FR-001, FR-005, FR-014 | system | `for any` project state, running `speckit-init` twice yields a byte-identical project | property-test | — |
| P-002 | FR-002, FR-015 | system | `for any` pre-existing `opencode.json` / `hooks.yaml` / `AGENTS.md`, the installer never removes or rewrites a user-owned region | property-test | — |
| P-003 | FR-001, FR-003 | system | `for any` command on the fixed irreversible list, the installed block contains a rule whose pattern matches it and resolves to deny | property-test | — |
| P-004 | FR-005 | system | `for any` `AGENTS.md`, re-running the installer leaves exactly one Commands marker pair | property-test | — |
| P-005 | FR-010 | system | `for any` interrupted run, resuming repeats no task that has a `complete` ledger line | review-only | prompt behaviour; the rule is asserted present (§3b/§5), but the resume itself needs a live session (manual S9) |
| — | FR-008, FR-009 | — | — | — | prompt behaviour; no decidable oracle in the kit (verified by manual scenario) |
| — | FR-011, FR-012, FR-013 | — | — | — | routing/classification is model judgement; measured by eval, not asserted |
| — | FR-004, FR-007 | — | — | — | document-presence checks; asserted directly by the gate, not as a quantified property |

### Rules

Every property above starts with `for any` and names a check method. The non-mapped requirements are
opted out with a reason, not left as gaps.

### Framework decision

- **Detected** — `none found`. The kit has no `hypothesis`, `fast-check`, `proptest`, `jqwik`,
  `QuickCheck`, or `PropEr` dependency; its tests are bash and embedded Python.
- **Version / where found** — N/A.
- **Signal** — `scripts/` contains only `self-gate.sh`; there is no test-framework config.
- **Decision** — **`fallback`** to example-based tests, augmented with loop-generated fixture corpora
  (a lightweight property test in bash). Adding a property-testing framework to a zero-dependency
  bash kit is not justified by this change. `tasks.md` follows this decision verbatim: **no
  property-based framework is introduced.**

### Traceability

`FR-xxx → P-xxx → T0xx` is completed in `tasks.md`. A property with no task is unbuilt; a property
test with no requirement is scope creep.

### Independence

This section applies when `/speckit.plan` runs, whether or not the `spec-driven-development` skill
loaded. Under the `lean` preset, which bypasses templates, it does not apply.

## Alternatives Considered

| Option | Advantages | Disadvantages | Decision |
| --- | --- | --- | --- |
| Deny-list as a **hook** instead of a permission block | Cannot be talked out of; portable; the gate already behaviourally tests hooks | Per-project only; needs the plugin; a broad deny-list risks false positives; the kit deliberately keeps hooks "tiny" | **Rejected** — permission block is the documented, user-configurable layer; the hook layer stays at two near-zero-false-positive rules |
| Write the block to the **global** `~/.config/opencode/` config | Applies to every repo at once | The kit would edit a user-owned file outside the project; not version-controllable with the project | **Rejected** |
| **Print-only** snippet (never write) | Zero clobber risk | No boundary is installed by default; the failure mode is silent (no protection) | **Rejected** — create-if-absent, print-if-present is the safe middle |
| `permissions` (ruleset array) instead of `permission` | Not deprecated | Newer; not what the current docs show; may not be honoured by older installs | **Deferred** — write `permission`; record `permissions` as the forward path (R2) |
| Put the autonomy contract in each command | Always in front of the model | Blows the instruction budget (research finding 5); duplicates prose | **Rejected** — one file, one pointer |
| New `/speckit.quick` as a preset command entry | Declarative | The preset cannot create a command (`speckit-init:83`–`:85`) — silently ignored | **Rejected** — installer-copied, like `speckit.md` |

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Global `permission: "allow"` overrides the project block (R1) | Medium | High — boundary inert | Validation step attempts a denied command; if precedence is wrong, fall back to a hook (recorded alternative) |
| `permission` schema drift (R2) | Low | Medium | Validation step confirms the block is honoured; `permissions` recorded as forward path |
| Deny false positive blocks legitimate work (R3) | Medium | Low | Small reviewed list; editable; visible in the diff |
| `/speckit.quick` route fires on work that is not small | Medium | Medium | The command promotes to `/speckit.specify` on overrun (FR-013); eval checks the classification |
| Continuous execution compounds an error | Medium | Medium | Execution budget + `scripts/verify` as ground truth (research finding 3) |
| **R5 — glob flag position.** `git push --force*` does not match `git push origin main --force`, and a `-f` glob false-positives on `--follow-tags` | Medium | High for that one action | **Resolved during implementation:** glob `git push*--force*` for the long flag (§1d3), plus a token-based hook `block-force-push` for `-f` / `--force-*` / `+refspec` (§1f behavioural test) |
| Stale re-listed tables (the sweep) | High if skipped | Low | The sweep table above is the task checklist |

## Requirement-to-Design Traceability

| Requirement | Design Decision | Reason |
| --- | --- | --- |
| FR-001 | New installer §2d writes `permission` into project `opencode.json` | Mechanical boundary; project-scoped and reviewable |
| FR-002 | Create-if-absent, print-if-present (hooks no-clobber pattern) | Never edit a user-owned file |
| FR-003 | Rely on opencode's documented fail-closed precedence; assert with a negative test | Deny must win over allow |
| FR-004 | One `global/autonomy-contract.md` + one pointer line in the bridge | Instruction budget (finding 5) |
| FR-005 | `SPECKIT-COMMANDS` managed block + generated `scripts/verify` | One known command removes the discovery cost |
| FR-006 | Unresolved entries + one-time prompt; no verify generated | Never invent a command |
| FR-007 | Extend `preset/commands/speckit.tasks.prepend.md` | Verification line must name the recorded command |
| FR-008 | Append continuous-execution rule to the implement prepend | Round-trip savings |
| FR-009 | Execution budget in the implement prepend | Stopping condition (finding 3) |
| FR-010 | Per-task commit + ledger line in the implement prepend | Resumable state (finding 3) |
| FR-011 | Route from `commands/speckit.md` §3 | Fast lane (finding 5) |
| FR-012 | Failing test first, in `commands/speckit.quick.md` | Test-in-the-loop (finding 4) |
| FR-013 | Promotion rule in `commands/speckit.quick.md` | Scope control |
| FR-014 | New assertions in `scripts/self-gate.sh` §1-family, §3b, §5 | Evidence, not assertion |
| FR-015 | Installer compares managed blocks and reports drift | Rule-file supply chain (finding 2) |

## Implementation Boundaries

### Must Change

- `bin/speckit-init` — new §2d, §6b, and copies for the contract and the quick command.
- `bin/speckit-uninit` — reverse the new artifacts.
- `commands/speckit.quick.md` (new), `commands/speckit.md` (routing).
- `preset/commands/speckit.implement.prepend.md`, `preset/commands/speckit.tasks.prepend.md`,
  `preset/preset.yml` (version + description).
- `global/autonomy-contract.md` (new).
- `scripts/self-gate.sh` — assertions.
- `CHANGELOG.md` — `[1.12.0]`.
- The sweep tables listed in Repository Findings (SKILL.md, README.md, QUICKSTART.md, blog).

### Must Not Change

- The **existing two hooks' behaviour and their awk predicates**, including the exact indentation of
  the no-verify awk block (`self-gate.sh` §1f regex-extracts it). A third hook may be **added** —
  that is the R5 mitigation — but the two existing ones are untouched.
- `.opencode/commands/speckit*.md`, `.specify/scripts/`, `.specify/templates/`, `.specify/presets/`
  — generated; the hooks block hand-edits.
- The `SPECKIT START/END` block (owned by the agent-context extension).

## What Changed / What Remains Open

- **Changed from the spec:** the spec's open question (where the block is written) is resolved to the
  project `opencode.json`; the plan adds `bin/speckit-uninit` to the change surface (a gap the spec did
  not name) and a framework decision of `fallback`.
- **Changed during implementation:** R5 is resolved with a **third hook** (`block-force-push`) rather
  than globs alone, because a `-f` glob false-positives on `--follow-tags`. A **`Makefile`** was added
  so the kit's own Commands block is meaningful. `specify preset add/update` **normalises**
  `opencode.json` (strips blank lines), so the kit source was made blank-line-free and uninit's
  comparison was made formatting-tolerant. P-005's check method was reconciled to `review-only`.
- **Changed during convergence (Phase 8):** a **fourth hook** (`block-destructive-commands`) and
  quote-stripping in the hook predicates close the review's bypass findings; the detector gained
  `install` and Python/Rust/Go lint+typecheck; `uninit` gained a shape check for `scripts/verify` and
  a narrower command glob. T042 (live validation of rule precedence) remains open.
- **Still open:** whether project config overrides global `permission` (R1) and whether `permission`
  is honoured (R2) — both are validation steps, not design blockers; Linux bash 5 (CI).
- **Needs approval:** this plan, before `/speckit.tasks`.
