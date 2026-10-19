# Quickstart — validating feature 003

**Purpose:** prove the feature works end to end. Each scenario is runnable and has an expected outcome.
This is a validation guide, not an implementation plan; the implementation lives in `tasks.md`.

**Prerequisites**

- macOS (system bash 3.2) or Linux (bash 5)
- `specify` CLI 1.0.13 on PATH, `git`, `python3`
- the `opencode-yaml-hooks` plugin installed for the agent host under test
- a scratch target project: `mkdir -p /tmp/003-demo && cd /tmp/003-demo && git init`

---

## S1 — Install into an empty project (US1, US2)

```bash
cd /tmp/003-demo
/path/to/speckit-kit/bin/speckit-init .
```

**Expected**

- `opencode.json` is created and contains the `permission` block from `contracts/permission-block.md`.
- `AGENTS.md` contains one `SPECKIT-COMMANDS` marker pair; `scripts/verify` exists and is executable.
- `.opencode/autonomy-contract.md` exists; `AGENTS.md` contains exactly one pointer line to it.
- `.opencode/commands/speckit.quick.md` exists (installer-copied).

## S2 — Idempotence (P-001, P-004)

```bash
cp -R /tmp/003-demo /tmp/003-demo-snap
cd /tmp/003-demo && /path/to/speckit-kit/bin/speckit-init .
diff -r /tmp/003-demo /tmp/003-demo-snap
grep -c "SPECKIT-COMMANDS START" AGENTS.md
```

**Expected:** the diff is empty (excluding timestamps the installer does not write); the marker count
is exactly `1`.

## S3 — Never clobber (FR-002, P-002)

```bash
printf '{\n  "permission": "allow"\n}\n' > /tmp/003-demo/opencode.json
cd /tmp/003-demo && /path/to/speckit-kit/bin/speckit-init .
cat opencode.json
```

**Expected:** `opencode.json` is byte-identical to what you wrote; the installer **prints** the
permission block and a merge instruction instead of editing the file.

## S4 — The boundary blocks without the model (US1, SC-002)

With the plugin active, ask the agent to run each of:

```
git push --force origin main
git commit --no-verify -m x
npm publish
```

**Expected:** each is refused by opencode (not by the prompt). Then ask it to run `git status` —
**expected:** it runs with no prompt.

## S5 — Flag-position coverage (permission-block limitation)

```
git push origin main --force
```

**Expected:** blocked. If it is **not** blocked, the glob does not cover trailing flags — record the
finding and apply the mitigation in `contracts/permission-block.md` (extend the pattern set or add a
token-based hook modelled on `block-commit-no-verify`).

## S6 — Verification is one command (US2)

```bash
cd /tmp/003-demo && ./scripts/verify; echo "exit=$?"
```

**Expected:** each detected step prints its name in order; `exit=0` on a healthy project and non-zero
at the first failure. Inspect a generated task and confirm its **Verification** line names
`./scripts/verify`.

## S7 — Undetectable stack (FR-006)

```bash
mkdir -p /tmp/003-empty && cd /tmp/003-empty && git init
/path/to/speckit-kit/bin/speckit-init .
grep -A6 "SPECKIT-COMMANDS START" AGENTS.md
test -f scripts/verify && echo "UNEXPECTED: verify generated"
```

**Expected:** the Commands block shows `unresolved` rows, a one-time prompt is printed, and **no**
`scripts/verify` is generated.

## S8 — Fast lane (US4, SC-004)

In a project with the kit installed, ask for a one-line fix.

**Expected:** no `spec.md`/`plan.md`/`tasks.md`; one entry in `specs/quick-log.md` with an Evidence
line. Then start a change that touches a schema or a second component — **expected:** the command stops
and promotes to `/speckit.specify`.

## S9 — Continuous execution and the budget (US3, SC-006)

Run `/speckit.implement` on a three-task plan. **Expected:** it completes with no per-phase
confirmation; each task has a commit and a ledger line.

Then run it on a plan whose second task cannot pass verification. **Expected:** it halts at the budget
(3 consecutive failures), the failing task is unticked, and the reason is in the ledger. Simulate a
context loss mid-run and resume — **expected:** no completed task is repeated.

## S10 — Drift reporting (FR-015)

```bash
sed -i '' 's/## Commands/## Commands (edited)/' /tmp/003-demo/AGENTS.md   # macOS; use sed -i on Linux
cd /tmp/003-demo && /path/to/speckit-kit/bin/speckit-init .
```

**Expected:** the installer reports that the managed block differs from the installed one.

## S11 — The kit's own gate (FR-014, SC-005)

```bash
cd /path/to/speckit-kit && ./scripts/self-gate.sh          # full, includes e2e
```

**Expected:** PASS on macOS bash 3.2 and Linux bash 5, including the new assertions for the permission
block, Commands block, `scripts/verify`, autonomy contract, continuous-execution rule, and the quick
command.

## S12 — Reversal (uninit completeness)

```bash
/path/to/speckit-kit/bin/speckit-uninit /tmp/003-demo
git -C /tmp/003-demo status --short
```

**Expected:** the Commands block, `scripts/verify`, the autonomy contract, and the quick command are
removed; a project the user brought their own content to is left clean. `opencode.json` edits are
reversed only where the kit created the file.

---

## Where each scenario is checked

Eight of these are deterministic (files, exit codes, markers) and run in the kit's own gate on every
push. Two need a real agent; `evals/run-scenario-evals.py` automates them against a scripted agent in
CI and against a live one on demand.

| Scenario | Checked by |
| --- | --- |
| S1, S2, S3, S6, S7, S10, S11, S12 | `scripts/self-gate.sh` §5 — init, idempotence, no-clobber, verify, unresolved, drift, the gate itself |
| S4, S5 — the boundary refuses | `self-gate.sh` §1d3 and §1f assert it **mechanically**; `run-scenario-evals.py` asserts the agent's response to it — **live pass recorded 2026-10-19** |
| S8 — the fast lane | `evals/run-scenario-evals.py` (no spec/plan/tasks; one `quick-log.md` entry) — **live pass recorded 2026-10-19** |
| S9 — the budget halt | **live only.** The halt is prompt behaviour with no observable file effect, so there is no oracle to assert against — the honest limit of the split |

**Live pass (2026-10-19):** `python3 evals/run-scenario-evals.py` → `ok S4 (live)`, `ok S8 (live)`,
`SCENARIOS: PASS`. The same run in `--fake` mode is what the gate asserts on every push.

The rule behind S9's ledger resume *is* asserted mechanically: `bin/speckit-resume` computes the
resume point, and `self-gate.sh` §1i tests it with an oracle plus metamorphic relations (monotone
progress, no double completion) across a targeted interrupt.
