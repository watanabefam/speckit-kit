# Data model — verification integrity

**Feature**: `005-verification-integrity` · **Date**: 2026-10-22

Four persisted artefacts and three in-memory aggregates. Field names are the contract; the JSON shapes are in
`contracts/`. Nothing here is a database — every artefact is a file the adopter owns and version-controls.

## Persisted artefacts

### 1. Check manifest — `.specify/verify.json`

The only place a check is defined. Seeded by `speckit-init` from the detected Commands block; edited by the
adopter thereafter.

| Field | Type | Required | Rule (from the spec) |
|---|---|---|---|
| `version` | integer | yes | must be `1`; any other value is a configuration error (exit 2) |
| `checks[].id` | string, `^[a-z0-9][a-z0-9-]{0,63}$` | yes | unique within the manifest; appears in records and reports |
| `checks[].kind` | enum `test│lint│typecheck│build│property│schema│mutation│security` | yes | determines which extra fields are required |
| `checks[].runner` | enum `pytest│jest│cargo│go│make│schemathesis│command` | yes | selects the exit-code and count adapter (FR-006) |
| `checks[].command` | string | yes | executed verbatim, no shell expansion beyond what the shell does; recorded in the ledger (FR-011) |
| `checks[].paths` | array of globs | yes | at least one; used for selection (FR-015). `**` matches any depth |
| `checks[].oracle` | enum `spec│fixture│declared│implementation` | **yes** | `implementation` or absent ⇒ excluded from evidence with a named reason (FR-004) |
| `checks[].control` | string | for `test`/`property` | a command that **must fail**; if it passes the check is vacuous (FR-005) |
| `checks[].falsify` | string | for `kind: property` | the known-failing input that proves the property can fail (FR-030) |
| `checks[].spec_rule` | string | for `kind: property`/`schema` | the specification rule the check encodes (FR-029) |
| `checks[].coverage` | string (path) | no | coverage JSON this check contributes; used by the changed-line report (FR-033) |
| `checks[].timeout_s` | integer ≥ 1 | no | default 300; a timeout is `status: fail` with `note: timeout`, never `pass` |
| `security.rules` | string (path) | when any `kind: security` | pinned, committed rule file (FR-026); absence is a refusal, not a fetch |
| `security.baseline` | string (path) | when the block stage is enabled | recorded per-rule counts (FR-025) |
| `security.confirm` | boolean | no, default `false` | enables the network confirmation tier (FR-035/FR-036) |
| `mutation.limit` | integer ≥ 1 | no, default 20 | bounded candidate list (FR-020) |
| `mutation.extreme` | boolean | no, default `false` | whole-method mode, labelled less precise (FR-039) |
| `selection.select_all_on` | array of globs | no | shared/configuration files; a change to one selects every check (defaults listed in the contract). A glob bounds a private module's effect, not `conftest.py`'s |

Validation is all-or-nothing: one invalid check rejects the manifest (exit 2) and nothing is recorded. A
partially-valid manifest is exactly the kind of thing that produces a green run over half a suite.

### 2. Verification ledger — `.specify/ledger.jsonl`

One JSON object per line, append-only. Never rewritten, never reordered, never compacted.

| Field | Type | Rule |
|---|---|---|
| `id` | string, UUIDv4 | unique across the file; a duplicate fails `speckit-ledger verify` (FR-012) |
| `at` | string, RFC 3339 UTC with `Z` | the sort key, with `id` as the tie-break (FR-013) |
| `mode` | enum `changed│all│criteria│mutation│security│property` | what was asked for |
| `command` | string | the command line that was run, verbatim (FR-011, FR-014) |
| `exit` | integer | its exit code; a record without one is refused (FR-014) |
| `fingerprint` | string, `sha256:<64 hex>` | `sha256(HEAD tree + hash of the working-tree diff)`; ties a result to content |
| `examined` | integer ≥ 0 | items examined across all checks (FR-001) |
| `verdict` | enum `PASS│FAIL│INCOMPLETE│NOT-RUN` | computed, never supplied by a caller (FR-003) |
| `checks[]` | array | `{id, status, examined, note}`; `status` is `pass│fail│no-items│skipped│not-run│vacuous` |
| `selection[]` | array of strings, optional | the files/checks selected (FR-017); absent in `--all` |
| `profile` | object, optional | `{source: full│selected│none, path}` for the changed-line report (FR-033) |
| `criteria` | object, optional | `{evidenced, total, gaps[]}`; `total: 0` is recordable only on the refused run (FR-008) and never with `verdict: PASS` |

**Append discipline.** Open `O_APPEND`; `flock`; write exactly one line ending in `\n`; `fsync`; close. If any
step fails the run reports `INCOMPLETE` with `note: record not durable` and exits non-zero — a report that claims
a result the ledger did not receive is not a result.

### 3. Security baseline — `.specify/security/baseline.json`

