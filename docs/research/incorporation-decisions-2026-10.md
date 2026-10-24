# Incorporation decision record — competitor & tooling sweep

**Date:** 2026-10-22 · **Method:** GitHub API metadata + upstream file retrieval + local execution.
**Companion:** `verification-tooling-2026-10.md` (verification findings). This document answers a
different question: **for each thing examined, what exactly do we take, and where does it land?**

**Supersedes** the one-line verdicts in `verification-tooling-2026-10.md` §2 for the six workflow
repos. Those verdicts were made at a single level of analysis ("is the rule executable or prose?")
and dismissed four projects that carry distinct, adoptable mechanics.

**Evidence grades used below:**
`[measured]` run on this machine · `[fetched]` read the actual source file at a recorded commit ·
`[read]` read the README/docs only · `[meta]` GitHub API metadata only.

**Grades were raised on 2026-10-23.** Every repo in this table was cloned and every claim below was
checked against its source, at the commits in the re-verification table at the end. Six claims did not
survive unchanged; two of those forced a requirement to change. Where a row below still carries a grade
lower than `[fetched]`, that grade is what the re-verification could establish, not what the first pass
assumed.

---

## Decision table

| Examined | Stars | Evidence | What we take | Lands in |
|---|---|---|---|---|
| **obra/superpowers** | 304,187 | `[fetched]` + `[measured]` | TDD delete-work-before-tests; per-task review with two required verdicts; worktree isolation; task-start/task-done pairing | **006** |
| **gotalab/cc-sdd** | 3,737 | `[fetched]` | Boundary-first tasks (`_Boundary:_`, `_Depends:_`, `(P)`); dependency-wave batching; ten-check cross-spec review | **006** |
| **anton-abyzov/specweave** | 167 | `[measured]` + `[fetched]` | Claims with overlap exits; handoff/pickup with uncommitted-edit snapshot; heuristic secret redaction; `review` exit-3; note; committed memory; glossary check | **006** |
| **Fission-AI/OpenSpec** | 72,853 | `[fetched]` | Delta specs (`## ADDED Requirements` + MODIFIED/REMOVED/RENAMED); dated `changes/archive/` history; in-flight `changes/` dir; "no delta headers remain after sync" invariant | **006** |
| **buildermethods/agent-os** | 5,537 | `[fetched]` | Nothing | **Rejected** |
| **eyaltoledano/claude-task-master** | 28,270 | `[fetched]` | Nothing | **Rejected** |
| **diff_cover** | 849 | `[fetched]` | Assert coverage on the **changed lines** — needs git plus a coverage report, so it is not a shell-repo gate | **005 (amend)** |
| **trufflehog** | 28,678 | `[fetched]` | Verified-credential tier — the only FP answer; `--only-verified` and `--fail` (exit 183) both exist, but hook mode fails on *any* finding | **005 (amend)** |
| **schemathesis** | — | `[fetched]` | Concrete instance of a generated property, for OpenAPI **and GraphQL** APIs | **005 (amend, optional)** |
| **reviewdog** | 9,692 | `[fetched]` | Findings posted onto the PR diff (`-diff="git diff ..."`, `-efm`) | **006** |
| **pre-commit** | 15,650 | `[fetched]` | Local runner for the cheap gates (a hook installer, not a gate) | **006** |
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

## What superpowers has that we do not `[fetched]`

- **`test-driven-development`: "Deletes code written before tests."** A mechanic, not advice — the
  RED-GREEN-REFACTOR cycle is enforced by discarding implementation that preceded its test
  (`skills/test-driven-development/SKILL.md:37` — *"Write code before the test? Delete it. Start over."*,
  repeated at `:231` and `:254`).
- **Per-task review with two required verdicts:** spec compliance **and** task quality, both from one
  task-scoped review, with a single broad whole-branch review at the end
  (`skills/subagent-driven-development/SKILL.md:8,240-256`). Corrected 2026-10-23: this is **not** two
  sequential stages — the first pass read it that way, and the source says "a task review (spec
  compliance + code quality)". A report missing either verdict is rejected.
