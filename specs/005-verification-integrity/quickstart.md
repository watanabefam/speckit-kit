# Quickstart — proving a green result was earned

**Feature**: `005-verification-integrity` · Every scenario below is a command you can run and the outcome that
proves the feature works. Shapes are in `contracts/`; fields are in `data-model.md`; neither is repeated here.

## Prerequisites

- The kit installed in a project: `bin/speckit-init` has run, and `.specify/verify.json` exists (seeded from the
  detected Commands).
- `git` and `python3` on `PATH`. Optional: `pytest`, `mutmut`, `semgrep`, `gitleaks`, `trufflehog`,
  `schemathesis`, `coverage.py` — absence is reported, not fatal.

## 1. A clean project passes, and says what it examined

```bash
scripts/verify --all
```

Expect: `SELF-VERIFY: PASS`, an `examined=<n>` with `n > 0` on the last line, and one record appended to
`.specify/ledger.jsonl`. Re-running appends a second record; the first is byte-identical afterwards (`git diff`
on the ledger shows additions only).

## 2. Nothing to check is not a pass

```bash
mkdir -p /tmp/vacity && cd /tmp/vacity && git init -q && printf 'version = 1\n' > .specify/verify.json  # + one check with no tests
scripts/verify --all
```

Expect: exit **3**, the word `INCOMPLETE`, and "nothing was examined" naming the check. Never `PASS`.

The runner-level version of the same test: a `pytest` check in a directory with no tests. `pytest` exits 5; the
adapter maps that to `status: no-items`, and the verdict is `INCOMPLETE`.

## 3. A check that cannot fail is vacuous

```bash
# manifest check with control = "true" (a command that passes)
scripts/verify --all
```

Expect: `vacuous`, `INCOMPLETE`, exit 3, and the control's passing exit named as the reason. A control that fails
(`false`) leaves the check admissible.

## 4. The report counts against the plan

```bash
scripts/verify --criteria
```

Expect: `34/42 evidenced` with the eight gaps named, in a project whose spec is this one. On a spec with **no**
acceptance criteria: exit 3 and a refusal naming the missing section — never `0/0` and never a pass.

## 5. The trail survives a merge

```bash
bin/speckit-ledger verify
```

On a ledger built by the merge simulator (100 rounds, two branches, union merge), expect exit 0: no duplicates,
timestamp order stable, deletions zero. Then edit one record in place and re-run: expect exit 1, "not
append-only", naming the commit. Duplicate an `id`: exit 1, "duplicate id".

## 6. Cost tracks the change

```bash
time scripts/verify            # one-file change, default mode
time scripts/verify --all
```

Expect the first to be ≤25% of the second **on the same machine**, with both numbers recorded in `progress.md`.
The first run's report names the selection and does not claim the suite is green.

A changed file matched by no check: exit 3, the file named. That is the safety half of selection.

## 7. Changed lines, with provenance

```bash
python3 -m coverage run -m pytest && python3 -m coverage json
scripts/verify --all --coverage coverage.json --profile full
```

Expect `reached <a> of <b> changed lines`, with `profile=full`. Repeat with `--profile selected` on a subset run:
expect the same section to refuse the phrase "no test executes this line".

## 8. Mutation reports candidates, not a score

```bash
scripts/verify --mutation
```

Expect a bounded list (`--limit`, default 20) of `file:line operator status`, no percentage, and an
`equivalent`-labelled mutant excluded from the list. A crash-killed mutant appears as `killed-by-crash` and is not
counted as evidence. A module with no tests reports `unmeasured`.

## 9. The security ladder

```bash
scripts/verify --security observe      # records the baseline, blocks nothing
scripts/verify --security changed      # diff-aware, non-blocking
scripts/verify --security block --confirm
```

Expect: observe exits 0 and writes `.specify/security/baseline.json`; a planted `ghp_…` token is reported but does
**not** fail `changed`; `block --confirm` fails **only** when a credential is confirmed live; `block` without
`--confirm` refuses (exit 3) rather than blocking on a pattern match; without a baseline it refuses (exit 3);
offline the confirmation tier reports `NOT-RUN`; deleting the pinned rules file makes the scan
refuse rather than fetch a default.

## 10. Properties are aimed and can fail

```bash
scripts/verify --all   # with a manifest check of kind=property, spec_rule=FR-007, falsify=<command>
```

Expect the falsification command to run first and fail (proving the property can fail), the property to run
second, and the report to name the spec rule. A property without `spec_rule` or without `falsify` is a manifest
error (exit 2), not a silently accepted check.

## 11. Reliability, both numbers

```bash
python3 evals/run-passk.py --tasks outcomes.json --k 5
```

Expect `pass@1`, the empirical `pass^k`, the constant-p bound (`p^k`), and a note explaining why the bound is the
pessimistic one. A deterministic task set prints the two figures equal.

## 12. Both shells

```bash
bash -n bin/speckit-verify bin/speckit-ledger bin/speckit-security
./scripts/verify --all         # bash 5
/usr/bin/env bash --version    # and CI's macOS bash 3.2 job
```

Expect the gate green under both. A construct that parses only on bash 5 is a defect: macOS ships 3.2.

## What "done" looks like

`./scripts/verify --all` green, every scenario above observed, and `progress.md` carrying one
`Task N: complete (<evidence>)` line per task — the evidence being the command and its result, never a summary.
