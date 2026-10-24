# Implementation Plan: Verification Integrity — a Green Result Must Be Earned

**Branch**: `005-verification-integrity` | **Date**: 2026-10-22 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/005-verification-integrity/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command; its definition describes the execution workflow.

## Summary

Make `scripts/verify` prove that it looked. One verification engine — `bin/speckit-verify` — runs a project's
declared checks, records how many items each examined, maps each runner's "nothing to check" exit code to a
non-pass, refuses vacuous checks (no oracle source, or a negative control that passes), appends one immutable
record per run to `.specify/ledger.jsonl`, and prints a verdict of `PASS` / `FAIL` / `INCOMPLETE` / `NOT-RUN`
with a `n/m` criteria tally. Around it: a ledger reader and duplicate check, a change-scoped selector, a
changed-line reachability report that names its coverage profile, an opt-in mutation mode that reports
candidates rather than a score, a three-stage security ladder whose only blocking tier is a provider-confirmed
credential, and a `pass^k` measurement in `evals/`.

The engine is bash + `python3` heredocs, matching the kit's existing pattern. It adds no runtime dependency.
`scripts/verify` remains the entry point, so the recorded Commands contract does not change.

## Technical Context

**Language/Version**: Bash 3.2-compatible shell (the kit's floor — macOS system bash) plus Python 3 stdlib.
No Python version above 3.6 is assumed: no `tomllib`, no `match`, no `dataclasses` in the engine's helpers.

**Primary Dependencies**: `git` (required), `python3` (already a hard dependency of the installer, the hooks and
`speckit-resume`). Optional, detected, never required: `mutmut` (mutation), `semgrep` and `gitleaks` (rules),
`trufflehog` (credential confirmation), `schemathesis` (schema-driven properties), `coverage.py` (changed-line
profiles).

**Storage**: `.specify/ledger.jsonl` (append-only events), `.specify/verify.json` (check manifest),
`.specify/security/baseline.json` (per-rule counts), `.specify/security/semgrep.yml` (pinned rules). All plain
files under version control; no database.

**Testing**: the kit's own gate — `./scripts/verify` → `make test` → `scripts/self-gate.sh` — plus fixture
projects created under a temp directory by the new gate sections. Scenario evals stay in `evals/`.

**Target Platform**: macOS and Linux, bash 3.2 and bash 5, non-interactive; offline-capable except the
explicitly network-tier security checks.

**Project Type**: CLI kit (bash scripts + prompt commands) installed into other repositories.

**Performance Goals**: default (change-scoped) verification of a single-file change completes in ≤25% of the
same machine's full-suite time (SC-004); the engine's own overhead stays under 300 ms for a 20-check manifest — a design target, not a measurement: no benchmark exists yet, and the first task that touches the engine replaces this figure with a measured one or records the miss.

**Constraints**: no new runtime dependency; every optional tool degrades to `NOT-RUN`/`INCOMPLETE`, never to a
pass; the engine must not write outside `.specify/` and the project's own coverage output; bash 3.2 has no
associative arrays or `${var,,}`.

**Scale/Scope**: one manifest of up to ~40 checks; ledgers of ~10^4 records; changed sets of ~10^3 files. The kit
itself is ~4.5k lines of bash plus ~1.5k of Python evals.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status |
|---|---|---|
| I. Evidence over assertion | Every task in `tasks.md` names the command that settles it; the plan's Validation Strategy is executable | **pass** — each task below carries a verify command; nothing is "done" on inspection |
| II. Proportionate process | Full workflow justified: this change crosses `bin/`, `scripts/`, `preset/`, `evals/`, a security surface, and a public CLI contract | **pass** — full workflow chosen deliberately; the fast lane would hide the contract change |
| III. Traceable artifacts | Every FR has a design decision and a task | **pass** — full 42-row traceability below |
| IV. Repair at the source | Earlier artifact repaired first | **pass** — already done for this feature: the research corrections (§12) and the spec repair preceded this plan |
| V. Honest enforcement | Do not claim a command enforces anything; only a hook or a permission can block | **pass** — the engine *reports*; blocking is `exit 1` from a command or a CI job, and the plan says so in Error Handling and Validation Strategy |
| Security & prompt boundaries | Guards fail closed; generated files never hand-edited; `--no-verify` not routed around | **pass** — new guards exit 2 on their own failure; `.specify/scripts/` untouched; no bypass added |
| Workflow & quality gates | `./scripts/verify` run before completion; both bash versions | **pass** — Validation Strategy requires both, recorded per task |

**Post-Phase-1 re-check**: unchanged. No complexity violations, so `Complexity Tracking` is empty by design.

## Project Structure

### Documentation (this feature)

```text
specs/005-verification-integrity/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   ├── ledger-record.schema.json
│   ├── verify-manifest.schema.json
│   └── verify-cli.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
bin/
├── speckit-verify            # NEW — the engine: manifest, adapters, verdict, report
├── speckit-ledger            # NEW — append, read, verify (ordering, duplicates, append-only ratio)
├── speckit-security          # NEW — observe / changed / block stages, pinned rules, confirm tier
├── speckit-init              # installs the three above, seeds .specify/verify.json, writes the wrapper
├── speckit-check             # + ledger drift, duplicate ids, new artifacts present
├── speckit-resume            # + criteria tally; refuses when the spec declares no criteria
└── speckit-uninit            # removes the three new files and the seeded manifest

scripts/
├── verify                    # generated: legacy sequence, or `exec bin/speckit-verify "$@"`
├── self-gate.sh              # + examined-count verdict line, + sections for every new behaviour
└── check-section-integrity.sh  (unchanged)

evals/
├── run-passk.py              # NEW — pass@1, empirical pass^k, constant-p bound, Wilson interval
└── fixtures/verify/          # NEW — four vacuity fixtures, a clean control, a merge simulator

preset/
├── preset.yml                # version: next free minor (1.15.0 was taken)
├── templates/plan-addendum.md    # Correctness Properties gains a "spec rule" column + falsify command
└── commands/speckit.plan.prepend.md  # the property rule, as a rule, not a hope

.specify/                     # adopter-owned after install; created/seeded by the installer
├── verify.json               # the check manifest (schema in contracts/)
├── ledger.jsonl              # append-only verification records
└── security/{baseline.json, semgrep.yml}
```

**Structure Decision**: the kit's existing single-project layout (top-level `bin/`, `scripts/`, `evals/`,
`preset/`) is kept exactly; no new directories at the root. New behaviour is three executables in `bin/`, in
line with the five that already exist, so the installer's copy list and `speckit-uninit`'s removal list stay
flat and auditable.

