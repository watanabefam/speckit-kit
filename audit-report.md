# 📋 Audit Report: speckit-kit

Date: 2026-10-21 (fresh pass after commit cb56ab4)
Audited by: `audit-project` skill

## Overall Score: 97.2/100 — 🟢 Excellent

| Category | Initial | Now | Weight | Weighted |
|---|---|---|---|---|
| Structural compliance (Phase 2) | 37/100 | 95/100 | 20% | 19.0 |
| Template consistency (Phase 3) | 100/100 | 100/100 | 20% | 20.0 |
| Deployment health (Phase 4) | 95/100 | 100/100 | 20% | 20.0 |
| Convention gaps (Phase 5) | 94/100 | 96/100 | 10% | 9.6 |
| Project health (Phase 7) | 88/100 | 93/100 | 20% | 18.6 |
| Security scan (Phase 8) | 95/100 | 100/100 | 10% | 10.0 |
| **Total** | **83.9** | **97.2** | | **97.2** |

**Verdict: 🟢 PASS — 0 failures. 2 accepted deviations, 3 observations. Nothing actionable left
that can be fixed without harming the product.**

### Verification evidence (all run, not inferred)

| Check | Command | Result |
|---|---|---|
| Recorded verification | `./scripts/verify` | **EXIT=0, `SELF-GATE: PASS`**, 0 FAIL lines |
| Spec Kit install | `speckit-check .` | **`constitution conforms` → `current, nothing to do`** |
| Command-guard probes | 8 command strings | **8/8 correct** |
| Path-guard probes | 12 payloads on the real hook body | **12/12 correct** |
| Fail-open regression | protected path, env var absent | **exit 2** (was exit 1 — crashed open) |
| Source ↔ installed pairs | 5 `diff -q` comparisons | **5/5 identical** |
| Markdown relative links | 9 links scanned | **0 broken** |
| Placeholder scan | `TODO(`/`FIXME`/`TBD`/`[ALL_CAPS_` | **0 real** (all instructional text) |
| Tracked OS noise | `git ls-files` | **none** |

---

## This pass: one new defect found and fixed

**Stale eval fixture** — `evals/trigger-evals.json:100` (case `snt-07`) told the model to read
`specs/001-faq-block/spec.md`, a path that has never existed in this repo. A trigger eval asks
"should the skill activate on this prompt?", and a prompt referencing a missing file can change the
answer for the wrong reason — the model may react to the dead path rather than to the intent.

Repointed to `specs/003-autonomous-throughput/spec.md`, which exists. JSON re-validated; the
already-committed specs list confirmed.

---

## Earlier fixes (all still green)

1. **Command guard bypass** — the token walk only inspected tokens after the first `git`, so
   `env core.hooksPath=/dev/null git commit` escaped. Now two passes.
2. **Path guard failed open** — ran under `set -u` reading `$OPENCODE_PROJECT_DIR`, which the plugin
   never exports (only `OPENCODE_CONFIG_CONTENT`). Aborted with exit 1, and only exit 2 blocks, so
   the whole generated-file guard protected nothing. Now defaults the variable.
3. **Path guard ignored multiedit shapes** — paths were read from the payload root while this plugin
   nests args under `tool_args`. Now reads both.
4. **Two tools not installed** — `speckit-mcp`, `speckit-resume` symlinked; all five resolve.
5. **SKILL.md** — `allowed-tools` added, loop numbered `Step 1..6`, `## Where to go next` added.
6. **`.ignore`** — added.
7. **Constitution** — was still the raw scaffold with every principle a placeholder. Ratified at
   1.0.0; reasoning in `decisions/0001-ratify-the-constitution.md`.

---

## Observations (checked, not defects, deliberately not "fixed")

**A. Historical spec artifacts predate the current template.**
`scripts/check-section-integrity.sh` against the resolved templates, after the 2026-10-21 fix:

| Artifact | Result |
|---|---|
| `003/spec.md` | 1 missing heading — substance present in prose |
| `003/plan.md` | **conformant** |
| `003/tasks.md` | 3 missing headings — renamed or re-levelled |
| `001/spec.md`, `001/plan.md`, `001/tasks.md` | written 2026-10-04, before several template additions |
| `002/spec.md`, `002/plan.md`, `002/tasks.md` | written 2026-10-17 |

The checker compared heading strings verbatim, so `### Key Entities` never matched the template's
`### Key Entities *(include if feature involves data)*` and a conformant spec reported MISSING.
That is fixed: guidance parentheticals, trailing `⚠️` and italic notes are stripped before
comparison, and a heading that appears twice (`### Worked example` in `tasks-template`) no longer
reads as reordered. The remaining failures are genuine differences in what a heading *says*:

- `003/spec.md` covers "which document wins" in prose under `## Normative Status` ("where the two
  disagree, this spec prevails"). The substance exists; the sub-heading does not.
- `003/tasks.md` writes `## Phase 7: Polish & Cross-Cutting Concerns` where the template says
  `## Phase N: …`, `### Task-level dependencies` where it says `### User Story Dependencies`, and
  puts `Parallel Opportunities` at level 2 where the template has level 3.

For 001 and 002 the drift is real but historical: they were authored against earlier template
versions, they record completed features, and retrofitting sections would rewrite records to say
things their authors did not write at the time. `CI` does not check them, and neither does
`speckit-check`. Recommendation: leave historical artifacts alone; enforce the check at authoring
time on new work.

**B. `model:` absent from SKILL.md frontmatter (accepted WARN).**
Adding it would fail the project's own gate — `scripts/self-gate.sh:633` allows only
`{name, description, license, compatibility, metadata, allowed-tools}`. The kit is deliberately
model-agnostic. Structurally impossible to satisfy both rules; the gate wins.

**C. Two addenda exceed 200 lines (accepted WARN).**
`plan-addendum.md` (258), `spec-addendum.md` (225). The rubric targets *reference* files a reader
navigates; these are template fragments composed **into** users' `plan.md` and `spec.md`, so a table
of contents inside them would be injected into every generated artifact. A real fix is a
restructuring, which is a preset change needing a version bump. Scored as a warning rather than
reclassified to N/A, deliberately — re-scoring my own finding upward mid-audit would be the exact
"rounding up to green" this workflow exists to prevent.

**D. Documented deviation:** `argument-hint` / `user-invocable` intentionally absent —
`self-gate.sh:633` rejects them as non-portable. Covered above.

---

## Status of the two flagged guards

Both guard classes were driven with real payloads, not read. The path guard in particular is
verified **with the environment variable absent**, because that is how the plugin actually runs —
and that single case is what exposed the fail-open bug that the harness's UNVERIFIED label misses.

---

## Recommended next

Nothing is required for the project to be correct. Optional, in priority order:

1. When `001`/`002` are next touched for any reason, backfill their missing sections then — not as a
   standalone rewrite.
2. ~~Teach `check-section-integrity.sh` to ignore template parentheticals.~~ Done 2026-10-21, with
   five gate tests. What remains is option 1 (backfill `001`/`002` if touched) and deciding where
   the check script lives for adopters — see the open question in `specs/quick-log.md`.
3. Next preset version: consider splitting the two long addenda.

Re-audit with `skill("audit-project")` after any further change.