- **`using-git-worktrees`:** isolated workspace per feature, then **verifies a clean test baseline
  before starting** — it refuses to build on a red or dirty baseline (`## Step 3: Verify Clean
  Baseline`, `:121-123`). Two details the first pass missed, and one of them changed a requirement:
  the skill's **first rule is to use the host's native worktree tool** and it calls a raw
  `git worktree add` "the #1 mistake" because it creates state the harness cannot see; when the
  sandbox denies worktree creation it falls back to working **in place, sequentially** (`:55,100,164`).
- **`task-start` prints a BASE SHA that `task-done` records** — a cheap, real change-range binding
  (`skills/executing-plans/scripts/task-start:28` → `echo "base: $(git rev-parse HEAD)"`).

## What cc-sdd has that we do not `[fetched]`

- **Boundary-first specs:** `design.md` carries a File Structure Plan that *drives task boundaries*;
  tasks carry `_Boundary:_` and `_Depends:_`; review looks for **boundary violations**, not style.
- **`/kiro-spec-batch`:** a roadmap decomposed into specs **by dependency wave**, run in parallel, with
  a **ten-check cross-spec review** (`.../skills/kiro-spec-batch/SKILL.md:85-120`): data-model
  consistency, interface alignment, duplicate functionality, dependency completeness, naming, shared
  infrastructure, task-boundary partition, roadmap continuity, architecture-boundary integrity, and
  change-friendly decomposition. The first pass summarised this as "contradictions, duplicated
  responsibilities and interface mismatches" — a fair abstract, but three of the ten checks (dependency
  completeness, shared infrastructure, boundary partition) were not recorded anywhere.
- **`/kiro-discovery`** routes new work five ways and writes `brief.md` / `roadmap.md` for resumption.
- Learnings propagate through `## Implementation Notes` in `tasks.md`.
- TDD is gated **behind a feature flag** — an admission that test-first is not always wanted.

Its philosophical bet is worth recording because it differs from the kit's: *"Code remains the source of
truth. Specs make the boundaries between parts of the code explicit."* This kit treats `spec.md` as the
source of truth for intended behaviour. Both can be true at once — behaviour in the spec, structure in
the code — but 006 should say which governs when they disagree.

## What SpecWeave has that we do not `[fetched]`, with its measured holes kept in view

Capabilities worth taking, each checked in source on 2026-10-23:

- **`task claim`** — `src/cli/commands/task.ts:7,198-210`: appends a claim, and distinguishes a **lost
  race (exit 3)** from **overlapping `Files` with a live claim (exit 4)**; stale claims are takeable, and
  `next`/`claim` print the task's acceptance criteria. Stronger than the first pass recorded, which saw
  the claim and not the overlap exit.
- **`handoff`/`pickup`** — releases claims, records why you stopped (`--reason`, `--summary`, `--next`,
  `--gotcha`, `--decision`), captures a **full diff of uncommitted edits**, and prints the next task for
  any other tool or machine (`src/core/session/work-handoff.ts:4,55-59`).
- **`auto-handoff`** — corrected: the threshold is a percentage of a **usage window** (a rate-limit
  window), not "of the plan limit", and it has three modes — `suggest` (tells you once and keeps
  working), `enforce` (hands off and stops), `checkpoint` (local checkpoints only), plus a `--at`
  percentage (`src/cli/commands/auto-handoff.ts:223,235,360`).
- **`review` returning exit 3** for "fix first" (a third state, like our `INCOMPLETE`) —
  `src/cli/commands/review.ts:7,141`: `const code = verdict === 'ship' ? 0 : 3`. Note the collapse: **a
  reviewer that returns no verdict is indistinguishable from "fix first"**, which is a reason our
  FR-038 requires a finding to record how it was established rather than relying on a missing verdict.
- **`note`** (`src/cli/commands/pickup.ts:2,208`), committed project memory, and
  **`glossary check --strict`** (exit 1 when drift exists — `src/cli/commands/glossary.ts:42`).
- **Handoff secret scrubbing** — corrected: it **redacts** both the handoff document and the captured
  diff with twelve regex patterns, records counts in a `Redaction` section, **and then pushes anyway**
  (`src/core/session/work-handoff.ts:157-171`, `src/core/session/handoff-remote.ts:89-143`). There is no
  refusal path. The module's own header disclaims the guarantee: *"This is a HEURISTIC baseline (regex
  only) — an empty redaction list is NOT a guarantee the content is clean"*
  (`src/core/session/handoff-secret-scrub.ts:3-7`). Our FR-037 and SC-010 are therefore **stronger than
  upstream, not inherited from it**: they require that nothing is pushed when scrubbing cannot run. The
  first pass attributed the stricter rule to the upstream docs; that was wrong, and the strictness is
  ours.