## Complexity Tracking

No constitution violations. No justified complexity to record.

---

## Carried Forward

### Confirmed Decisions

- `scripts/verify` remains the one entry point; the Commands block already names it and must not change (004 FR-010).
- The verdict is three-state plus `NOT-RUN`, copying `scripts/self-gate.sh:1477-1490` rather than inventing a new vocabulary (005 FR-003).
- No mutation percentage is a gate; survivors are candidates (005 FR-021, research §10).
- Blocking security may only be a **confirmed-live** credential on a rule class with a recorded baseline (005 FR-025/FR-035).
- The ledger is append-only JSONL with immutable lines, unique ids and a duplicate check — `merge=union` alone was measured unsafe (research §10, §12 item 4).

### Constraints

- Bash 3.2 compatibility for anything the installer writes; the gate runs under both 3.2 and 5.
- `python3` only for parsing; no third-party module in the engine path.
- Optional tools are detected, never required; their absence is `NOT-RUN`.
- A changed-line figure is only evidence about "no test executes this" when its profile came from the full suite.

### Assumptions

- Adopters can edit `.specify/verify.json` (it is theirs, like `specs/`), and the installer seeds a working default from the detected Commands.
- `git` is present in any project where claims and diff-scoped selection are used; without it the engine reports `NOT-RUN` for the scoped modes rather than guessing.
- The project's test runner prints a machine-parsable count; where it does not, the adapter reports `examined: unknown` and the verdict is `INCOMPLETE`.

### Risks

- Output parsing is version-fragile (pytest, jest, cargo). Mitigation: one adapter file, fixture-tested, and an `unknown` fallback that is never a pass.
- The mutation mode is the most complex piece and the least certain to work on arbitrary projects. Mitigation: opt-in, fixture-first, bounded output; it can ship one release later than the rest without blocking any other FR.
- `trufflehog --only-verified` transmits a candidate credential to the provider. Mitigation: network tier only, explicit `--confirm`, documented in Security and Privacy.

