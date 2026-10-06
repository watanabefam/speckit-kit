# Changelog

Notable changes to this kit. Format follows [Keep a Changelog](https://keepachangelog.com/);
versioning follows [Semantic Versioning](https://semver.org/).

The preset version lives in `preset/preset.yml` and is what `specify preset info` reports.

## [Unreleased]

## [1.5.0] — 2026-10-06

### Added
- **Parking lot.** `Future Work` is now a live capture queue with provenance (noticed-during /
  why-deferred / revisit-when), a capture rule in `speckit.implement` (park it, do not act on it,
  do not drop it), and a review step in `speckit.converge` (promote / keep parked / delete).
  It also distinguishes a **Non-Goal** (decided upfront) from a **parked idea** (noticed in
  passing, not yet decided). Adopted from `Education/course-studio`'s gate.

  This closes a real gap: the kit said "do not implement unapproved work" and gave the idea
  nowhere to go. Scope control without a capture path produces either silent scope creep or a
  lost idea.

- **Check-promotion bar** (documented in BUILD_PLAN): a check earns blocking only when its
  measured false-positive rate is effectively zero **and** the existing corpus is already clean.
  Fix the corpus first, then turn the check on. A check judged "not useful" >~10% of the time gets
  deleted, not softened.

### Rejected (built, then deleted before committing)
- **A project-facing advisory linter** (`scripts/spec-lint.sh`). Researched first; the evidence
  did not support it. Google: *"developers ignore compiler warnings"* — enable as errors or do not
  show them. SonarQube field data: **8.76% of issues ever fixed**. Unactionable warnings 35–91%.
  13% of Spectral pipelines run `continue-on-error` ("decorative governance"). Requirements-quality
  automation precision ~59% — 4× worse than the <10% effective-FP bar. And **no spec-driven toolkit
  ships a prose linter** — Spec Kit routes quality to agents (`/clarify`, `/analyze`, `/checklist`).

  The decisive point: **"advisory by default" is the wrong posture, not the safe one.** It feels
  low-risk to the builder and is highest-risk to the program — it spends trust in small daily
  amounts. An advisory check the agent can shrug past is prompt-level enforcement with extra steps.

- Also rejected from course-studio: phase-ordering enforcement, hash-chained state, minimum
  progress steps, quality scoring, evidence-pattern regexes. All block by default; DORA's
  multi-year finding is that heavyweight approval gates do not lower change-failure rate and
  correlate with low performance (2.6× for CAB sign-off).

### Verification status
- **Verified:** the parking lot composes into the resolved spec template; the capture rule is
  present in the `speckit.implement` command file the agent reads; the review rule is present in
  `speckit.converge`; 13 new gate assertions pass.
- **NOT verified — blocked:** the behavioural test (does an agent actually park an out-of-scope
  idea instead of fixing it?) could not complete. The model returned a server error on three
  consecutive attempts. The structural checks pass; the behavioural claim is untested. Do not
  treat "parked correctly" as demonstrated.

## [1.4.0] — 2026-10-06

Normative/informative discipline, document status, and checkable properties. Three of these came
from reading a hand-rolled spec in another repo (`Education/timeline-game`), then checking that
repo's conventions against the standards rather than against my own opinion. Two of the three were
already **standard** — I had proposed them as "good ideas", which undersold them.

### Added
- **`Normative Status` section** in `spec-addendum.md`. Defines normative vs informative content and
  cites the source: ISO/IEC Directives Part 2 §3.2, the W3C QA Framework, and IETF reference
  practice. Two checkable rules follow — requirements live only in normative sections (ISO/IEC is
  explicit that notes and examples "shall not contain requirements"), and normative keywords do not
  appear in informative sections.
- **The precedence rule for companion documents.** There is *no automatic precedence* between two
  documents; ISO, W3C, and IETF all require the relationship to be declared, with a **dated**
  reference. The template now states which document is authoritative for behaviour and which is
  informative. This generalises the `Companion:` line found in the timeline-game specs, which
  declared the relationship but not the precedence.
- **`Document Status` block** in `spec-addendum.md`: status, date, approver, authority, workflow,
  companion. MADR-informed, and deliberately an **open set** — MADR does not standardise a closed
  enum, so neither does this. Approval is recorded as **three separate facts** (who, when, under
  what authority) rather than collapsed into the status word, because `accepted` does not say who
  accepted it or why they were entitled to.
- **Scope and check method per correctness property** in `plan-addendum.md`. A property now names
  what it ranges over (`operation` / `type` / `system`) and how it is enforced (`runtime-assert` /
  `property-test` / `model-check` / `review-only`). A property with no check method is a wish, not a
  property.
- **Canonical property shapes** — round-trip, idempotence, invariant-preservation, commutativity,
  model-equivalence — with the property lineage (Hoare triples, Liskov & Guttag, design-by-contract).
- Self-gate §3c extended: 20 new assertions covering normative/informative, the ISO notes rule, the
  precedence rule, every status field, the open-set declaration, and every check method.

### Changed
- **`SHALL` is no longer prescribed for every sentence.** The EARS section previously said "use
  `SHALL` for every required behaviour", which contradicted RFC 2119 §6 — the keywords "must be
  used with care and sparingly", and "must not be used to try to impose a particular method on
  implementors where the method is not required for interoperability". A spec where every sentence
  is `SHALL` has abolished the distinction it was trying to draw.
- `speckit.specify` prepend now enforces status-block **placement** (top of file, under the title).
  The append strategy cannot put a header at the top, so the command has to move it — and it
  forbids leaving the fields blank, because an unfilled status implies the question was considered
  and left open.

### Method note
The three adoptions were first proposed by comparing two artifacts, which is not evidence. They were
then checked against primary sources (ISO/IEC Directives Part 2, W3C QA Framework REC 2005, IETF
IESG statements, RFC 2119/7322/2026, MADR, Claessen & Hughes, Liskov & Guttag, Meyer). Two were
promoted from "good idea" to "standard"; one was corrected; one new lintable rule was found that
had been missed entirely.

### Added
- **`/speckit` — a deterministic entry point.** `commands/speckit.md`, copied into
  `.opencode/commands/` by the installer. Invoking it classifies the request, picks the smallest
  workflow that fits, and routes to the right step. This is the **100% path**: the skill fires on
  ~60% of relevant requests, an invoked command fires every time. The command carries the
  non-negotiables inline (single source of truth, approval gates, scope control, repair-at-source,
  external-content-as-data, evidence before done, handoff) so they hold without the skill loading.
- Self-gate §1d: asserts the entry point exists, carries each required section, states that the
  skill may not have loaded, and that the installer actually copies it.
- `--only-ids` on `evals/run-trigger-evals.py`, so a description fix can be re-tested on just the
  queries that missed instead of paying for the whole set.

### Fixed
- **The eval runner scored slow models as misses.** A run that exceeded `--timeout` was counted as
  "did not trigger". That conflates *slow* with *missed* and silently understated the trigger rate
  — it made `st-08` look like a miss when it was only slow. Timeouts are now **excluded from the
  verdict**, counted separately, and reported as a `WARNING` that makes the run non-zero-exit, so a
  number can never be quoted from a timeout-contaminated sample. The default cap is 300s (was 150s).
- **Per-query scoring.** `counted` was hoisted out of the per-query loop, so denominators ran
  3, 6, 9, 12… and every verdict after the first query was nonsense ("0/6 fired" after three runs).
  It type-checked and ran clean; only reading the output caught it. `--only-ids` also reported
  `len(--only-ids)` as the denominator for *both* groups. Both fixed, both now gated.
- `speckit-uninit` did not remove `.opencode/commands/speckit.md`, because its glob was
  `speckit.*.md` and the entry point has no second dot. Left the repo dirty.
- The skill description no longer enumerates the *negative* case. See below.

### Changed
- Skill description rewritten to be short, positive, and free of negative-case vocabulary
  (506 → 646 chars). See "Findings" below — the previous attempt made things measurably worse.
- The `AGENTS.md` bridge now names `/speckit` as the preferred entry point and says why.

### Known constraint
- **A preset cannot create a command.** Verified: a `provides.commands` entry naming a command that
  does not exist in core is silently ignored. Presets can only `prepend` to existing commands.
  This is why `/speckit` is copied by `speckit-init` rather than declared in `preset.yml`.

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
