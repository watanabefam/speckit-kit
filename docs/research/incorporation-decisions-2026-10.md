# Incorporation decision record — competitor & tooling sweep

**Date:** 2026-10-22 · **Method:** GitHub API metadata + upstream file retrieval + local execution.
**Companion:** `verification-tooling-2026-10.md` (verification findings). This document answers a
different question: **for each thing examined, what exactly do we take, and where does it land?**

**Supersedes** the one-line verdicts in `verification-tooling-2026-10.md` §2 for the six workflow
repos. Those verdicts were made at a single level of analysis ("is the rule executable or prose?")
and dismissed four projects that carry distinct, adoptable mechanics.

**Evidence grades used below:**
`[measured]` run on this machine · `[fetched]` read the actual source file from upstream ·
`[read]` read the README/docs only · `[meta]` GitHub API metadata only.

---

## Decision table

| Examined | Stars | Evidence | What we take | Lands in |
|---|---|---|---|---|
| **obra/superpowers** | 303,335 | `[fetched]` + `[measured tree]` | TDD delete-work-before-tests; two-stage review; worktree isolation; task-start/task-done pairing | **006** |
| **gotalab/cc-sdd** | 3,732 | `[read]` | Boundary-first tasks (`_Boundary:_`, `_Depends:_`); dependency-wave batching; cross-spec contradiction review | **006** |
| **anton-abyzov/specweave** | 167 | `[measured]` + `[read]` | Claims; handoff/pickup with uncommitted-edit snapshot; `review` exit-3; note; committed memory; glossary check | **006** |
| **Fission-AI/OpenSpec** | 72,704 | `[read]` | Delta specs (`## ADDED Requirements`); `/opsx:archive` dated history; in-flight `changes/` dir | **006** |
| **buildermethods/agent-os** | 5,532 | `[fetched]` | Nothing | **Rejected** |
| **eyaltoledano/claude-task-master** | 28,263 | `[meta]` | Nothing | **Rejected** |
| **diff_cover** | 849 | `[read]` | Assert coverage on the **changed lines** | **005 (amend)** |
| **trufflehog** | 28,631 | `[read]` | Verified-credential tier — the only FP answer | **005 (amend)** |
| **schemathesis** | — | `[read]` | Concrete instance of a generated property for HTTP APIs | **005 (amend, optional)** |
| **reviewdog** | 9,686 | `[read]` | Findings posted onto the PR diff | **006** |
| **pre-commit** | 15,650 | `[read]` | Local runner for the cheap gates | **006** |
| BMAD-METHOD | 54,422 | `[read]` | Nothing | **Rejected** (unchanged) |
| promptfoo / Inspect / DeepEval | — | `[measured]` | Nothing | **Rejected** (unchanged) |
| Kiro IDE / Tessl | — | `[read]` | Nothing | **Rejected** (unchanged) |

---

## The finding that changes the verdict on superpowers

`superpowers` was dismissed in one table cell. It is the largest project in the sweep and it has a
**real executable completion gate**, at `skills/executing-plans/scripts/task-done` `[fetched]`:

```
rc=0
"$@" > "$log" 2>&1 || rc=$?
tail -n 5 "$log"
if [ "$rc" -ne 0 ]; then
  echo "task-done: test command exited $rc; Task $n NOT recorded ..." >&2
  exit "$rc"
fi
last=$(grep -v '^[[:space:]]*$' "$log" | tail -n 1) || last="(no output)"
line="Task $n: complete (commits $(git rev-parse --short=7 "$base")..$(git rev-parse --short=7 HEAD), tests: $cmd → $last)"
printf '%s\n' "$line" >> "$ledger"
```

It **runs the command itself** rather than accepting a claim, records nothing on failure, and ties the
completion line to a commit range (`BASE..HEAD`). That is better than what the kit had before 1.14.0.

**And its hole is exactly our item 1.** It records the *last output line* and nothing else. Nothing
counts how many tests ran. A command that exits 0 having examined nothing is recorded as `complete`.

Everything else in superpowers is prose: 15 skills, `[fetched]` `verification-before-completion/SKILL.md`
is 120 lines and teaches the identical doctrine to our item 1 — *"NO COMPLETION CLAIMS WITHOUT FRESH
VERIFICATION EVIDENCE"*, a table of what each claim **requires** versus what is **not sufficient**, and a
`Rationalization Prevention` table. Its `hooks/` directory `[fetched]` contains only a `SessionStart`
hook that injects skill text — **no blocking hook anywhere.**

**This is now a three-way convergence:** this kit, superpowers, and cc-sdd independently wrote the same
doctrine (evidence before claims; line-by-line requirements checklist; red-green verification of a
regression test; don't trust an agent's success report). Two of the three wrote it as prose.
`superpowers` §"Common Failures" independently contains our item 2 as a table row:
*"Requirements met → requires: line-by-line checklist → not sufficient: tests passing"*.

That is strong support for **what** to build. The differentiation is unchanged and now better evidenced:
prose is a request, `exit 1` is a guarantee.

## What superpowers has that we do not `[read]`

- **`test-driven-development`: "Deletes code written before tests."** A mechanic, not advice — the
  RED-GREEN-REFACTOR cycle is enforced by discarding implementation that preceded its test.