### Open Questions

- None that block design. Two are deferred by decision, not by omission: (a) which non-Python coverage adapters ship first — Python (`coverage.py` JSON) is the only one in scope for this feature; (b) whether the extreme-mutation mode is useful enough to document beyond a flag — deferred to implementation feedback.

## Scope Confirmation

### In Scope

- The engine, its manifest, its verdicts, its ledger, the tally, selection, changed-line provenance, mutation candidates, the security ladder, the `pass^k` measurement, and the kit's own examined-count.
- Installer, checker, resume and uninstall changes required to deliver and remove those.

### Out of Scope

- Reviewer/judge mechanics (006), claims and handoffs (006), any second spec framework.
- Non-Python coverage adapters, LLM mutant generation, a hosted dashboard, and any schema beyond JSON Schema documents in `contracts/`.

### Requirements Affected

- 005 FR-001…FR-042 all addressed. FR-037 (schema-driven properties) is addressed by an adapter plus a documented manifest field, deliberately the lightest touch of the set.

## Repository Findings

Inspected before designing: `bin/` (five bash executables, 86–591 lines each), `scripts/verify` (5 lines,
generated by the installer), `scripts/self-gate.sh` (1,491 lines, sectioned `hdr`/`ok`/`bad`/`skip`), the
`hooks/speckit-hooks.yaml` guard contract, `evals/` (four Python harnesses), `preset/` (version 1.14.0),
`specs/004-reliability-hardening/` (plan/ tasks/ progress conventions), and `.specify/` (generated — not
editable).

### Relevant Components

- `bin/speckit-init:445-530` — the Commands detection block and the `scripts/verify` heredoc. This is where a
  wrapper replaces the fixed `test → lint → typecheck → build` sequence.
- `scripts/self-gate.sh` — the kit's own gate; its `skip()`/`hdr()`/`ok()`/`bad()` vocabulary and the verdict
  block at `:1477-1491` are the precedent to copy. Section 0 already asserts the gate cannot lie about itself.
- `bin/speckit-check` (304 lines) — read-only drift reporter; the natural home for ledger drift (FR-010/FR-012).
- `bin/speckit-resume` (98 lines) — reads `progress.md`'s `# Progress — plan:` header; the criteria tally surfaces here, and its exit codes (0/2) must stay distinct from the new "no criteria" refusal.
- `hooks/speckit-hooks.yaml` — four guards, exit 2 = block. New code must not add a fifth guard unless a hook is the only way to block (it is not, for verification).
- `evals/run-scenario-evals.py` — the pattern for a standalone measurement harness in this repo.
- `preset/templates/plan-addendum.md` — already carries `Correctness Properties`; the `spec rule` column and the
  falsification command belong there, not in a new template.

### Existing Behavior

- `scripts/verify` runs the detected commands in order and stops at the first failure. It reports no counts, and
  a runner that exits 0 having collected nothing is indistinguishable from a full pass (measured: `pytest` with
  no tests exits 5, but a wrapper that swallows it exits 0).
- The kit's own gate prints one `ok` line per assertion and ~256–263 of them, but never prints a total and has
  no `checked > 0` guard at the verdict site (`scripts/self-gate.sh:1477-1491`).
- `bin/speckit-check` verifies artifacts exist and prepends are intact; it knows nothing about a ledger.
- No ledger, no manifest, no coverage handling, no security stage exists anywhere in the kit today.

### Existing Tests

- `scripts/self-gate.sh` is the test suite: sectioned assertions over the installer, guards, resume, evals,
  templates and the preset. Every new behaviour must get a section there, because that is the only gate the
  project actually runs.
- `evals/` covers prompt-level behaviour (scenario, trigger, outcome) — not the engine.
- Nothing covers `scripts/verify`'s output, because it had none worth covering. This plan adds the fixtures.

### Project Conventions

- Every `bin/` executable is bash with a `#!/usr/bin/env bash` shebang, a `# —` doc line, `set -euo pipefail`,
  and `"$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"` root resolution.
- Coloured `say`/`warn`/`die` helpers exist in `speckit-init`; `speckit-check` uses plain `printf`. New scripts
  follow `speckit-check` (plain, pipe-friendly) because their output is parsed by humans and CI.
