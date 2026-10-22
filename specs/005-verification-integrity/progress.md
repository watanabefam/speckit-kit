# Progress — plan: specs/005-verification-integrity/plan.md

Ledger for `specs/005-verification-integrity`. One line per task, evidence in parentheses.
`bin/speckit-resume` reads the plan identity from the first line and the tasks from here.

Task 1: complete (`bash -n bin/speckit-verify`; `--help` exits 0; `--nonsense` exits 2 (gate §12))
Task 2: complete (ledger with no subcommand exits 2; append/read/verify exercised by P-001 and P-002)
Task 3: complete (security with no stage exits 3, never 0; ladder cases pass in the fixture harness)
Task 4: complete (`evals/run-passk.py --help` exits 0; no arguments exits 2)
Task 5: complete (`python3 evals/fixtures/verify/harness.py --make DIR` builds the corpus; rewritten per run)
Task 6: complete (init copies the three executables and uninit removes them; gate §12 asserts they are present)
Task 7: complete (case manifest-rejected: a duplicate id and an absent oracle are both exit 2)
Task 8: complete (P-003: pytest 5 / jest / cargo 0 tests / go no-test-files all map to no-items, never a pass)
Task 9: complete (case clean-control prints `examined 3` beside the adapter name `pytest`)
Task 10: complete (P-004: six combinations; PASS only when no check failed, skipped or collected nothing)
Task 11: complete (every verdict assertion parses `--json` as a record; the human report carries `examined=`)
Task 12: complete (a record with no `exit` is refused; 12 appends grow the file with the prefix unchanged (P-002))
Task 13: complete (a hand-written scripts/verify is left with a note; only the byte-identical generated form is replaced)
Task 14: complete (a fresh scratch install seeds a manifest the loader accepts; --no-manifest skips seeding)
Task 15: complete (gate §12 runs the four vacuity fixtures and the clean control ([SC-001]))
Task 16: complete (P-003)
Task 17: complete (case control-passes: a control that exits 0 marks the check vacuous, exit 3)
Task 18: complete (case self-oracle: `oracle=implementation` is excluded and named, not counted)
Task 19: complete (case zero-tests: exit 3, "no tests collected", and no green verdict ([SC-001]))
Task 20: complete (P-004)
Task 21: complete (case criteria: the tally and both refusal paths)
Task 22: complete (case criteria: `1/3 evidenced` with SC-002 and SC-003 named as gaps ([SC-002]))
Task 23: complete (a spec with no SC-xxx rows refuses with exit 3 and names the missing section)
Task 24: complete (a progress line citing SC-999 exits 2 and names the id)
Task 25: complete (`bin/speckit-resume --criteria specs/005-verification-integrity` prints the n/11 tally)
Task 26: complete (P-006: the tally equals the number cited and every gap is named)
Task 27: complete (case merge: 20 rounds of shuffled two-sided merges, no loss, no duplicate, order stable ([SC-003]))
Task 28: complete (P-001: 12 shuffled record sets read back in (at, id) order)
Task 29: complete (read orders by (at, id) independent of file order and notes the skew on stderr)
Task 30: complete (duplicate id exits 1, a malformed line exits 2, git-reported deletions are not append-only)
Task 31: complete (bin/speckit-check §4b-ii reports ledger drift (duplicate ids or a rewritten history))
Task 32: complete (P-002: the file only grows and no id appears twice)
Task 33: complete (case unmatched and case coverage assert the scoped wording; the CI matrix runs both bash versions; the timing half is measured in docs/evidence/sc-004-timing-2026-10-22.md — 7 interleaved pairs at five suite sizes, ratio 0.235 at 6 checks down to 0.063 at 24, 0.273 at 5 and 0.444 at 3 ([SC-004]))
Task 34: complete (P-005: eight changed sets; every changed file is selected or named unmatched)
Task 35: complete (case unmatched: a one-file change selects `unit` and the report names the selection)
Task 36: complete (`--all` runs every declared check and the report says so)
Task 37: complete (a selected report never claims the suite: case unmatched asserts the scoped sentence)
Task 38: complete (case flaky: `flaky-classified`, both attempts retained, neither pass nor fail)
Task 39: complete (case coverage: `profile=full`, reached/not-reached counted, selected profile refuses the strong reading ([SC-008]))
Task 40: complete (P-008: provenance stated for both profiles; a selected profile never says no test executes a line)
Task 41: complete (gate §12 runs the mutation cases)
Task 42: complete (P-010: an equivalent mutant is not a candidate, an unclassified one is labelled unknown)
Task 43: complete (P-011: assertion kills and crash kills are distinguished)
Task 44: complete (`--mutation` is the only way the stage runs, and it is scoped to changed Python files)
Task 45: complete (case mutation: bounded candidates listed with file, line, operator; the percentage appears only on the budget line)
Task 46: complete (P-010 covers the equivalent/unknown split through the engine's own budget)
Task 47: complete (P-011: `killed-by-assertion` and `killed-by-crash` are separate counts ([SC-010]))
Task 48: complete (case unmeasured: a project whose tests collect nothing reports the module as unmeasured)
Task 49: complete (case extreme: `whole-method; less precise` in the report and in the mode line ([SC-011]))
Task 50: complete (case mutation: no `%` appears on the verdict line; the budget line is labelled not-a-threshold)
Task 51: complete (gate §12 runs the ladder cases)
Task 52: complete (P-009: four finding sets; the blocking exit appears only for a confirmed-live, baselined class)
Task 53: complete (case security: observe writes per-rule counts, blocks nothing ([SC-005]))
Task 54: complete (case security: no baseline refuses, no --confirm refuses, one confirmed-live class blocks)
Task 55: complete (case security: pattern-only never blocks, offline is not-run ([SC-009]))
Task 56: complete (an unpinned rule set is refused with exit 3 and no fetch)
Task 57: complete (a tool internal error is `scan-failed` with exit 3, never clean)
Task 58: complete (`changed` filters findings to the diff and prints the same rules hash as the broad scan)
Task 59: complete (every security report prints the environment-only control line; a green scan does not satisfy it)
Task 60: complete (gate §12 and case manifest-rejected: a property without `spec_rule` is rejected)
Task 61: complete (the report prints `spec_rule` beside the outcome)
Task 62: complete (a `falsify` command that passes makes the property vacuous)
Task 63: complete (a failing check's output is printed verbatim under `== failing output (verbatim) ==`)
Task 64: complete (the schemathesis adapter exists and `schema` is an accepted manifest field (documented in README))
Task 65: complete (plan addendum and plan prepend carry the spec-rule/falsification rule)
Task 66: complete (gate §12 runs `evals/run-passk.py` and asserts both figures are printed)
Task 67: complete (P-012: pass@1, pass^k and the bound are printed; the bound is (mean pass@1)^k)
Task 68: complete (`--vector 5/5,5/5 --k 3` gives equal figures; `p=0.8, k=5` prints both and explains the gap ([SC-006]))
Task 69: complete (preset/preset.yml 1.16.0 and the CHANGELOG entry above)
Task 70: complete (README and QUICKSTART document the three executables, the manifest, the ladder and the changed/full split)
Task 71: complete (bin/speckit-check reports a manifest, its absence as a skip, and ledger drift as DIFF)
Task 72: complete (bin/speckit-uninit removes the three executables, the seeded manifest and .specify/security/)
Task 73: complete (the CI matrix already runs the gate on macOS bash 3.2 and Linux bash 5; the 005 scripts were added to the 3.2 parse step)
Task 74: complete (quickstart scenarios: the engine, ledger, mutation and pass^k ones run in the harness; the scanner scenarios need absent tools, so they are NOT-RUN rather than claimed. The research companion's claims were checked in docs/research/spec-vs-research-check-2026-10-22.md ([SC-007]))
Task 75: complete (`SELF-GATE: PASS  examined=N assertion(s)`; N > 0, and a run that asserts nothing fails (FR-001))
Task 76: complete (this file; `bin/speckit-resume specs/005-verification-integrity` prints COMPLETE only when every task has a line)

## Not claimed

SC-004 is measured only above six checks: `docs/evidence/sc-004-timing-2026-10-22.md` records
0.235 at six checks, 0.273 at five and 0.444 at three, on one 2-CPU machine over a synthetic
suite. The criterion names no suite size, so the measured claim carries the floor in it and the
criterion's wording is left for its owner — it is **not** stated as met unconditionally, and it
is **not** a claim about this repository's own gate (the kit has no `.specify/verify.json`, so
`./scripts/verify` still runs the legacy sequence). Everything else above names the command that
proves it.

## Analysis findings, repaired before implementing

`/speckit.analyze`'s structural pass found 42/42 FRs, 76 sequential tasks and 12 properties
aligned. The semantic pass found five inconsistencies, each repaired at the artifact rather
than worked around in code:

- **A-1** `contracts/verify-cli.md` showed a `34/42` tally over FR ids; criteria are the spec's
  `SC-xxx` rows (`n/11`). The example and the `--criteria` row are corrected.
- **A-2** the ledger schema forbade `criteria.total = 0`, which FR-008's refusal must record.
  The schema now allows it, and forbids it only with `verdict: PASS`.
- **A-3** the tally's mechanism had no field ("records that name a criterion id"); it is now the
  explicit `[SC-003]` citation in `progress.md`, documented in `data-model.md`.
- **A-4** plan P-012 and T068 asserted the constant-p bound is always ≤ the empirical pass^k.
  That is a population statement (Jensen); the finite-sample estimates can reverse it
  (`n=5, c=4, k=2`: 0.64 > 0.60). Both artifacts are corrected and the harness names the reversal.
- **A-5** the record status enum had no state for FR-018's flaky result; `flaky` is added, and a
  flaky check forces INCOMPLETE rather than becoming a pass or a failure.

The criteria rule was also tightened during implementation for the same reason A-3 exists: the
first version counted any `SC-` mention in this file as evidence — including a sentence saying a
criterion was *not* measured. Evidence is now an explicit `[SC-xxx]` bracket on the line that
names the command or record behind it.

## Conformance gap found, not fixed

`scripts/check-section-integrity.sh . spec-template specs/005-verification-integrity/spec.md`
exits 1: 17 required sections are missing and `## Problem / Opportunity` sits before an
earlier-required heading. The spec predates the current template revision (it has no
`## Normative Status`, `## Requirements Syntax`, `## Carried Forward`, `## Goals`, `## Non-Goals`).
`tasks.md` (28/28) and `plan.md` (44/44) both pass. The spec is not restructured here because the
plan records it as approved content — changing it needs an amendment, not an edit — so the gap is
reported rather than patched.
