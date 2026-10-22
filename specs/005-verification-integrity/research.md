# Research — design decisions for verification integrity

**Feature**: `005-verification-integrity` · **Date**: 2026-10-22

This file holds the **design** decisions Phase 0 had to settle. The *evidence* behind the feature — why
vacuous passes are the dominant failure mode, what the tools measure, which sources support which number —
is not duplicated here; it lives in `docs/research/verification-tooling-2026-10.md` (§6, §10, §11, §12) and
`docs/research/incorporation-decisions-2026-10.md`, and the spec cites it. What follows is what the
implementation had to choose, and why.

Each decision states what was chosen, why, and what else was evaluated. Where a decision rests on how a tool
actually behaves, the behaviour was checked rather than assumed, and the check is named.

---

## D-001 — `scripts/verify` stays the entry point; the engine lives in `bin/`

**Decision.** `scripts/verify` remains the single command adopters run. It dispatches to `bin/speckit-verify`
when `.specify/verify.json` exists, and otherwise runs the historical `test → lint → typecheck → build`
sequence the installer already generates.

**Rationale.** The Commands block, every task's `— Verify:` line, and 004 FR-010 all name `./scripts/verify`.
Changing the entry point would invalidate the one contract the kit has already made. The installer writes
`scripts/verify` only when it is absent and never overwrites it (`bin/speckit-init:509-528`), so the upgrade is
additive: replace only a file byte-identical to the generated form.

**Alternatives considered.** Extending the generated file into a full engine (rejected: every adopter then
carries 600 lines of unreadable bash); a bare `bin/speckit-verify` with no wrapper (rejected: breaks the
recorded contract).

---

## D-002 — JSON manifest, not TOML

**Decision.** `.specify/verify.json`.

**Rationale.** `tomllib` arrives in Python 3.11; the kit cannot assume it (stock macOS `python3` is older, and
the gate deliberately supports old interpreters). `json` is stdlib everywhere. The kit already parses JSON with
`python3` in `common.sh` and `self-gate.sh`, so this adds no new mechanism.

**Alternatives considered.** `.specify/verify.toml` (rejected: parser version risk); YAML for the kit's own
files (rejected: PyYAML is optional — 004 removed hard `jq` dependencies for the same reason); embedding the
manifest in `AGENTS.md` (rejected: that block is generated and managed).

---

## D-003 — Bash controller with `python3` heredocs; no new module tree

**Decision.** Each new executable is one bash file; parsing, record writing and reporting are `python3 - "$x"
<<'PY' … PY` heredocs inside it.

**Rationale.** This is the kit's established pattern (`scripts/self-gate.sh`, `.specify/scripts/bash/common.sh`).
It keeps the installer's copy list flat (three files), makes uninstall symmetric, and avoids a `lib/` directory
the rest of the kit does not have. It also keeps bash 3.2 compatibility trivially auditable: the bash parts use
`case` and indexed arrays only.

**Alternatives considered.** A Python package under `lib/` (rejected: new layout, new import path resolution,
installer complexity); pure bash JSON handling (rejected: the ledger needs real JSON and hashing).

---

## D-004 — Exit codes: 0 pass, 1 fail, 2 usage/config, 3 incomplete or nothing examined

**Decision.** As above, for `speckit-verify` and `speckit-ledger`. `speckit-resume` keeps 0/2 and gains **3**
for "the spec declares no acceptance criteria".

**Rationale.** `speckit-resume` already uses 2 for a plan-identity mismatch (004 FR-007). If a zero-criteria
refusal also returned 2, a caller could not distinguish "you gave me the wrong ledger" from "there is nothing to
verify". `INCOMPLETE` is a *different* state from failure, and the exit code is the only part of a verdict a
shell can branch on.

**Alternatives considered.** 0/1 only (rejected: conflates "looked and failed" with "did not look"); reusing 2
(rejected, above).

---

## D-005 — Ledger: `.specify/ledger.jsonl`, append-only, id + timestamp + fingerprint

**Decision.** One JSON object per line. Writer opens `O_APPEND`, takes `flock`, writes one complete line, then
`fsync`. No rewrite path exists in any command. Reader sorts by `at` then `id`. `speckit-ledger verify` rejects
duplicate ids and a history that is not append-only.