- Python is embedded as `python3 - "$arg" <<'PY' … PY` heredocs (self-gate, common.sh) — never a separate module directory.
- `specs/<feature>/tasks.md` is a checklist; `progress.md` holds `Task N: complete (evidence)` lines; the gate
  asserts the ledger's plan identity.
- Preset changes bump `preset/preset.yml` and add a CHANGELOG entry (constitution, Development Workflow).

### Constraints Discovered

- `scripts/verify` is only written when the installer finds at least one command, and it is never overwritten
  once present (`speckit-init:509-528`). A wrapper upgrade therefore has to be additive: detect the old
  generated form and replace it only when it is byte-identical to what the kit generates.
- `speckit-resume` already uses exit 2 for a mismatched ledger; FR-008's refusal needs a distinct code (3) so
  callers can tell "wrong plan" from "nothing to verify".
- `common.sh:get_feature_paths` writes `.specify/feature.json`; the new engine must not go through it (that file
  is workflow state, not verification state).

## Architecture Overview

A single engine with a manifest, adapters, and a reporter. `scripts/verify` is a two-line dispatcher. The engine
loads `.specify/verify.json`, selects checks (all, or those whose `paths` globs match the changed set), runs each
check through a named adapter, and folds results into a verdict. Before a check runs, its declared negative
control must fail; a control that passes marks the check vacuous and forces `INCOMPLETE`. After the run the
engine appends one record to `.specify/ledger.jsonl` and prints the report, including the criteria tally from
`specs/*/spec.md` and, when a coverage profile is supplied, the changed-line reachability with its provenance.
Optional modes (mutation, security, properties) hang off the same manifest as check `kind`s so the verdict
arithmetic stays in one place rather than four.

## Major Components

- **`bin/speckit-verify`** — manifest load, selection, adapter dispatch, negative controls, verdict, report,
  ledger append, criteria tally. `--all`, `--strict`, `--json`, `--coverage`, `--mutation`, `--criteria`.
- **`bin/speckit-ledger`** — `append` (exclusive, refuses malformed records), `read` (orders by `at`, then `id`),
  `verify` (duplicate ids, append-only ratio from `git log --numstat`, schema).
- **`bin/speckit-security`** — `observe` (record baseline by rule), `changed` (diff-aware, non-blocking),
  `block` (requires baseline + confirmation; fails only on confirmed-live).
- **Runner adapters** — `pytest`, `jest`, `cargo`, `go`, `make`, `schemathesis`, `generic`; each returns
  `examined=<n>`, `status=<pass|fail|no-items|not-run>` and never invents a count.
- **`evals/run-passk.py`** — the reliability measurement (FR-031/FR-032).
- **`scripts/self-gate.sh` new sections** — one per behaviour, each with a negative control.

## Data Flow

`git diff` → changed set → manifest globs → selected checks → (negative control runs) → check runs → adapter
parses examined/status → verdict → ledger record append → report (selection, examined, tally, changed-line
reachability, profile provenance). Security and mutation are the same flow with different adapters; their
findings are attached to the same report and the same record, so one run produces one auditable line.

## Interfaces and Contracts

- `scripts/verify [--all|--strict|--json|--coverage PATH|--mutation|--security STAGE|--criteria]` — unchanged
  entry point, extended flags. Exit `0` pass, `1` fail, `2` usage/config error, `3` incomplete or nothing examined.
- `.specify/verify.json` — `{version, checks:[{id, kind, runner, command, paths, oracle, control, falsify, spec_rule, coverage, timeout_s}], security:{...}, mutation:{...}}`; schema in `contracts/verify-manifest.schema.json`.
- `.specify/ledger.jsonl` — one JSON object per line; schema in `contracts/ledger-record.schema.json`.
- `bin/speckit-ledger verify` exit `1` on a duplicate id or a non-append-only history, `2` on a malformed record.
- `bin/speckit-security` exit `0` nothing blocking, `1` confirmed-live credential (block stage only), `3` not-run/insufficient baseline. `block` without `--confirm` is exit `3`: the network tier is not enabled, so nothing can be confirmed live, and a pattern-only match never blocks (FR-025).
- `bin/speckit-resume` gains `--criteria`; exit `3` when the spec declares no acceptance criteria (FR-008).

## Dependencies