Its README states at §"The loop" `[read]`: *"`done` refuses a failing test and stores the evidence in the
ledger."* **Measured, it does not:** `task done T-01 --evidence "reviewed it myself, looks fine"` returned
`rc=0` with no command run. A promise in the README that the code does not enforce is the single best
illustration of this spec's thesis, and it is worth citing in 006 as the reason claims are enforced by
command rather than by documentation.

## Rejections, with reasons better than a table cell

- **agent-os** `[fetched]`: the entire product is **five markdown commands** (1147 lines total:
  `discover-standards`, `index-standards`, `inject-standards`, `plan-product`, `shape-spec`), one profile
  directory with a `tech-stack.md`, and **three scripts** (one installer, one profile sync, one shared
  functions file — not "three install scripts"), and a `config.yml` that is **10 lines**, 8 of them
  commented-out plumbing. Corrected 2026-10-23 from "8 lines of profile-inheritance plumbing".
  The one real idea — extract conventions from a codebase, index them, then inject only the *relevant*
  subset — is a prompt-context optimisation with no outcome evidence, and it buys a permanent standards
  maintenance burden. The kit deliberately keeps a small, always-injected `AGENTS.md`. **Rejected.**
- **task-master** `[fetched]`: last commit 2026-04-23, last push 2026-04-28; an MCP server whose
  registry holds **43 tool entries** (7 "core", 14 "standard"; `mcp-server/src/tools/tool-registry.js:59`)
  plus a PRD→task-graph decomposition. Its distinguishing idea (dependency-annotated tasks) is done
  better and more cheaply by cc-sdd's `_Depends:_`, and the tool surface is the opposite of what this
  kit wants. **Rejected.**
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

---

## Corrections and completions after the independent check (2026-10-22)

An adversarial check (`docs/research/spec-vs-research-check-2026-10-22.md`) found that four mechanics marked
in the table above as landing in **006** did not appear as requirements, and that one upstream mechanic this
table never listed is load-bearing. Both specs were repaired; this section records what changed so the
table's "lands in" column is true again.

| Mechanic | Was | Now |
|---|---|---|
| superpowers — **worktree isolation** | listed, no requirement | `006` **FR-033** (one `git worktree` per worker), **SC-001**/SC-008 dependent on it |
| superpowers — **task-start BASE SHA ↔ task-done** | listed, no requirement | `006` **FR-035** (start records base commit, completion records the range) |
| cc-sdd — **dependency-wave batching** | listed, only `_Depends:_` landed | `006` **FR-036** (independent tasks startable as a wave) |
| specweave — **`glossary check --strict`** | listed, no requirement | `006` **FR-040** (deprecated/avoided terminology checkable, non-zero in CI) |
| specweave — **handoff scrubs secrets before pushing** (from the upstream handoff docs; this table never listed it) | absent | `006` **FR-037**, **SC-010** (redact or do not push) |
| cc-sdd — **cross-spec contradiction review** | partially landed (amendments only) | `006` **FR-026** widened to specifications worked in the same batch |
| review as findings | adopted on `[read]` evidence, no accuracy requirement | `006` **FR-038**/FR-039, **SC-011** (how established, plus measured precision before findings count) |
| claims | adopted, no substrate | `006` **FR-001** now names an atomic acquisition; `git update-ref --stdin` `create` was measured to fail rather than overwrite |

Two further adjustments belong here rather than in the specs:

- The TDD mechanic is **mechanism-justified**, not evidence-justified. `[read]` superpowers README is the only
  source in this audit, and the defect-reduction literature on test-first is contested. `006` US3 now says so.
- The audit's own "13.6% judge instability" reason for rejecting verdicts is mis-attributed in
  `verification-tooling-2026-10.md` §2/§7; see that file's §12 item 2. The rejection stands on a different
  mechanism (run-to-run self-inconsistency on identical input), and the reviewer's own failure mode is
  measured precision, not absence of flipping.

---

## Re-verification at source level (2026-10-23)

**Why.** Nearly every row above was graded by reading a README or the GitHub API. A README claim is not an
implementation claim — that is this document's own thesis, and the sharpest example of it is inside the
sweep: SpecWeave's README says `done` refuses a failing test, and the code does not. So each adopted and
each rejected mechanic was re-read at its source.

