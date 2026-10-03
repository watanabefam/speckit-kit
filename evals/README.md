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

- **should-trigger ≥ 90%** (Anthropic's target, over 10–20 queries)
- **should-not-trigger = 0 false triggers**

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

Exits non-zero if the should-trigger rate is below 90% or any false trigger occurs.

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

Recorded so a regression is visible rather than assumed.

| Date | Set | should-trigger | false triggers | Notes |
| --- | --- | --- | --- | --- |
| 2026-10-03 | should_trigger (10) | **6/10 = 60%** | — | BELOW target. Missed: bug fix, small feature, idea assessment, refactor |
| 2026-10-03 | should_not_trigger (10) | — | **0/10 = 0%** | No over-triggering; the description is not too broad |
| 2026-10-03 | re-run of the 4 misses | 4/4 fired | — | Misses were **non-deterministic**, not category exclusions |

### What that run taught us

1. **The skill under-triggers (~60%) and it is non-deterministic.** Every query fires
   *sometimes*. A retry therefore masks the defect — which is exactly why a single-shot test
   (the original G5 "pass") could not see it, and why the rate must be measured over repeated
   runs rather than asserted once.

2. **The eval set itself had a wrong case.** `snt-07` originally asserted that a mechanical
   rename in a spec-kit repo should *not* trigger. But `SKILL.md` §1 exists to **classify**
   the request — the skill should load on trivial work, recognise it as trivial, and say so.
   The negative case contradicted the skill's own design. Reclassified to `st-11`, with a
   read-and-summarise request replacing it as the near-miss.

3. **Description broadened in response.** The old wording enumerated artifact activities
   ("writing or revising a specification, planning a feature…"), which reads as a checklist
   the query must match. The new wording leads with the precondition and the general intent —
   *"any software change in such a repository"* — so ordinary dev requests match strongly.

### Measurement caveat

A full run is 20+ real agent calls (~15 min). `--runs 3` — the method Anthropic actually
specifies for a reliable rate — is ~45 min. **Single-run results are not conclusions.**
The second run below demonstrates exactly why.

| Date | Set | Rate | Notes |
| --- | --- | --- | --- |
| 2026-10-03 | should_trigger (10), run 1 | 6/10 = 60% | old description |
| 2026-10-03 | should_trigger (11), run 2 | **5/11 = 45%** | broadened description; st-08 hit the 300s timeout and counted as a miss |

### What the second run overturned

The first run suggested the description was too narrow — it enumerated artifact activities
("writing or revising a specification, planning a feature…") rather than stating the general
intent. The description was broadened in response. **The re-measure did not improve, and was
numerically worse.**

But the more important observation is the **variance**. Between the two runs:

- `st-02` missed, then fired.
- `st-09` fired, then missed.
- `st-04`, `st-05`, `st-06` missed both times.
- `st-08` timed out at 300s in run 2 and was scored as a miss.

With n=1 per query, a rate that swings 60% → 45% across runs, and individual queries flipping
in both directions, **neither number is trustworthy** — including the first one I reported.
This is why Anthropic specifies 3 runs per query for a reliable trigger rate.

### The likely real cause (and a flaw in this eval set)

Anthropic documents the mechanism directly:

> *"Claude only consults skills for tasks it can't easily handle on its own — simple, one-step
> queries like 'read this PDF' may not trigger a skill even if the description matches
> perfectly… **Complex, multi-step, or specialized queries reliably trigger skills.**"*

The three queries that missed **both** runs are all short and simple-sounding:

- `st-04` "can u add dark mode to the settings page"
- `st-06` "Refactor the payment module onto the new provider API."
- `st-11` "Rename the `spec` variable to `specification`"

Per that guidance, these are **poor test cases** — not because the skill shouldn't handle
them, but because the platform won't route a simple-looking request to a skill regardless of
how the description is written. *"Simple queries like 'read file X' are poor test cases — they
won't trigger skills regardless of description quality."*

So the should-trigger set needs **substantive** queries — ones where consulting a skill would
plausibly change the outcome — and the trivial ones (`st-04`, `st-11`, arguably `st-06`) belong
on neither side. That is a fix to the eval set, not to the skill.

### Status

**Inconclusive, and deliberately recorded as such.** The description change is kept (it is
more accurate to the skill's intent and measured no worse), but it must **not** be claimed as
a fix. The next step is a `--runs 3` measurement on a revised, substantive should-trigger set —
which will also surface whether the underlying rate is genuinely below 90% or whether the
earlier numbers were sampling noise.



## Known gaps

- **No cross-model coverage.** Anthropic's checklist asks for testing across model tiers. Everything so far has run on one model.
- **`skill-evals.json` has 3 behavioural evals; one is unrun.** Eval 3 (`no-code-before-approved-artifacts`) is written but hasn't been executed.