- **None added.** `python3` and `git` already exist for every installed project. TOML was rejected precisely so
  the engine does not need `tomllib` (absent before Python 3.11); YAML is used only where the tool requires it
  (semgrep rules), never in the kit's own files.
- Optional tools keep their existing contract: absent → `NOT-RUN`.

## Error Handling

- A check whose command cannot be parsed → `examined: unknown` → `INCOMPLETE`, with the adapter named.
- A negative control that passes → the check is vacuous → `INCOMPLETE`, "control did not fail".
- A changed file matched by no check → `INCOMPLETE`, with the file named (never a silent pass).
- A manifest that is missing, unparsable, or refers to an unknown runner → exit 2, nothing recorded.
- A ledger write failure → the report is still printed, the run is reported `INCOMPLETE` ("record not durable"),
  and the exit code is non-zero. A record is never half-written: write to a temp line, `fsync`, append under `flock`.
- Security: tool internal error → `scan failed`, never `clean`; no baseline → the block stage refuses (exit 3);
  offline → the confirmation tier is `NOT-RUN`.

## Security and Privacy

- **Credential confirmation leaves the machine.** `trufflehog --only-verified` sends the candidate credential to
  the provider to test it. It runs only in the network tier, only under an explicit `--confirm`, and the report
  says so. Pattern-only findings never enter that tier.
- **The ledger records commands, not secrets.** A command line is stored verbatim; the engine refuses a record
  whose command matches the project's secret-shaped patterns, and the handoff/ledger docs tell adopters to keep
  credentials out of commands (env vars are fine — they are not in the record).
- **No privilege escalation, no network except the declared tier.** The engine shells only what the manifest
  names; it does not fetch a rule set at run time (FR-026).
- **Fail closed.** Every guard path exits non-zero on its own failure and says why.

## Performance and Reliability

- Default mode reads one manifest and runs the selected checks; engine overhead is bounded by one `git diff` and
  one Python start (~50 ms each). Mutation and security stages are opt-in because their cost is dominated by the
  tools, not by us.
- Full-suite mode is the schedule's job (`--all` in a nightly CI job); changed mode is the per-change job. The
  ratio between them is SC-004's measurement, recorded per machine rather than asserted.
- The ledger grows by one line per run; `read` is O(n) and `verify` is O(n log n). At 10^4 records this is
  milliseconds, so no index is introduced.

## Validation Strategy

- Each task's verify command, run in this repository, plus the new `self-gate.sh` sections.
- Four vacuity fixtures (zero tests, self-referential oracle, skipped section, clean control) executed by the
  gate; SC-001 requires the first three to be non-green and the control to pass.
- A merge simulator (100 rounds of two-branch append + union merge, then `bin/speckit-ledger verify`) for SC-003.
- A single-file-change fixture timed against a full run on the same machine for SC-004 (both numbers recorded).
- Security ladder: a planted `ghp_` token (pattern-only, must not block) and a verified-tier stub (must block
  only when confirmed); offline run must report `NOT-RUN`; unpinned ruleset must refuse.
- Mutation: a fixture with one surviving mutant must produce one candidate and no percentage; a crash-killed
  mutant must be labelled `killed-by-crash` and not counted.
- Both bash versions: the gate already runs in CI on macOS bash 3.2 and bash 5; new sections are added there,
  not behind a version check.
- Manual: `bash -n` on every new script, then `./scripts/verify` green before the task is ticked.

## Correctness Properties

