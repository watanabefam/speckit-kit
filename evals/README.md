# Skill evaluations

Two kinds of test, because a skill fails in two different ways.

| File | Tests | Why it matters |
| --- | --- | --- |
| `skill-evals.json` | **Behaviour** — what the skill does once loaded | A skill that loads but gives bad guidance is worse than none |
| `trigger-evals.json` | **Triggering** — whether the skill loads at all | A skill that doesn't load fails *silently* — no error, the agent just handles the task itself |

## Triggering is the one that bites

Per Anthropic and independent write-ups, silent misfire is the most common way a skill
fails: *"a skill that misfires just doesn't run… there's no error or warning to indicate the
problem, and the trigger description is usually the cause."*

So trigger rate is the primary metric:

- **should-trigger ≥ 90%** — an **aspirational benchmark**, not a conformance target (see below)
- **should-not-trigger = 0 false triggers**

#### What the 90% actually is

It is real, but it is not a spec requirement, and this README previously overstated it. The number
comes from Anthropic's *The Complete Guide to Building Skills for Claude* (p.9), which introduces it
as one example among several and says so explicitly:

> *"These are aspirational targets — rough benchmarks rather than precise thresholds. Aim for rigor
> but accept that there will be an element of vibes-based assessment."*
> — [The Complete Guide to Building Skills for Claude](https://resources.anthropic.com/hubfs/The-Complete-Guide-to-Building-Skill-for-Claude.pdf), p.9

The same page gives the method: *"Run 10-20 test queries that should trigger your skill."*

**No normative source states a ≥90% requirement.** The [agentskills.io
specification](https://agentskills.io/specification), the [skill authoring best
practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices), the
[engineering post](https://www.anthropic.com/engineering/equipping-agents-for-the-real-world-with-agent-skills)
and `anthropics/skills`' own `skill-creator` contain no aggregate trigger target (`skill-creator`
mentions `90%` zero times). An earlier version of this README called it "Anthropic's target… for
general skill corpora" — that phrasing was invented and has been removed.

Treat 90% as a direction of travel, and judge a change by whether it regresses, not by whether it
crosses an arbitrary line.

### The method (a single run is not a measurement)

This mirrors the standard method in
[agentskills.io → optimizing descriptions](https://agentskills.io/skill-creation/optimizing-descriptions)
and skill-creator's `run_loop.py`, which calls `run_eval(runs_per_query=3, trigger_threshold=0.5)`:

- Each query runs **3 times**.
- A query "triggers" when it fires in **≥ 50%** (i.e. 2 of 3) of its runs.
- A query **passes** when that verdict matches its label.

**Both defaults are the documented standard, not local choices.** `runs_per_query=3` and
`trigger_threshold=0.5` are the values named in the optimizing-descriptions guide ("Run each query
multiple times (3 is a reasonable starting point)… 0.5 is a reasonable default"). An earlier
changelog entry in this repo claimed the 0.5 threshold was "this kit's own invention" — that was
wrong; it is the upstream default.

**`--runs 3` is not optional.** With one run per query, the rate swings between runs and individual
queries flip in both directions — which is exactly what happened on the first two measurements of
this skill (60%, then 45%). Neither number was valid. Do not draw conclusions from `--runs 1`; the
runner warns if you try.

### Split the set before tuning (train / validation)

The standard method splits the eval set — roughly **60% train, 40% held-out validation** — and
iterates on the train split only, up to about five times, picking the best by **validation** pass
rate. This exists to stop you tuning the description against the very queries you then score it on.

This kit's set is small (10 + 10), so a formal split is coarse, but the rule still applies: **if you
change the description to fix a specific query, re-measure on queries you did not tune against.** A
description tuned until the whole set passes has been taught to the test, and the score is fiction.
That is the main reason the trigger eval is a *measurement*, not a build gate.

### should-trigger queries must be substantive

Anthropic is explicit: *"simple, one-step queries… may not trigger a skill even if the
description matches perfectly"* and *"simple queries are poor test cases — they will not
trigger skills regardless of description quality."*

So a one-line rename or a trivial edit is **not a valid should-trigger case**, however
willing the skill would be to handle it. A query belongs in the set only if consulting a
skill would plausibly change the outcome.


### The negative cases are near-misses on purpose

An obviously irrelevant query ("what's the weather") proves nothing. The valuable negatives
share keywords and intent with the skill but need something else:

- `write a spec for the login flow` — in a repo with **no** `.specify/`. Every keyword matches; the precondition doesn't.
- `Spec out the API response shape` — "spec out" collides with "specify" directly, but it's a quick design question.
- `Write a blog post about spec-driven development` — contains the skill's exact name, but it's content writing, not the workflow.
- `Explain what Spec Kit is` — same topic, but there's no work to do.

Each query declares a `context`: run inside a **spec-kit repo** (has `.specify/`) or a
**plain repo** (doesn't). Triggering depends on it, so the same words appear on both sides.

## Runners

### Primary — `run-trigger-evals.py`

Drives the `opencode` CLI directly and detects the skill load from the transcript. Its
detection signal — the `-> Skill "spec-driven-development"` line — was **verified by
execution** during the build, which is why it's the primary runner.

```bash
./evals/run-trigger-evals.py --dry-run        # list queries, run nothing
./evals/run-trigger-evals.py                  # full run, creates scratch repos
./evals/run-trigger-evals.py --runs 3         # 3 runs/query for a reliable rate
./evals/run-trigger-evals.py --only snt       # only the should-not-trigger set
./evals/run-trigger-evals.py --spec-kit-repo ~/Documents/GitHub/speckit-sandbox
```

**Exit semantics — the two sets are not the same kind of thing:**

- **should-NOT-trigger firing → FAIL.** The skill loaded where its precondition says it must not.
  That is a defect, and it fails the run.
- **should-trigger missing → reported, not failed.** The model decided it could handle the task
  without the skill. That is a probability, not a defect — and for a skill about "how much process
  this needs", misses are partly by design. Hard-gating a probabilistic number invites tuning the
  description to the test set.
- **Timeouts → FAIL.** A contaminated sample cannot produce a number.
- **`--gate <rate>`** enforces a should-trigger threshold if you want one. Off by default.

### Secondary — `promptfooconfig.yaml`

promptfoo's OpenCode SDK provider plus the `skill-used` assertion, which normalizes native
`skill` tool parts — a cleaner signal, with CI-ready reporting. **Two things are unverified
in this environment** and are documented at the top of the config:

1. `working_dir` may restrict the SDK to read-only tools (read/grep/glob/list), possibly excluding `skill`.
2. Whether the SDK provider discovers a **global** skill from `~/.agents/skills/`.

Treat this as the upgrade path, not the source of truth, until both are confirmed.

```bash
npm install -g promptfoo && npm install @opencode-ai/sdk
promptfoo eval -c evals/promptfooconfig.yaml
```

## Automated by the self-gate

`scripts/self-gate.sh` validates both eval files parse and that each set has ≥8 queries. It
runs in CI on **both Linux bash 5 and macOS system bash 3.2**.

It does **not** run the queries — they cost real agent calls. Run them deliberately, after
editing the skill or its description.

## Results

### Valid baseline (3 runs/query, threshold 0.5)

| Query | Fired | Verdict |
| --- | --- | --- |
| st-02 bug fix | 2/3 | pass |
| st-03 SSO, "start from the beginning" | 2/3 | pass |
| st-04 multi-part settings page | 2/3 | pass |
| st-07 "write a spec for team invitations" | 3/3 | pass |
| st-09 notifications, "the works" | 2/3 | pass |
| st-10 "Plan out a migration" | 2/3 | pass |
| st-01 "Add CSV export to the reports page…" | 1/3 | **miss** |
| st-05 "Is a mobile app worth building?" | 1/3 | **miss** |
| st-06 "Refactor the payment module…" | 0/3 | **miss** |
| st-08 "The build got a lot slower…" | 1/3 | **miss** |

**should-trigger: 6/10 = 60%** — below the aspirational ~90% benchmark. (An earlier note here said
"0 false triggers at n=1"; that was superseded and the should-not-trigger set is now re-measured
properly — see the `$PWD` note below.)

> **Instrument bug, found and fixed 2026-10-08.** The runner passed `cwd=` to the subprocess but did
> not set `PWD`. opencode resolves the project from `$PWD`, so **every run executed in the launching
> directory**, not the intended context repo. Because the launcher was a Spec Kit repo, the "plain"
> (no `.specify/`) context was never plain. Consequence: the `snt-01` "false trigger" reported in
> earlier versions of this file was an **artifact**. With `PWD` set, `snt-01` scores **0/3** and
> should-not-trigger is **10/10**. Any number in this file dated before 2026-10-08 that involves the
> `plain` context should be treated as invalid.

**This is a real, measured under-trigger, not sampling noise.** It matters that the earlier
invalid single-run measurements also landed on 60% — two independent methods converging on
the same number is what makes it credible.

### The pattern in the failures

The passes cluster around **explicit process language** the user typed:

| Phrasing | Result |
| --- | --- |
| "write a spec for…" | 3/3 |
| "Plan out a migration" | 2/3 |
| "Start from the beginning" | 2/3 |
| "…the works" (obviously multi-part) | 2/3 |
| "Add CSV export…" / "Refactor…" / "Fix it" / "Is this worth building?" | 1/3, 0/3, 1/3, 1/3 |

Task-shaped requests ("just do this thing") route unreliably; requests that sound like
*process* route reliably. That matches the documented mechanic — the model consults a skill
when it perceives the task needs help deciding, not when it thinks it can just do it.

### Earlier measurements (invalid — recorded so the mistake isn't repeated)

| Date | Method | Result | Problem |
| --- | --- | --- | --- |
| 2026-10-03 | 1 run/query, old description | 6/10 = 60% | n=1 is not a measurement |
| 2026-10-03 | 1 run/query, broadened description | 5/11 = 45% | same; individual queries flipped between runs |

Those two runs disagreed and I nearly reported the second as a regression. Both were noise.
The runner now defaults to `--runs 3` and warns if you pass `--runs 1`.

### Description optimization attempt — the description is not the lever

A second description was written from the failure pattern, reframing the skill as
**"Required process for any code change… Load this before writing code"** rather than optional
capability. Hypothesis: the misses are all *"just do this"* shapes, so signalling that the
skill is mandatory before coding would catch them.

Measured with the same method (3 runs/query, threshold 0.5):

| Query | Description A | Description B |
| --- | --- | --- |
| st-01 | 1/3 | 1/3 |
| st-02 | **2/3 pass** | 0/3 |
| st-03 | 2/3 pass | 3/3 pass |
| st-04 | **2/3 pass** | 1/3 |
| st-05 | 1/3 | **2/3 pass** |
| st-06 | 0/3 | 0/3 |
| st-07 | 3/3 pass | 2/3 pass |
| st-08 | 1/3 | **2/3 pass** |
| st-09 | 2/3 pass | 3/3 pass |
| st-10 | 2/3 pass | 3/3 pass |
| **total** | **6/10 = 60%** | **6/10 = 60%** |

**The aggregate is identical while four queries swap sides.** Four of ten moving in opposite
directions is what noise looks like; a real description effect would move the total.

Two conclusions, both earned:

1. **The description is near its ceiling for this skill.** Two structurally different
   wordings produce the same rate. Rewriting it again is unlikely to help.
2. **The residual ~40% is platform routing behaviour, not a defect to fix.** `st-01`
   ("Add CSV export…") and `st-06` ("Refactor the payment module…") never trigger under
   *either* description — they are pure task-shaped requests with no process signal, exactly
   the category Anthropic documents as not routing to skills.

Description B was therefore reverted: it measured no better, and A is the plainer wording.
The experiment is recorded rather than deleted, because "we tried this and it didn't move"
is the finding.

### What this means for the 90% benchmark

The 90% is an aspirational example benchmark, not a requirement (see "What the 90% actually is"
above — no normative source states it). For a skill whose whole job is *deciding how much process
work warrants*, a meaningful share of relevant requests will be ones the model believes it can just
do — those will not route, by design. The honest position is that this skill's realistic ceiling on
task-shaped requests is **~60–70%**, and the routing is reliable (**2–3 of 3**) on requests carrying
process language.

If a higher rate matters more than precision, the lever is **not** the description — it is
scoping the skill's stated trigger to process-shaped requests only (narrow, honest, and
measures high), or pushing the workflow into the commands so it doesn't depend on a skill
loading at all. That second option is what `/speckit` does.



## Runner bug found by this work

The first `--runs 3` attempt **hung for over three hours** on a single query.

`subprocess.run(timeout=…)` did not help: opencode spawns children that inherit the stdout
pipe, so the parent blocks reading a pipe a grandchild still holds, long after the timeout
fired. The fix is threefold, and all three are load-bearing:

1. `start_new_session=True` + `os.killpg` — kill the whole process **group**, not just the parent.
2. **Raw `os.read` on the fd, never `readline()`** — the agent streams output that is not
   newline-delimited, and `readline()` blocks forever on a partial line even after `select`
   says the pipe is ready.
3. **Return as soon as the skill is detected** — the decision is early, so there's no reason
   to wait for the agent to finish the whole task. Fired runs now return in ~15s.

This would have hung CI indefinitely had the gate run the evals. It doesn't — the gate only
validates the eval data, deliberately, because the queries cost real agent calls.




## Known gaps

- **No cross-model coverage.** Anthropic's checklist asks for testing across model tiers. Everything so far has run on one model.
- **`skill-evals.json` has 3 behavioural evals; one is unrun.** Eval 3 (`no-code-before-approved-artifacts`) is written but hasn't been executed.
