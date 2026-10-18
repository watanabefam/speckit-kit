# Progress — plan: specs/003-autonomous-throughput/plan.md
# Resume rule: a task is DONE iff it has a `Task <N>: complete` line. Resume at the first
#   task without one. If the ledger names a different plan, archive it and start fresh —
#   never merge two plans' ledgers.

Task 1: complete (baseline `./scripts/self-gate.sh` PASS at v1.11.0, before changes)
Task 2: complete (`write_managed_block` + `cmd_row` added to bin/speckit-init; bridge rewired; scratch AGENTS.md bridge unchanged apart from the intended pointer + fast-lane row)
Task 3: complete (self-gate §1d2: four artifacts present, installer handles all four, no prepend duplicates the contract)
Task 4: complete (self-gate §5 asserts opencode.json boundary, Commands block, scripts/verify, contract, fast lane; live denial is manual S4)
Task 5: complete (§1d3 P-003 — 11 irreversible actions resolve to deny; includes the trailing-flag force-push)
Task 6: complete (§5 P-002 — installer never clobbers a pre-existing opencode.json)
Task 7: complete (installer §2d writes/prints the permission block)
Task 8: complete (global/autonomy-contract.md → .opencode/autonomy-contract.md)
Task 9: complete (one pointer line in the SPECKIT-BRIDGE block)
Task 10: complete (write_managed_block reports a managed block that differs from the installed copy; observed firing on the kit's own dogfood run)
Task 11: complete (uninit removes the contract and the boundary; boundary comparison is formatting-tolerant because `specify preset add` normalises opencode.json)
Task 12: complete (§5 P-001 — re-run leaves scripts/verify and opencode.json unchanged; AGENTS.md reaches a fixed point)
Task 13: complete (§5 asserts the Commands block and scripts/verify, incl. the unresolved case)
Task 14: complete (§5 P-004 — SPECKIT-COMMANDS markers appear exactly once)
Task 15: complete (detector: package.json scripts, pyproject/pytest/tox, Cargo.toml, go.mod, Makefile)
Task 16: complete (SPECKIT-COMMANDS block written via write_managed_block)
Task 17: complete (scripts/verify generated; create-if-absent; non-zero on first failure)
Task 18: complete (tasks prepend names the recorded verification command)
Task 19: complete (uninit strips the Commands block and removes scripts/verify)
Task 20: complete (§3b markers + §5 check_cmd extended for the continuous-execution rule)
Task 21: PARTIAL — rule presence asserted (§3b "execution budget", §5); behavioural resume is manual S9
Task 22: complete (implement prepend: "Execute continuously, with a stopping condition")
Task 23: complete (preset.yml implement description updated)
Task 24: complete (SKILL.md implement row + loop note)
Task 25: complete (§1d2 asserts commands/speckit.quick.md and that the installer copies it)
Task 26: complete (commands/speckit.quick.md written)
Task 27: complete (installer §2b copies the fast lane)
Task 28: complete (routing row + short-path paragraph in commands/speckit.md)
Task 29: complete (bridge table row, README component/command/layout tables, QUICKSTART, blog note)
Task 30: complete (preset 1.11.0 → 1.12.0; CHANGELOG `## [1.12.0]` is the newest entry)
Task 31: complete (README counts/tables updated)
Task 32: PARTIAL — full gate PASS on macOS bash 3.2; Linux bash 5 pending CI
Task 33: PARTIAL — S1,S2,S3,S6,S7,S10,S11,S12 covered by the gate; S4,S8,S9 are manual (need a live opencode session)
Task 34: complete (spec.md traceability Task column filled)
Task 35: complete (SC-001 evidence recorded in spec.md Success Criteria; fair measurement needs a second feature run)
Task 36: complete (Makefile added; kit Commands block now reads `make test`, scripts/verify runs it)

## Rulings

Ruling: the `-f` force-push cannot be a permission glob — `git push*-f` false-positives on the benign
  `--follow-tags`. Moved to a token-based hook (`block-force-push`), the R5 mitigation the plan named.
  Evidence: §1f behavioural test (6 force forms blocked, 4 benign allowed).
Ruling: `specify preset add/update` rewrites an existing `opencode.json`, stripping blank lines. The
  kit source was made blank-line-free (so a fresh install is byte-identical) and uninit's comparison
  was made formatting-tolerant. Evidence: `cmp` IDENTICAL after the change; §5 uninit test passes.
Ruling: added a `Makefile` so the kit's own Commands block is meaningful (T036). The kit had no
  detectable stack, so its Commands block would otherwise read `unresolved`.
Ruling: the blog's v1.2.0 command table was annotated, not rewritten — it is a historical narrative.

## Close

# Status: implementation complete (committed + pushed as f245193) — 2026-10-18
# Evidence: `./scripts/self-gate.sh` → SELF-GATE: PASS (exit 0); `./bin/speckit-check` → current, kit 1.12.0
# Open: T021/T032/T033 behavioural halves; Linux CI.

## Convergence (2026-10-18)

Ran `/speckit.converge` after the push. Independent review by a fresh context returned 8 findings, all
verified by reproduction. The declared boundary held: **hook 1 and hook 2 are byte-identical** to the
pre-change file (only hook 3 was added).

Appended `## Phase 8: Convergence` — T037 (CRITICAL: overstated CHANGELOG), T038 (CRITICAL: quoted-flag
bypass in both hooks), T039 (HIGH: wrapper/infix deny bypass), T040 (HIGH: uninit verify heuristic),
T041 (HIGH: FR-005 install/lint/typecheck gap), T042 (HIGH: unverified rule precedence), T043 (MEDIUM:
uninit `speckit*` glob), T044 (MEDIUM: gate gaps).

Ruling: converge appends, it does not fix inline (its command contract). The two CRITICALs remain open
until `/speckit.implement` runs the Phase 8 tasks. Note for the next session: a **global** hook in this
environment matches coarse substrings and blocked a diagnostic command containing the literal
`git push -f`; run force-push diagnostics from a file, not the command line.

Parking lot reviewed: all six items kept parked, each with a revisit condition (worktree/parallel →
after Phase 8; eval gate → with a second measurement; sandbox docs → on demand; rule-file signing → if
AGENTS.md becomes remotely sourced; cost budget → with eval instrumentation).

## Phase 8 (2026-10-18)

T037–T041, T043, T044 complete. T042 left open (needs a live opencode session).

- T038: both existing hook predicates now strip quote characters (`tr -d '\42\47'`) before the walk.
  Fixtures added; §1f now blocks 6 no-verify forms and 8 force forms, quoted included.
- T039: a fourth hook, `block-destructive-commands` (publish / supabase db / prisma migrate), with a
  segment guard so `grep -r npm publish .` is allowed. §1f: 8 irreversible forms blocked, 6 benign allowed.
- T040: `uninit` removes `scripts/verify` only when it matches the generated shape.
- T043: `uninit` removes `speckit.md` + `speckit.*.md`, not a `speckit*.md` glob.
- T044: the gate asserts FR-015 drift reporting, and the uninit fixture now has a manifest so
  `scripts/verify` removal is exercised.
- T041: the detector records `install` and adds Python/Rust/Go lint+typecheck (only when a config file
  proves the tool). The contract was updated to match.
- T037: the CHANGELOG no longer claims more than the code does (plugin dependency, precedence
  dependency, and the real uninit comparison are now stated).

Ruling: the FR-015 gate assertion first failed because piping the installer into `grep -q` SIGPIPEs
  the producer and `set -o pipefail` reads it as "not found" — the exact trap the installer documents
  at its §4. Fixed by capturing to a variable first. The gate caught it, not a reading.

Evidence: `./scripts/self-gate.sh` → SELF-GATE: PASS (232 ok, 0 FAIL); `./bin/speckit-check` → current.

## T042 (2026-10-18) — closed deterministically, no live session

Researched online and on CiteKit (see `research.md` Finding 7, sources [32]–[44]). The premise that
only a live session could settle it was false:

- opencode resolves with `rules.findLast(...)` — confirmed in the docs [32], a source walkthrough [33],
  the project's own tests [36], and the **installed 1.18.30 binary**.
- An open PR changes it to most-specific-wins (ties by position) [35], so the dependency had an expiry
  date rather than being unknown.
- The hazard is named in the literature — shadowing/conflict in access-control rules [40][41], rule
  ordering in firewalls [42][43], deny-overrides as the safe combining semantics [44].

Ruling: remove the dependency rather than verify it once. The rules are written so both semantics
agree (every deny is last AND at least as specific as what it overrides), and the gate now asserts it
under **both** folds, plus the structural property that no deny precedes a non-deny. Verified before
asserting: all 11 irreversible actions and a command derived from every deny pattern resolve to `deny`
under both.

Evidence: `./scripts/self-gate.sh` → §1d3 "11 irreversible actions deny under last-match AND
most-specific" + "every deny is later than every non-deny"; full gate PASS.

Remaining open in this spec: T021/T032/T033 (behavioural halves needing a live session; Linux bash 5).