**Method.** Shallow clone of all eleven repos into a scratch directory (gitignored, never committed), then
the specific claim read in the specific file, with `git log -1` recorded so the reading can be reproduced
later. No peer CLI was executed in this pass; the two `[measured]` findings are the earlier runs and are
unchanged.

| Repo | Commit read | Claims checked | Result |
|---|---|---|---|
| obra/superpowers | `2ce8aa1` 2026-10-21 | 15 skills; 120-line `verification-before-completion`; `NO COMPLETION CLAIMS…`; Common-Failures row; hooks; TDD delete; task-start/`task-done`; worktree skill | all confirmed; 2 corrections |
| gotalab/cc-sdd | `e2a0c67` 2026-09-23 | `_Boundary:_`/`_Depends:_`; File Structure Plan; batch; discovery; Implementation Notes; TDD flag; philosophy quote | all confirmed; 1 addition |
| anton-abyzov/specweave | `b26e05e` 2026-10-23 | claim/pickup/note; review exit 3; auto-handoff; glossary `--strict`; handoff scrubbing | all confirmed; 2 corrections |
| Fission-AI/OpenSpec | `56ef0ac` 2026-10-23 | delta headings; dated archive; in-flight `changes/` | confirmed; 1 naming correction |
| buildermethods/agent-os | `e892e61` 2026-10-07 | five commands; profile; scripts; `config.yml` | confirmed; 2 corrections |
| eyaltoledano/claude-task-master | `c0c98d3` 2026-04-23 | tool surface; PRD decomposition | confirmed; 1 correction |
| Bachmann1234/diff_cover | `400061f` 2026-10-22 | changed-line coverage; `--fail-under` | confirmed; 1 constraint added |
| trufflesecurity/trufflehog | `d6ea4a5` 2026-10-23 | `Verified`; `--only-verified`; `--fail` | confirmed; 1 divergence added |
| reviewdog/reviewdog | `272537b` 2026-10-23 | findings on the PR diff | confirmed |
| pre-commit/pre-commit | `8cb5845` 2026-10-20 | local hook framework | confirmed, with a sharper description |
| schemathesis/schemathesis | `24fb8ea` 2026-10-23 | generated properties from a schema | confirmed; scope widened |

### Claims that did not survive

| # | Claim as first written | What the source says | Grade |
|---|---|---|---|
| 1 | superpowers does "two-stage review: spec compliance *first*, then code quality" | It is **one task-scoped review with two required verdicts** (`spec compliance + code quality`), plus one broad whole-branch review at the end — not sequential stages. `subagent-driven-development/SKILL.md:8,240-256` | `[fetched]` |
| 2 | superpowers `using-git-worktrees` means "`git worktree` per task" | Its **first rule is the host's native worktree tool**; raw `git worktree add` is called "the #1 mistake" (phantom state the harness cannot see); when the sandbox denies worktree creation it falls back to **in-place, sequential** work. `:55,100,164` | `[fetched]` |
| 3 | SpecWeave `auto-handoff` fires at "a configurable percentage of the plan limit" | It is a percentage of a **usage window** (rate limit), with `suggest`/`enforce`/`checkpoint` modes and `--at`. `auto-handoff.ts:223,235,360` | `[fetched]` |
| 4 | SpecWeave handoff "scrubs secrets before pushing — redact or do not push", attributed to upstream docs | It **redacts by regex and pushes anyway**: twelve patterns, counts in a `Redaction` section, no refusal path, and the module header says an empty redaction list is **not** a guarantee. `handoff-secret-scrub.ts:3-7`, `work-handoff.ts:157-171`, `handoff-remote.ts:89-143` | `[fetched]` |
| 5 | SpecWeave `review` exit 3 means "fix first" | True, but `verdict === 'ship' ? 0 : 3` also fires when the reviewer **returns no verdict** — a missing verdict is indistinguishable from a rejection. `review.ts:7,141` | `[fetched]` |
| 6 | "`/opsx:archive`" | No such slash command: archive is the `openspec-archive-change` skill (invoked as "opsx archive"). The mechanic also carries an invariant the sweep missed: after syncing deltas, **no delta-style heading may remain in the main spec**. `skills/openspec-archive-change/SKILL.md:157` | `[fetched]` |
| 7 | agent-os `config.yml` is "8 lines of profile-inheritance plumbing"; three "install scripts" | `config.yml` is **10 lines**, 8 of them commented out; the three scripts are an installer, a profile sync and a shared-functions file. `config.yml`, `scripts/` | `[fetched]` |
| 8 | task-master exposes "~40 tools" (on `[meta]`) | **43 registry entries** (7 core, 14 standard); last commit 2026-04-23. `mcp-server/src/tools/tool-registry.js:59` | `[fetched]` |