| Property ID | Requirement | Scope | `for any …` statement | Check method | Non-mapped reason |
| --- | --- | --- | --- | --- | --- |
| P-001 | FR-013 | system | `for any` two sets of ledger records merged in any order, reading the trail yields the same sequence sorted by (`at`, `id`) | property-test | — |
| P-002 | FR-010, FR-012 | system | `for any` sequence of `append` calls, the file only grows and no id appears twice | property-test | — |
| P-003 | FR-002, FR-006 | operation | `for any` runner exit code in the "collected nothing" set (pytest 5, jest 1 with no suites, empty selection), the verdict is not `PASS` and the exit is non-zero | property-test | — |
| P-004 | FR-003 | operation | `for any` combination of skipped and failed checks, `PASS` is printed only when there are zero skips and zero failures | property-test | — |
| P-005 | FR-015, FR-017 | system | `for any` changed set, every changed file is matched by a check or named as unmatched, and the report names the selection | property-test | — |
| P-006 | FR-007 | operation | `for any` set of criteria and evidence records, the tally equals the number evidenced and the gaps are named | property-test | — |
| P-007 | FR-021 | operation | `for any` mutation result set, no percentage is emitted as a pass/fail threshold | review-only | the guard is a wording/exit-code assertion over a rendered report; checked by a gate fixture, not a generator |
| P-008 | FR-033, FR-034 | operation | `for any` changed-line report, its profile provenance is stated and a selected profile never yields "no test executes" | property-test | — |
| P-009 | FR-025, FR-035 | system | `for any` finding set, a blocking exit occurs only for a confirmed-live finding on a class with a recorded baseline | property-test | — |
| P-010 | FR-022 | operation | `for any` mutant whose compiled form equals the original, it is labelled equivalent and is not counted as a candidate | property-test | — |
| P-011 | FR-038 | operation | `for any` killed mutant, its status distinguishes assertion from crash | property-test | — |
| P-012 | FR-031, FR-032 | operation | `for any` per-task success vector and k, the empirical pass^k and the constant-p bound are both printed, the bound is (mean pass@1)^k, and when finite-sample noise reverses the ordering the report says so instead of asserting an ordering that does not hold | property-test | — |
| P-013 | FR-043 | operation | `for any` changed set and any partition of its lines into executed / missing / excluded / unmentioned, every changed line lands in exactly one state, silence is never classified as unexercised, and only measured lines enter the denominator | property-test | — |
| — | FR-001, FR-004, FR-005, FR-014, FR-016, FR-018, FR-019, FR-020, FR-023, FR-024, FR-026, FR-027, FR-028, FR-029, FR-030, FR-036, FR-037, FR-039, FR-040, FR-041, FR-042 | — | — | — | configuration, reporting or prompt-side obligation with no decidable oracle over generated inputs; each is checked by an example-based gate fixture instead (see Validation Strategy) |
| — | FR-008, FR-009, FR-011, FR-012 (id shape) | — | — | — | covered by P-002 / P-006 and by example fixtures; a separate property would restate them |

### Rules

Every row starts with `for any`, names its scope and a check method, and every requirement is either mapped or
opted out with a reason. The property tests generate their own inputs with a small stdlib generator (random
sequences of records, exit codes, changed sets); no third-party framework is used, per the decision below.

### Framework decision

- **Detected** — none found. No `hypothesis`, no `fast-check`, no property framework in any manifest.
- **Version / where found** — N/A; `evals/` uses stdlib Python only.
- **Signal** — `grep -rn "hypothesis\|@given\|fast-check\|fc.assert" bin scripts evals` returns nothing.
- **Decision** — **fallback** to example-based fixtures plus small stdlib generators for the P-series above. Adopting `hypothesis` would add a test-time dependency to a kit whose gate must run on a stock macOS `python3`, and the generated domains here are tiny (exit codes, record orders, file sets) where a 20-line generator is sufficient and auditable. The trade-off is recorded rather than hidden: a hand-rolled generator explores less of the space than a mature framework would.

### Traceability

`FR-002 → P-003 → T0xx` and so on; the task list carries the property id in the verification column for each
property test, so a property without a task and a test without a requirement are both visible.

### Independence

Applies: this plan was produced through the template, not the `lean` preset. The property table stands on its
own regardless of whether the skill loaded.

## Alternatives Considered