- **Two-stage review:** spec compliance *first*, then code quality.
- **`using-git-worktrees`:** isolated workspace per feature, then **verifies a clean test baseline
  before starting** — i.e. it refuses to build on a red or dirty baseline.
- **`task-start` prints a BASE SHA that `task-done` records** — a cheap, real change-range binding.

## What cc-sdd has that we do not `[read]`

- **Boundary-first specs:** `design.md` carries a File Structure Plan that *drives task boundaries*;
  tasks carry `_Boundary:_` and `_Depends:_`; review looks for **boundary violations**, not style.
- **`/kiro-spec-batch`:** a roadmap decomposed into specs **by dependency wave**, run in parallel, with
  **cross-spec review** for contradictions, duplicated responsibilities and interface mismatches.
- **`/kiro-discovery`** routes new work five ways and writes `brief.md` / `roadmap.md` for resumption.
- Learnings propagate through `## Implementation Notes` in `tasks.md`.
- TDD is gated **behind a feature flag** — an admission that test-first is not always wanted.

Its philosophical bet is worth recording because it differs from the kit's: *"Code remains the source of
truth. Specs make the boundaries between parts of the code explicit."* This kit treats `spec.md` as the
source of truth for intended behaviour. Both can be true at once — behaviour in the spec, structure in
the code — but 006 should say which governs when they disagree.

## What SpecWeave has that we do not `[read]`, with its measured holes kept in view

Capabilities worth taking: **`task claim`** (with `pickup` showing *claims held by others*);
**`handoff`/`pickup`** — releases claims, records why you stopped, pushes the branch **plus a snapshot of
uncommitted edits**, and prints the next task with its acceptance criteria in any other tool or machine;
**`auto-handoff`** at a configurable percentage of the plan limit; **`review` returning exit 3** for
"fix first" (a third state, like our `INCOMPLETE`); **`note`**; committed project memory; and
**`glossary check --strict`** (avoided words and stale names, exit 1 for CI).

Its README states at §"The loop" `[read]`: *"`done` refuses a failing test and stores the evidence in the
ledger."* **Measured, it does not:** `task done T-01 --evidence "reviewed it myself, looks fine"` returned
`rc=0` with no command run. A promise in the README that the code does not enforce is the single best
illustration of this spec's thesis, and it is worth citing in 006 as the reason claims are enforced by
command rather than by documentation.

## Rejections, with reasons better than a table cell

- **agent-os** `[fetched]`: the entire product is **five markdown commands** (`discover-standards`,
  `index-standards`, `inject-standards`, `plan-product`, `shape-spec`), one profile directory with a
  `tech-stack.md`, and three install scripts; `config.yml` is 8 lines of profile-inheritance plumbing.
  The one real idea — extract conventions from a codebase, index them, then inject only the *relevant*
  subset — is a prompt-context optimisation with no outcome evidence, and it buys a permanent standards
  maintenance burden. The kit deliberately keeps a small, always-injected `AGENTS.md`. **Rejected.**
- **task-master** `[meta]`: last push 2026-04-28; an MCP server exposing ~40 tools plus a PRD→task-graph
  decomposition. Its distinguishing idea (dependency-annotated tasks) is done better and more cheaply by
  cc-sdd's `_Depends:_`, and the tool surface is the opposite of what this kit wants. **Rejected.**
- **BMAD** `[read]`: persona/role ceremony with no executable artefact. **Rejected** (unchanged).
- **promptfoo / Inspect / DeepEval**: solve prompt regression, not code correctness; the measurement we
  needed was 30 lines. **Rejected** (unchanged).

---

## Amendments this audit forces on 005

Three findings land in the verification cluster. 005 stays coherent — these sharpen mechanisms already
in it rather than adding a new one.

1. **`diff_cover`'s actual idea was lost and is stronger than what I wrote.** I specified "run only the
   tests that can be affected" (test *selection*). `diff_cover` asserts **coverage of the changed
   lines**. That is the empty-check invariant applied to the change itself: new lines that no test
   executes are precisely "looked at nothing", scoped to the diff. Cheaper than selection, and it cannot
   be gamed by a passing suite that never exercises the new code. **→ new requirement under US4.**
2. **`trufflehog`'s verified-credential check is the answer to the strongest weakness in the spec.** US6
   currently says "false positives run 25–99%, so stage it and don't block". Trufflehog does not
   pattern-match — it **tests whether the credential works against the provider**, which converts a
   high-FP signal into a near-certain one *for the formats it supports*. Dropping it left a hole.
   **→ new requirement under US6**, in the network-needed tier (with osv-scanner), explicitly scoped to
   **verified** findings only.
3. **My rejection of "model-as-judge" was broader than its evidence, and the spec's Out of Scope section
   overstates it.** The 13.6% verdict-flip evidence is against a *judge returning pass/fail*. It is
   **not** evidence against a *reviewer that files findings for a human* — which is what cc-sdd ships and
   what SpecWeave ships (`review`, exit 0/3). The spec must say which one is rejected and why.
   **→ repair the Out of Scope bullet.**
4. **`schemathesis`** is the concrete instance of item 7's property technique for services with an
   OpenAPI schema. **→ optional requirement under US7**, not a new item.

Everything else in cluster B goes to **006** (`specs/006-workflow-orchestration/`).