### What the corrections changed

1. **`006` FR-033 was behind its own source.** It required "`git worktree` per task". Two independent
   projects now say the opposite about *how*: superpowers makes the host's native facility the first rule
   and a raw `git worktree add` the named mistake, and SpecWeave's HEAD commit today is *"Create agent
   worktrees in `.worktrees/`, never beside the project"*. A requirement that mandates the raw command
   would produce the phantom state both of them warn about. FR-033 and the `Checkout` entity now require a
   per-worker checkout **created by the host's facility where one exists**, **placed inside the
   repository**, and falling back to **sequential in-place** work when creation is refused — never to a
   shared tree.
2. **A stronger requirement was mis-attributed.** FR-037/SC-010 are stricter than SpecWeave, not derived
   from it. No text change: the stricter rule is the right one, and the record now says where it came
   from. The lesson worth keeping is that "scrubbed" without a verified check means "regex ran", which is
   exactly the claim-versus-evidence distinction 005 exists to enforce.
3. **`005` FR-033/FR-034 had a gap that source-reading exposed.** diff_cover's `--expand-coverage-report`
   exists because a coverage report can **omit a file entirely**; an omitted line is not an uncovered line.
   005 said only a full-suite profile may be read as "no test executes this line", which is necessary but not
   sufficient — a full-suite run with a partial report can still omit lines. **Closed 2026-10-23** by
   amendment A-005-1 (FR-043, qualified FR-034, extended SC-008, property P-013, task T077,
   `decisions/0006`), after the formats themselves were read; see *Convergence* below for why the wording
   changed from "unknown" to a five-state classification.
4. **Two divergences from upstream defaults are now explicit rather than assumed.** trufflehog's hook mode
   sets `--fail` on **any** finding, not only verified ones (`main.go:930-931`); 005 limits blocking to
   provider-confirmed findings, which is deliberately narrower. And diff_cover requires `git` plus a
   coverage report in a supported format, so changed-line coverage is a **tiered** capability in 005 rather
   than a universal gate — a shell-only repository cannot produce the report at all.

### Confirmed exactly as written

superpowers' 15 skills, the 120-line `verification-before-completion` skill, its headline, the
"Requirements met → line-by-line checklist → tests passing" row, a hooks directory containing only a
`SessionStart` hook (no blocking hook anywhere), TDD "delete it, start over", and `task-start` printing
`base: <sha>`; cc-sdd's `_Boundary:_`/`_Depends:_`/`(P)` markers, File Structure Plan driving boundaries,
`## Implementation Notes`, TDD behind a feature flag, and the quote *"Code remains the source of truth"*
verbatim (`README.md:34`); SpecWeave's `task claim` (with exit 3 lost-race / exit 4 files-overlap),
`pickup`/`note`, `glossary check --strict`, and its secrets-scanning gap; OpenSpec's delta headings and
dated archive; reviewdog's `-diff="git diff FETCH_HEAD"`; trufflehog's `Verified` field, hidden
`--only-verified` flag and `--fail` = exit 183.

### Limits of this pass

- **HEAD moves.** Seven of the eleven repos were pushed on the day of reading. That is why each row records
  a commit: a claim verified now can be false next week, and "verified" without a SHA is an anecdote.
- **Stars are a snapshot** (2026-10-23) and three could not be re-read because the unauthenticated GitHub
  API rate-limited; those keep their original figure.
- **Reading code is not measuring adoption.** Nothing here shows that a peer's users *use* the mechanic, or
  that it improved their outcomes. The grades say the mechanism exists and behaves as described — no more.
- **One repo could not be cloned under its remembered name** (`juhasgit/diff_cover` no longer resolves);
  `Bachmann1234/diff_cover` is the live home and is what was read.

---

## Convergence after the amendment (2026-10-23)

