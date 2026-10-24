# Contract — `scripts/verify` and its engine

**Status**: design contract for feature 005. Nothing here is implemented yet.

`scripts/verify` is the entry point adopters already run and the Commands block already names. This contract
adds flags and output; it does not move the command.

## Invocation

```
scripts/verify [options]
```

| Flag | Meaning | Default |
|---|---|---|
| *(none)* | Change-scoped: select checks by `git diff` against the merge-base, run them, report the selection | changed |
| `--all` | Run every check in the manifest (the full-suite mode; the nightly job uses this) | off |
| `--strict` | Exit non-zero on `INCOMPLETE` even when nothing failed | off |
| `--json` | Print the report as one JSON object (the same fields as the ledger record) | off |
| `--coverage PATH` | Consume a `coverage.py` JSON report for the changed-line section | none |
| `--profile full\|selected` | Declare the provenance of that report; required with `--coverage` | none |
| `--criteria` | Print only the `n/m` tally over the spec's `SC-xxx` criteria; exit 3 when `m` is 0 | off |
| `--mutation` | Run the mutation stage on changed files (opt-in) | off |
| `--extreme` | With `--mutation`: whole-method mode, labelled less precise | off |
| `--security observe\|changed\|block` | Run the security stage at that rung | off |
| `--confirm` | With `--security block`: enable the network verification tier (required for `block` to do anything other than refuse) | off |
| `--base REF` | Diff base for selection | merge-base with `main`/`master`/`origin/main` |
| `--no-ledger` | Print the report without appending a record (diagnostics only; the report says so) | off |

## Exit codes

| Code | Meaning | Caller can rely on |
|---|---|---|
| `0` | `PASS` | `examined > 0`, no failures, no skips, no vacuous checks, no unmatched changed files |
| `1` | `FAIL` | at least one check failed (dominates every other state) |
| `2` | usage or configuration error | nothing ran, nothing recorded |
| `3` | `INCOMPLETE` / `NOT-RUN` | something did not run: zero examined, a skip, a vacuous check, an unmatched changed file, a missing tool, or a non-durable record |

`--security block` without `--confirm` exits `3`, not `1`: without the network tier no finding can be
confirmed live, so there is nothing that may block, and a pattern-only match never does.

`speckit-resume` keeps its existing `0`/`2` and adds `3` for "the spec declares no acceptance criteria"
(distinct from a plan-identity mismatch).

## Output (human)

```
== selection ==
changed: 2 files → checks: unit-pricing, lint
unmatched: (none)
fallback: select-all: conftest.py changed, so a file-glob selection cannot bound the effect

== checks ==
  pass    unit-pricing        examined 18   pytest
  pass    lint                examined 1    ruff
  skip    integration         examined  —   tool absent: mutmut

== criteria ==
specs/005-verification-integrity/spec.md  10/11 evidenced; gaps: SC-004

== changed lines ==
profile=full  reached 41 of 45 measured changed lines
unexercised: src/pricing.py:88, src/pricing.py:91
excluded by declaration (a pragma or an LCOV_EXCL marker): src/pricing.py:44
unmentioned by the report — not covered, not uncovered, not measured: src/pricing.py:12
unprofiled — file absent from the report: src/legacy.py
this profile is full, but the report does not measure the lines above: it supports neither
'a test reaches this line' nor 'no test executes this line' for them

SELF-VERIFY: INCOMPLETE — 1 skipped, 0 failed  (a skip is not a pass)
           record: .specify/ledger.jsonl#2f9c…  examined=19
```

Rules the output obeys:

- The word `PASS` never appears when anything was skipped, vacuous, unmatched or absent.
- A changed-line figure always states `profile=`, and its denominator counts only lines the report measured.
- A line the report does not mention is printed under `unmentioned`, never under `unexercised`; an excluded line is printed as excluded; a file absent from the report is printed as `unprofiled` (FR-043).
- `unprofiled` names only files the selected checks own: a changed file no check matched is reported once as `unmatched`, not a second time as unmeasured.
- The stronger reading is refused when the profile is selected **or** when any changed line was unmeasured, because a full profile with silent lines is not a complete measurement either.
- A mutation percentage, if printed, is labelled `budget` and never `verdict`.
- The last line always carries `examined=` and the record id, or `record: none — not durable`.

## Output (`--json`)

The JSON object is the ledger record (`contracts/ledger-record.schema.json`) plus `report: {selection, changed,
unmatched, fallback, changed_lines, findings}`. No field is human-prose-only; a CI job parses the record, not the banner.

## Invariants

1. `PASS` ⇒ `examined > 0 ∧ skips = 0 ∧ vacuous = 0 ∧ unmatched = 0 ∧ record durable`.
2. A check whose `oracle` is `implementation` or missing is never counted in `examined`.
3. A check whose `control` passes contributes `status: vacuous` and forces `INCOMPLETE`.
4. `--no-ledger` never yields `PASS`.
5. Exit `1` dominates `3`: a real failure beside a skip is `FAIL`, not `INCOMPLETE`.
6. Selection is by declared globs, and a change to a shared or configuration file
   (`selection.select_all_on`, defaulting to `conftest.py`, `pyproject.toml`, lockfiles and the
   manifest itself) selects every check and states `fallback:` — a glob cannot bound the effect of
   a file every test reads. Selection omits no test it cannot attribute, or it says so.

## Non-goals

The command does not *block* anything by itself. It reports and exits; a hook, a CI job, or an adopter's own
gate is what stops a merge. The kit will not describe this command as enforcing a rule — only as reporting one
(constitution, Honest Enforcement).
