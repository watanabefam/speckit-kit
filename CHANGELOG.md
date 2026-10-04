# Changelog

Notable changes to this kit. Format follows [Keep a Changelog](https://keepachangelog.com/);
versioning follows [Semantic Versioning](https://semver.org/).

The preset version lives in `preset/preset.yml` and is what `specify preset info` reports.

## [Unreleased]

### Added
- `--only-ids` on `evals/run-trigger-evals.py`, so a description fix can be re-tested on just the
  queries that missed instead of paying for the whole set.

### Fixed
- **The eval runner scored slow models as misses.** A run that exceeded `--timeout` was counted as
  "did not trigger". That conflates *slow* with *missed* and silently understated the trigger rate
  — it made `st-08` look like a miss when it was only slow. Timeouts are now **excluded from the
  verdict**, counted separately, and reported as a `WARNING` that makes the run non-zero-exit, so a
  number can never be quoted from a timeout-contaminated sample. The default cap is 300s (was 150s).
- The skill description no longer enumerates the *negative* case. See below.

### Changed
- Skill description rewritten to be short, positive, and free of negative-case vocabulary
  (506 → 646 chars). See "Findings" below — the previous attempt made things measurably worse.

## Findings: skill descriptions are positive-only, short, and probabilistic

Cross-model measurement on `opencode-go/space-bunny-free` (n=3/query, 300s cap, timed-out runs
excluded). Three description variants were measured:

| Variant | `st-06` multi-call-site refactor | `st-08` perf regression | `snt-01` false trigger |
| --- | --- | --- | --- |
| original (506 chars, 150s cap) | 2/3 ✅ | 1/3 ❌ | 2/3 ❌ |
| + explicit prohibition (860 chars) | 1/3 ❌ | 1/3 ❌ | **3/3 ❌ worse** |
| short + positive (646 chars, 300s cap) | 1/3 ❌ | 2/2 ✅ | 3/3 ❌ |

**1. Negative constraints in a skill description backfire.** To suppress a false trigger
(`write a spec for the login flow` firing in a repo with no `.specify/`), the description was
rewritten to lead with the precondition and an explicit prohibition — naming "write a spec", "spec
out" and "requirements". The false trigger got **worse**: 2/3 → 3/3. Naming the negative case put
those words into the description and raised its semantic similarity to the very query it was meant to
exclude. Skill matching is semantic; a prohibition is not a filter.

**2. The `.specify/` precondition cannot be enforced from the description at all.** `snt-01`
false-triggered in all three variants (2/3, 3/3, 3/3). The precondition is stated once, positively,
and the skill still fires on a repo that has no `.specify/`. Whatever the description says, the
*enforcement* has to live where it is read on invocation.

**3. No variant produced a reliable improvement.** Run-to-run variance is large — `st-01` scored
3/3 in one session and 1/3 in another with the same-ish setup. At n=3 these variants are **not
distinguishable**, and no honest claim of improvement can be made from them.

**4. The real headline.** Overall trigger rate on this model is ~60% (6/10 judged), the same ballpark
as the original 60% on `muse-spark-1.3`. The apparent "80%" seen mid-session was not a better
description — it was a small-sample artifact compounded by counting timeouts as misses. Two models,
two measurements, **the same ~60%.**

**Conclusion — this is the strongest argument yet for the P1 architecture.** Rules that must hold
every time belong in commands, which are read on every invocation. A skill description is a
probability surface: it can nudge the hit rate, but it cannot be relied on to enforce anything in
*either* direction. Both failure modes observed here are description-level — a miss it could not
prevent, and a false positive a prohibition could not suppress. The commands carry the rules; the
skill carries the reasoning. That split is doing exactly the job it was designed for.

## [1.3.0] — 2026-10-04

EARS requirements and correctness properties (feature 001).

### Added
- **EARS guidance** in `spec-addendum.md`: the five patterns (`THE <system> SHALL`, `WHEN`,
  `WHILE`, `WHERE`, `IF…THEN`), the `SHALL`-only / RFC 2119 rule, fixed clause order, common
  misuse, and a language-agnostic guard. Shapes verified against Mavin et al., RE'09.
- **Correctness Properties** section in `plan-addendum.md`: a `for any …` property table, the
  explicit opt-out rule, a framework-decision record, and a per-ecosystem *detection* table.
- **Property-test task rules** in `tasks-addendum.md`: one task per P-ID, both-ID tracing,
  co-location, fallback-following, a worked example, and a Property column in Requirement
  Coverage.
- Self-gate §3c: asserts the EARS shapes, the RFC 2119 and clause-order rules, the properties
  section, the task rules, and a **no-hardcode guard** for PBT framework names.

## [1.2.0] — 2026-10-04

Step rules moved into the commands.

### Added
- Command contributions (`strategy: "prepend"`) on `speckit.specify`, `speckit.plan`,
  `speckit.tasks`, `speckit.implement` and `speckit.converge`, carrying each step's enforceable
  rules. The skill fires on ~60% of relevant requests, so rules that must always apply cannot
  live behind a probabilistic trigger.
- Self-gate §3b: every command entry is a prepend, each contribution carries its rules, and none
  ships its own frontmatter.

### Changed
- The skill is now the *reasoning* layer and points at the commands as authoritative
  ("if the skill and a command disagree, the command wins") instead of restating the rules.

## [1.1.0] — 2026-10-04

Addendum reliability.

### Added
- Section-integrity prepends on `speckit.specify`, `speckit.plan` and `speckit.tasks`, so the
  appended template sections are not silently dropped. Before this, a generated `spec.md` had
  **0** appended sections; after, three consecutive artifacts carried all of theirs.

### Fixed
- `append` alone did not guarantee delivery: it depended on the agent resolving the composed
  template, which agents do inconsistently.

## [1.0.0] — 2026-09-30

First working version.

### Added
- Preset with `strategy: "append"` on the constitution, spec, plan and tasks templates.
- `spec-driven-development` skill (agentskills.io), discovered by both opencode and Freebuff
  from `~/.agents/skills/`.
- `global/working-agreements.md` routing file.
- `bin/speckit-init` installer.
- `scripts/self-gate.sh` + CI on Linux bash 5 and macOS system bash 3.2.
- Behaviour and trigger-accuracy evals.