`{created_at, rules_sha256, counts: {<rule-id>: <integer>}}`. The block stage refuses without it (FR-025), and
refuses again if `rules_sha256` no longer matches the committed rules — a baseline measured against different
rules is not a baseline (FR-026).

### 4. Coverage profile — path named in the manifest

Unmodified `coverage.py` JSON (`files[].executed_lines`, `files[].missing_lines`, `files[].excluded_lines`,
`files[].summary.num_statements`). The engine reads it and never writes it. Its provenance is not a property of the
file, so `--coverage` takes an explicit `--profile full|selected` flag; guessing would be the defect.

A changed line falls into exactly one of five states, and only the first two are measurements of the change:

| State | Source | Counted as |
|---|---|---|
| **reached** | in `executed_lines` | measured, numerator |
| **unexercised** | in `missing_lines` | measured, denominator |
| **excluded** | in `excluded_lines` (a `# pragma: no cover` or `LCOV_EXCL_LINE`) | named, never measured — an exclusion is a declaration, not a result |
| **unmentioned** | in none of the three lists | named as unmeasured, in neither numerator nor denominator |
| **unprofiled** | the whole file is absent from `files[]` (and a check owns it — an unowned file is `unmatched`, reported elsewhere) | named, in neither |

The arrays hold **statements**, not every source line, so silence is the normal state of a comment and the defect
state of a stale report — the engine cannot tell them apart and MUST NOT guess (FR-043). `summary.num_statements`
is the report's own claim about its completeness: when it disagrees with `len(executed)+len(missing)` for a file,
the report contradicts itself and that file's lines are unmeasured rather than classified.

## In-memory aggregates

| Aggregate | Fields | Lifecycle |
|---|---|---|
| **CheckOutcome** | `id`, `status`, `examined`, `note`, `duration_ms`, `adapter` | one per executed check; discarded after the record is written |
| **CriteriaTally** | `evidenced`, `total`, `gaps[]`, `source` (spec path) | computed from the spec's `SC-xxx` rows and the explicit `[SC-003]` citations in that feature's `progress.md` (FR-007…FR-009). A prose mention of an id is not a citation — a sentence saying a criterion was *not* measured must not count as evidence for it. |
| **Report** | verdict, totals, selection, per-check outcomes, tally, changed-line reachability, findings | rendered once, to stdout (human) or `--json` (machine) |

## State transitions

**Verdict.** Inputs: outcomes, skips, vacuity findings, unmatched changed files, ledger durability.

```
start ──► PASS        only if: examined > 0, failures = 0, skips = 0, vacuous = 0,
                      unmatched = 0, record durable
      ──► FAIL        any check status = fail  (dominates every other state)
      ──► INCOMPLETE  examined = 0, or skips > 0, or vacuous > 0, or unmatched > 0,
                      or record not durable   (never printed as PASS)
      ──► NOT-RUN     a requested mode's tool is absent or offline; reported per tier,
                      folded into INCOMPLETE at the verdict, never into PASS
```

`FAIL` dominates: a genuine failure beside a skipped section is `FAIL`, not `INCOMPLETE` (spec Edge Cases).

**Check.** `declared → control-run → (control passed ⇒ vacuous, stop) → executed → classified
(pass│fail│no-items│skipped│not-run) → recorded`. A check whose control fails to run is `not-run`, not `pass`.

**Security finding.** `pattern-match → (confirm requested and online ⇒ confirmed-live│confirmed-dead) →
pattern-only│confirmed-*`. Only `confirmed-live` may produce exit 1 at the block stage (FR-035).

**Mutant.** `generated → tce-filter (equivalent ⇒ stop) → run → killed-by-assertion│killed-by-crash│
survived-candidate`. `survived-candidate` is the only state that reaches the report as a candidate (FR-020/FR-038).

## Relationships

- A **verification record** references zero or more **check ids** (by id, not by position) and optionally one
  **coverage profile** and one **criteria tally**.
- A **criteria tally** references criterion ids parsed from the feature's `spec.md`; a record's `criteria.gaps`
  entries must exist in that spec (FR-009).
- A **security finding** references one **baseline** entry by rule id; a rule absent from the baseline cannot
  block (FR-025).
- Records never reference each other. Causality is expressed by `at` + `id`, not by pointers — that is what makes
  a concurrent merge safe.

## Invariants (checked by the property tests in `plan.md`)

1. The ledger file only grows: for any prefix of appends, its length is non-decreasing and no line is modified.
2. Every record has a unique `id`; reading after any permutation of appends yields the same (`at`, `id`) order.
3. `verdict = PASS` implies `examined > 0`, `skips = 0`, `vacuous = 0`, `unmatched = 0`.
4. A selected-run profile can never produce the "no test executes this line" claim.
5. A blocking security exit implies a baseline entry exists for that rule and the finding is `confirmed-live`.