**Rationale.** Measured in this repository: append-only lines merge with zero conflicts, while an in-place edit
merged silently and erased the original record (research §12 item 4). The requirements follow from that
measurement: immutable lines, unique ids, duplicate check, timestamp ordering, and never trusting file order.
The append-only assertion is `git log --numstat -- .specify/ledger.jsonl`: deletions after the creating commit
are a failure.

**Alternatives considered.** A markdown table (rejected: merges conflict on the same line); SQLite (rejected: a
binary file that merges badly, and the point is merge safety); a custom merge driver now (deferred: the research
records it as the escape hatch if union proves insufficient, not as a first step).

---

## D-006 — Selection by changed file, with an unmatched file forcing `INCOMPLETE`

**Decision.** Default mode calculates `git diff --name-only --diff-filter=ACMR <merge-base>...HEAD`, matches each
path against each check's `paths` globs, runs the union, and **names any changed file no check covers**.

**Rationale.** File-level selection is competitive with dynamic selection (Zhang 2018, cited in research §10)
and is cheap. Its known weakness is missing tests, which the research records as the reason to keep periodic
full runs. Naming an unmatched file converts the weakness from silent to visible — which is this feature's whole
purpose.

**Alternatives considered.** Dynamic/coverage-based selection (rejected: needs a prior full profile and runtime
instrumentation); running everything always (rejected: SC-004, and the kit's own gate is ~3.5 min).

---

## D-007 — Changed-line reachability consumes a coverage profile, and reports its provenance

**Decision.** `--coverage PATH` reads a `coverage.py` JSON report produced by the run that generated it. The
report prints `profile=full|selected` and refuses the "no test executes this line" reading for `selected`.

**Rationale.** diff-cover and Codecov's patch coverage both consume a coverage *report*; neither runs tests.
A selected run therefore understates reachability, and "no test covers this" is only true of the profile that
was measured. The spec's FR-033/FR-034 and SC-008 encode exactly this boundary.

**Alternatives considered.** Instrument during the selected run (rejected: not portable, and it still cannot
see unselected tests); infer from line counts (rejected: not a measurement).

---

## D-008 — Mutation: mutmut, changed files, candidates, TCE as a partial filter

**Decision.** `--mutation` runs mutmut against changed files only, applies a bytecode-equality (TCE) pre-filter
before reporting, labels each result `survived-candidate` / `killed-by-assertion` / `killed-by-crash` /
`equivalent` / `unknown`, and caps the list (`--limit`, default 20). No percentage is ever a verdict; a budget
line may accompany the candidates.

**Rationale.** TCE is a partial filter in Python — measured twice now: `x*2` vs `x+x` and `x/2` vs `x>>1` differ
in bytecode (not filterable), while an identical function and a docstring-only change are identical (filterable).
Treating its misses as "equivalent" would hide real survivors. Kill class matters because a mutant killed by a
crash is not evidence a test would notice the change.

**Alternatives considered.** No pre-filter (rejected: worst of both, more noise); LLM/test-aware generation
(rejected for this feature in the spec's Out of Scope, with the 87.7%/79.1% vs 4.4%/5.7% comparison recorded);
extreme mutation as the default (rejected: less precise by construction; available behind `--extreme`).

---

## D-009 — Security: three stages, pinned rules, and blocking only on a confirmed-live credential

**Decision.** `bin/speckit-security observe|changed|block`.
- `observe` runs the pinned rule set over the whole tree and writes `.specify/security/baseline.json` by rule.
- `changed` runs the same rules over the changed set, non-blocking, and diffs against the baseline.
- `block` requires a baseline, runs only high-confidence classes, and with `--confirm` adds the
  `trufflehog --only-verified` tier; **only a confirmed-live finding fails the build**. Offline → `NOT-RUN`.

**Rationale.** The measured result is that pattern matching catches vendor token shapes and misses hand-written
credentials (6 of 7 shapes), and the reported false-positive rate of rule-based scanners is high. The only
near-certain signal available is a credential that works, so that is the only thing allowed to block. The
staged sequence mirrors the ladder recorded in research §10 (`scheduled broad scan → diff-aware scan →
blocking`) and the OWASP security-gate pattern.

**Alternatives considered.** Blocking on any finding (rejected: the 25–99% FP range teaches owners to ignore it);
a custom regex rule (rejected: measured weakest); blocking offline on pattern matches (rejected: same reason,
and it would break the "network tier" honesty of FR-036).

---

## D-010 — Properties: `spec_rule` + an executable `falsify` command

**Decision.** A manifest check of `kind: property` requires `spec_rule` (the rule id it encodes) and `falsify`
(a command that must fail, proving the property can fail). The plan template gains the `spec rule` column so a
property cannot be written without naming its rule.

**Rationale.** The evidence in research §10 is that the measured gain comes from specification grounding, not
from the property technique. A property that cannot fail is the same defect as a test that cannot fail, so the
demonstration is the same mechanism as FR-005's negative control rather than a separate prose rule.

**Alternatives considered.** A prompt-only rule (rejected: prose is a request); a separate generator tool
(rejected: `hypothesis`/`schemathesis` are optional and detected, not required).

---

## D-011 — `pass^k` measured in `evals/`, both figures always

**Decision.** `evals/run-passk.py --tasks FILE --k 5` prints `pass@1`, the empirical `pass^k` averaged over
tasks, the constant-p bound `p^k`, and a Wilson interval for the single-attempt rate.

**Rationale.** `pass^k` is the standard repeated-trial reliability metric (τ-bench): the per-task definition is
the empirical one, and `(E[p])^k ≤ E[p^k]` by convexity, so the constant-p figure is the pessimistic bound. A
report showing only one invites the wrong conclusion. The research's own harness used a synthetic distribution;
this script takes real per-task outcomes and states which figure is which.

**Alternatives considered.** A third-party eval framework (rejected: the measurement is ~30 lines and the spec
puts bundled frameworks out of scope).

---

## D-012 — The kit's own gate gains an examined count

**Decision.** `scripts/self-gate.sh` prints `SELF-GATE: PASS — N checked, 0 failed, 0 skipped` and refuses to
print `PASS` when `N` is 0.

**Rationale.** Measured on 2026-10-22: the gate prints one `ok` per assertion (256–263 of them) but never a
total, and the verdict block (`:1477-1491`) has no `checked > 0` guard. The spec's Assumptions record this as
the first implementation task rather than an assumption of correctness. This is the same invariant the feature
asks of downstream projects, applied to the kit itself.

**Alternatives considered.** Leaving the kit out of scope (rejected: the kit gates itself by its own standard —
constitution, Development Workflow).

---

## D-013 — Preset 1.15.0, with a changelog entry

**Decision.** `preset/preset.yml` version 1.15.0; `CHANGELOG.md` entry describing the new verify modes, the
ledger and the security ladder.

**Rationale.** The constitution requires a version bump and a changelog entry for preset changes, and the gate
asserts the preset version. The addenda change (plan property column, plan command rule), so this is a preset
change in the constitutional sense.

---

## D-014 — Nothing new is required at runtime; every tool is optional

**Decision.** The engine path is bash + `python3` stdlib + `git`. `mutmut`, `semgrep`, `gitleaks`, `trufflehog`,
`schemathesis` and `coverage.py` are detected per feature and reported `NOT-RUN` when absent.

**Rationale.** The spec's assumption is explicit: absence produces `NOT-RUN`/`INCOMPLETE`, never a failure that
blocks work on a machine that cannot install the tool. It is also the only way the gate keeps running on a
stock macOS machine.

---

## Deferred, not omitted

- **Coverage adapters beyond Python.** The manifest has one `coverage` field; only the `coverage.py` JSON shape
  is specified now. Other formats report `NOT-RUN` with the adapter named. Deferred because each ecosystem needs
  its own fixtures and the Python one proves the design.
- **Whether `--extreme` earns documentation.** It exists behind a flag and is labelled less precise. Whether it
  is useful enough to recommend is implementation feedback, and FR-039 is satisfied either way.
- **`speckit-resume --criteria` versus always printing the tally.** Both satisfy FR-007. The flag avoids
  perturbing the existing resume output; the always-on form is harder to forget. Implementation feedback decides.