| Option | Advantages | Disadvantages | Decision |
| --- | --- | --- | --- |
| Extend `scripts/verify` directly with a growing bash script | no new file | a generator that embeds a 600-line engine into every adopter's project, unreadable and untestable | **Rejected** — wrapper + `bin/speckit-verify` |
| TOML manifest (`.specify/verify.toml`) | familiar to Python users | needs `tomllib` (3.11+) or a dependency; macOS stock python3 is older | **Rejected** — JSON |
| jq for manifest/ledger handling | concise | `jq` is optional in this kit and 004 removed it from every guard | **Rejected** — `python3` heredocs |
| SQLite ledger | atomic, queryable | a binary file that merges badly across branches, and the whole point is merge safety | **Rejected** — JSONL |
| Ledger with `git merge=union` only | zero effort | measured unsafe: union silently accepts an erasing edit and does not guarantee order | **Rejected** — immutable lines + unique ids + timestamp sort |
| Threshold on mutation score | one number | contradicted by industrial practice and by the 4.4%/5.7% verified-fault rate | **Rejected** — candidates |
| Custom regex secret rule as the gate | offline, fast | it was the weakest answer measured (6 of 7 shapes missed) | **Rejected** — pinned semgrep/gitleaks observe tier + confirmed-live block tier |
| LLM/test-aware mutant generation | 87.7%/79.1% verified-fault rate vs 4.4%/5.7% | a model call per mutant and a trustworthy oracle, which is what is being built | **Rejected for this feature** — recorded in the spec's Out of Scope |
| Coverage adapters for every language | broad | unbounded scope; each ecosystem has its own format | **Selected, narrowed** — Python `coverage.json` first; others report `NOT-RUN` |

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Runner output formats shift between versions | High | `examined` wrong → wrong verdict | adapter fixtures per version family; `unknown` is never a pass; the adapter name is printed with the count |
| Overwriting an adopter's hand-written `scripts/verify` | Medium | destroys local work | only replace a byte-identical generated form; otherwise print a migration note and leave the file |
| Mutation mode is flaky or unusably slow on a real project | Medium | the feature is abandoned | opt-in, bounded, fixture-first; no other FR depends on it |
| `trufflehog --only-verified` sends a credential to a third party | Low (opt-in) | privacy incident | network tier only, explicit flag, documented, never in the default run |
| Ledger merge still corrupts under a custom merge driver | Low | lost history | `speckit-ledger verify` in CI fails on duplicates/non-append history; the reader is order-independent |
| Bash 3.2 incompatibility ships silently | Medium | the engine does nothing on macOS | gate runs both versions; new sections use no associative arrays, `mapfile`, `${var,,}`, or `+=` on arrays |
| False confidence from a "green" selected run | Medium | exactly the failure this feature exists to stop | unmatched changed file → `INCOMPLETE`; report names selection; full-suite schedule documented |

## Requirement-to-Design Traceability

| Requirement | Design Decision | Reason |
| --- | --- | --- |
| FR-001 | Engine report prints `examined=<n>`, plus a total | A number is the only thing that distinguishes looking from not looking |
| FR-002 | Verdict is `INCOMPLETE` with exit 3 when total examined is 0 | Zero cannot be green |
| FR-003 | Verdict vocabulary copied from `self-gate.sh:1477-1491` | Precedent already proven in this repo; 004 owns it |
| FR-004 | Manifest `oracle` field; absent or `implementation` → excluded with a named reason | A declaration is checkable; detecting semantic anchoring is not |
| FR-005 | Manifest `control` command must fail before the check runs | Converts "the harness can fail" into an executable fact |
| FR-006 | Adapter exit-code tables map `no-items` codes (pytest 5, jest "no tests") to `no-items` | The measured failure mode |
| FR-007 | Criteria tally in the report and `speckit-resume --criteria` | One number, not an adjective |
| FR-008 | Tally refuses (exit 3) when the spec declares zero criteria | The `ACs 0/0` hole |
| FR-009 | Unknown criterion id → error, exit 2 | Silence is the defect |
| FR-010 | Append-only writer: `O_APPEND` + `flock`; no rewrite path exists | Immutability by construction |
| FR-011 | Record schema in `contracts/ledger-record.schema.json` | Fields are the contract |
| FR-012 | `speckit-ledger verify` duplicate check; wired into `speckit-check` and CI | Runs before merge |
| FR-013 | Reader sorts by (`at`, `id`) | Merge order is not chronology |
| FR-014 | Writer rejects records without a command and exit code | Prose is not evidence |
| FR-015 | `git diff` + manifest `paths` globs; unmatched file named | Diff-scoped by construction |
| FR-016 | `--all` + documented nightly job | The safety net for selection |
| FR-017 | Report states mode and selection; wording templates per mode | Never imply the suite is green |
| FR-018 | Adapter re-runs a single failure once; both outcomes recorded as `flaky-classified` | Google's 84%/16% evidence |
| FR-019 | `--mutation`, changed files only | Cost |
| FR-020 | Bounded candidate list with file, line, operator, kill status | Actionable, not a score |
| FR-021 | Report refuses to render a percentage as a verdict; a budget line is allowed | Thresholds are counterproductive |
| FR-022 | TCE pre-filter by compiled-code comparison; misses labelled `unknown` | TCE is partial in Python |
| FR-023 | No-tests module → `unmeasured` | A ratio over nothing is a lie |
| FR-024 | `security observe --all` writes baseline by rule | The ladder's first rung |
| FR-025 | Block requires baseline + confirmed-live | The only near-certain signal |
| FR-026 | Rules path is a committed file; missing → refuse | A gate that changes its rules is not a gate |
| FR-027 | Tool internal error → `scan-failed`, exit 3 | The tool's own vacuous-pass trap |
| FR-028 | Tier map per check; offline → `NOT-RUN` | Network is a property of the check, not the run |
| FR-029 | Manifest `spec_rule` on property checks; plan addendum gains the column | Traceability at generation time |
| FR-030 | Manifest `falsify` command executed before the property | The demonstration is executable |
| FR-031 | `evals/run-passk.py` prints single and repeated | Two questions, two numbers |
| FR-032 | Same script prints the constant-p bound and the convexity note | Both are true under different assumptions |
| FR-033 | `--coverage` consumes `coverage.json`; report names profile | Provenance is part of the number |
| FR-034 | Report refuses the "file/module/project" reading, and the selected-run reading | Scope discipline |
| FR-035 | Confirmation tier distinguishes `confirmed-live` from `pattern-only` | The only precision win available |
| FR-036 | Confirmation is a network-tier check; offline → `NOT-RUN` | Honesty about what ran |
| FR-037 | `runner: schemathesis` adapter + documented `schema` field | Lightest touch that is real |
| FR-038 | Kill status from the mutant's exit: assertion vs crash | A crash kill is not evidence |
| FR-039 | `--extreme` mode exists, labelled less precise, never the default | Speed without silent precision loss |
| FR-040 | Documented nightly broad scan (`security observe --all`) | The ladder needs its base |
| FR-041 | `security changed` uses the same pinned rules | Diff-aware stage |
| FR-042 | Report prints the environment-only rule as the control and never lets a green scan imply it | The rule a scanner cannot check |
| FR-043 | Line states from `executed_lines` / `missing_lines` / `excluded_lines`; silence and an absent file are named unmeasured, and `summary.num_statements` is checked against the lists | Silence is not a measurement |