Two questions were left open by the pass above. Both were researched to the point where a further source
stopped changing the answer, then implemented. "Convergence" here means the specific thing: a new source
either confirmed the mechanism or introduced a third option, and the last three sources did neither.

### 1. What is a coverage report's silence?

The earlier wording ("a line the report does not mention MUST be reported as unknown") was written from
diff_cover's flag alone. Reading the reporters themselves says the state space is larger, and the first
implementation was wrong in a way that mattered.

| Source | What it says about a line it does not list | Grade |
|---|---|---|
| `coverage.py` `coverage/jsonreport.py` | emits `executed_lines`, `missing_lines`, `excluded_lines` from `analysis.executed/missing/excluded`; these are **statements**, so comments, blanks and lines added after the run are in none of them | `[fetched]` |
| `coverage.py` `coverage/results.py` | `n_statements = len(statements)`, `n_executed = n_statements - n_missing`; `summary.num_statements` is the report's own completeness claim | `[fetched]` |
| lcov `geninfo(1)` | `LCOV_EXCL_LINE` / `LCOV_EXCL_START` remove lines from the tracefile; `DA:` records exist only for instrumented lines | `[fetched]` |
| diff_cover `violations_reporter.py:244-265` | fills each unreported line with **the previous line's hit count** — inference, not measurement | `[fetched]` |
| `watanabefam/citekit` (`46feeb2`) | an applied repo whose own rule is *"Never state a metric you have not run"*; its README labels an unmeasured latency as such rather than quoting a number | `[read]` |

Two independent report formats (Python's `coverage.py`, C's lcov) agree that a report names what it measured,
and the only tool found that closes the gap does so by guessing. Convergence: no third option appeared, so
the specification refuses the guess and names the states — `reached`, `unexercised`, `excluded`, `unmentioned`, `unprofiled`, plus `inconsistent`
when a report's summary contradicts its own lists (`decisions/0006`, 005 FR-043).

The implementation defect this exposed is worth recording because it was in shipped code: the first version
classified *anything not in `executed_lines`* as `unexercised`, which is a false claim about every changed
comment, every excluded line, and every line added after the coverage run. A file absent from the report was
handled; a line absent from it was not.

### 2. Does the delta invariant belong in 006?

OpenSpec's `openspec-archive-change` skill states that after syncing deltas, no delta-style heading may
remain in the main spec (read at `56ef0ac`). 006 records amendments (FR-023/FR-024) and archives them by date,
but says nothing about the *staging* form of an amendment, so a delta's proposal headings could be synced into
a settled spec and read as ordinary structure. That is a distinct mechanic, not a restatement: 006 says the
prior version must survive; it did not say the proposal scaffold must not. Adopted as **006 FR-041**,
acceptance scenario 5.7 and **SC-012**.

### 3. What an applied consumer measures

`watanabefam/citekit` is a real repository built with an older installed copy of this kit (preset `1.11.0`),
which makes it the first non-self-referential test of the conformance rule added in `decisions/0004`/`0005`:

```
$ ./scripts/check-section-integrity.sh . spec-template .../citekit/specs/001-web-search-source/spec.md
  MISSING  ### Which document wins
  MISSING  ### Parking lot vs Non-Goals
  FAIL     ... 2 missing, 0 out of order, 0 stubbed (of 27 required)
```

**25 of 27**, missing two subsections introduced after 1.11.0. This is measured, and it settles a question
the earlier pass could only speculate about: an adopter who upgrades the kit will fail the conformance rule on
specifications that were correct when they were written. The baseline mechanism from `0005` is therefore not
a self-excuse for this repository's history — it is the upgrade path every adopter needs. It also bounds the
claim the rule can make: presence of structure is checkable, and *when* the structure was required is not,
so the rule needs a recorded exemption rather than a status check.

### What this convergence did not settle

- citekit's own skill-validation protocol (trigger eval 30/30, metrics scored from `transcript.jsonl` by a
  different session) is a stronger claim-verification discipline than anything the kit ships for its own
  skill, whose 60% trigger rate is stated in `AGENTS.md` without a harness. That is a candidate feature, not
  an implemented one, and it needs its own specification rather than a paragraph here.
- Nothing in this section measures whether any adopter *acted* on a conformance failure. The citekit run
  proves the rule fires in a real repository; it does not prove the resulting message is useful.