## Implementation Boundaries

### Must Change

- `bin/speckit-verify`, `bin/speckit-ledger`, `bin/speckit-security` (new), `evals/run-passk.py` (new).
- `bin/speckit-init` (install, seed manifest, write the wrapper), `bin/speckit-check` (ledger + artifacts),
  `bin/speckit-resume` (tally, exit 3), `bin/speckit-uninit` (removal).
- `scripts/self-gate.sh` (examined-count verdict line; new sections and fixtures).
- `preset/preset.yml` (the **next free minor** — this plan originally named 1.15.0, which the stopping-rule
  change consumed on 2026-10-22; the tasks list says so at T069), `preset/templates/plan-addendum.md`, `preset/commands/speckit.plan.prepend.md`,
  `CHANGELOG.md`, `README.md`, `QUICKSTART.md`.

### Must Not Change

- `.specify/scripts/`, `.specify/templates/`, `.specify/presets/` — generated; the kit is changed and reinstalled.
- `hooks/speckit-hooks.yaml`'s contract: exit 2 means block, and no new guard is needed for this feature.
- `progress.md`'s `# Progress — plan:` line and `speckit-resume`'s exit 2 for a mismatched ledger (004 FR-007).
- The Commands block's `./scripts/verify` entry point and the historical command sequence for projects without a manifest.
- `specs/005-verification-integrity/spec.md` — approved content; a change needs an amendment, not an edit here.
- The spec/tasks/plan section headings the preset requires.

## What Changed / What Remains Open

- **Changed from the spec:** — FR-037's "schema-driven instance" lands as one adapter (`schemathesis`) plus a manifest field rather than a general property generator; FR-005's control and FR-030's falsification are the same mechanism (a command that must fail), so they share one manifest field.
- **Still open:** — whether the extreme-mutation mode earns its documentation; which coverage adapters follow Python; whether `speckit-resume`'s exit 3 needs a dedicated `--criteria` flag or should always print the tally (implementation feedback decides, both satisfy FR-007).
- **Needs approval:** — this plan, before `tasks.md` is generated.
