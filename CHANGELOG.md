# Changelog

Notable changes to this kit. Format follows [Keep a Changelog](https://keepachangelog.com/);
versioning follows [Semantic Versioning](https://semver.org/).

The preset version lives in `preset/preset.yml` and is what `specify preset info` reports.

## [Unreleased]

## [1.7.0] — 2026-10-08

Instrument bug in both eval runners, an outcome-eval runner that finally runs the rubrics, and a
**retraction** of two published findings.

### Fixed — the runners evaluated the wrong directory (major)
Both runners passed `cwd=` to `subprocess.Popen` but did **not** set `PWD`. opencode resolves the
project from `$PWD`, not from the process working directory, so **every eval run executed in the
directory the runner was launched from** — not the intended context repo. The launcher was a Spec
Kit repo, so the "plain" (no `.specify/`) context was never plain.

Found by investigating an outcome-eval failure instead of guessing: the agent reported *"README.md
here is 298 lines about speckit-kit itself"* and cited this repo's own eval fixtures. Verified with a
direct probe — `Popen(cwd=scratch)` launched from the kit dir ran in the kit dir; adding
`env={PWD: scratch}` fixed it.

**Consequence — a retraction.** The `snt-01` "false trigger" (`write a spec for the login flow`
firing in a repo with no `.specify/`) was an **artifact**. Re-measured with the fix:

| | before (buggy) | after (fixed) |
| --- | --- | --- |
| `snt-01` | 3/3 fired | **0/3** |
| should-NOT-trigger | 9/10 | **10/10** |

This retracts two findings from v1.4.0, both measured on contaminated runs:
- ~~"Negative constraints in a skill description backfire"~~ — no evidence that negative vocabulary
  affects triggering. The apparent 2/3 → 3/3 worsening was the bug.
- ~~"The `.specify/` precondition cannot be enforced from the description"~~ — the precondition
  **is** respected; a repo with no `.specify/` does not fire the skill.

The v1.4.0 "Findings" section is kept with a RETRACTED banner rather than deleted, because how it
went wrong is the instructive part: a confident mechanism ("naming the negative case raises semantic
similarity") was built on a broken measurement, and it was more convincing than the boring
explanation (the test ran in the wrong directory).

**Unaffected:** the should-trigger results (that set is 100% spec-kit context, and the launcher was a
Spec Kit repo, so it was accidentally correct). Re-measured anyway: **7/10 (70%)**.

### Added — `evals/run-outcome-evals.py`
The outcome rubrics in `skill-evals.json` existed but **nothing ran them** — only the gate checked
their structure. There is now a runner that builds each fixture, runs the scenario, judges the
transcript against `expected_behavior` / `failure_signals`, and reports.

Three design points, each from the research:
- **It runs the query through `/speckit`, not bare.** A bare query re-measures *triggering*: on a
  small fix the skill often does not load (by design — trivial queries are not valid should-trigger
  cases), so a rubric asking for skill-dependent behaviour like "states the chosen workflow" is
  unanswerable. Forcing the workflow in makes this eval measure *guidance*. `--bare` reproduces the
  trigger view.
- **It reports whether the skill loaded**, so a failure says which layer to look at: "did not load"
  points at the description, "loaded" at the skill text.
- **Deterministic guards** for the unambiguous signals (`must_survive` / `must_not_exist`), so the
  highest-value checks do not depend on a judge.

Fixture setups were made mechanical (`fixture` field) rather than prose, so they are reproducible.

### Changed — eval exit semantics
The runner no longer hard-fails below 90%. The two sets are not the same kind of thing:

- **should-NOT-trigger firing → FAIL.** The skill loaded where its precondition forbids. A defect.
- **should-trigger missing → reported, not failed.** A probability, not a defect; hard-gating a
  probabilistic number invites teaching the description to the test set. `--gate <rate>` opts in.
- **Timeouts → FAIL.** A contaminated sample cannot produce a number.

### Corrected — the 90% benchmark was misattributed
The README called 90% *"Anthropic's target"* and *"stated for general skill corpora"*. The number is
real but is an **aspirational example** from *The Complete Guide to Building Skills for Claude* (p.9),
which says so itself: *"aspirational targets — rough benchmarks rather than precise thresholds."*
No normative source (spec, platform docs, engineering post, `skill-creator`) states a 90%
requirement. "General skill corpora" was invented; removed.

Also corrected: an earlier changelog claimed the **0.5 threshold was "this kit's own invention"**.
It is the documented upstream default (agentskills.io → optimizing descriptions, and
`skill-creator`'s `run_eval(runs_per_query=3, trigger_threshold=0.5)`). Under-credited, now fixed.

### Current state (valid instrumentation, `opencode/space-bunny-free`)
- should-trigger **7/10 (70%)** · should-NOT-trigger **10/10 (100%)** · runner exits **PASS**
- The skill respects its precondition. The remaining gap is the miss rate.

## [1.6.0] — 2026-10-08

Agent-skills conformance pass. Researched official guidance (agentskills.io spec; Anthropic skill
authoring docs; opencode skills/commands/rules docs) and corrected a claim the kit was getting
**wrong**.

### Corrected — the kit claimed it could enforce things. It cannot.
The kit said each step's **"enforceable rules"** are prepended to the commands. Official guidance
contradicts this: *"Claude treats [memory/skills] as **context, not enforced configuration**. To
block an action regardless of what Claude decides, use a PreToolUse hook."* Commands are prompt
text; they buy **deterministic invocation, not deterministic compliance**. Reworded everywhere
(skill, README, `/speckit`, installer comments) and the skill now carries an explicit table:

| You want | Use |
| --- | --- |
| a rule to be *present* whenever a step runs | a command (this kit) |
| a rule to be *followed* reliably | a command, and check the artifact afterwards |
| a rule that *cannot* be violated | a hook or a permission — not a command, and not the skill |

This matters beyond wording: it decides where a genuinely must-not-fail rule belongs, and the honest
answer is *not here*. The kit's real offer is narrower and true — the rule is in front of the model
at the moment it acts, instead of behind a ~60% trigger.

### Changed
- **Skill description rewritten in the third person.** Official guidance: *"Always write in third
  person. The description is injected into the system prompt."* It opened with "Use this skill for…"
  (second-person imperative) and now opens with the what — "Spec-driven development for software
  work in a repository containing a `.specify/` directory…". 506 → 632 chars, still well inside the
  1024 limit.

  **Measured after the change: 7/10 should-trigger (70%)**, against 6/10 (60%) for the previous
  description on the same model family. **Do not read that as a 10-point win.** The two runs used
  different model slugs (the old one, `opencode-go/space-bunny-free`, has since been retired), and
  per-query variance swamps the delta — `st-06` swung from 1/3 to 3/3 on a wording change that was
  made for *style conformance*, not for triggering. At n=3 these are not distinguishable. What the
  run does support is that the change **did not regress** triggering, which was the real risk of
  touching the trigger surface for a style reason.
- **References now carry an explicit read trigger** — a `Read this / When` table, per the authoring
  checklist ("make the read trigger explicit; refs one level deep").

### Verified
- **Frontmatter is spec-portable.** Only spec fields are used (`name`, `description`, `license`,
  `metadata`); `version` stays nested under `metadata` as a quoted string. This is load-bearing:
  opencode **silently ignores** non-spec fields (so a stray top-level field looks like it works and
  does nothing), and Claude Code packaging hard-errors on them. Now gated.

### Added — gate assertions (6 new)
- frontmatter uses only spec fields; `metadata` values are strings
- description is third person (fails on `Use this` / `You ` / `I ` openings)
- **no "enforceable rules" claim** anywhere in skill / README / `/speckit`
- every reference file is linked *and* the `Read this / When` table is present

### Sources
agentskills.io/specification · platform.claude.com skill authoring best-practices · Claude Code
skills + memory docs · opencode skills/commands/rules docs.

### Open (not done — P2, from the same research)
- The trigger eval measures **trigger accuracy only**, with **no no-skill baseline** and **no
  outcome rubric**. Official methodology wants ≥3 end-to-end scenarios with `expected_behavior`
  rubrics, run against a baseline, across ≥2 models. Trigger rate ≠ skill value; a skill can fire
  100% and change nothing.
- The **0.5 threshold is this kit's own** invention, not standard. Recorded as an internal tripwire.
- The measured ~60% may be measuring the **harness** (in opencode the agent must *choose* to call
  the skill tool from a listing), not the description. Do not attribute all of it to wording.

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
- **Verified — behavioural test now PASSES.** A spec with one task (`add greet`) sat beside an
  unrelated, obvious bug (`formatDate` off-by-one month, `getMonth` is 0-indexed). Result:
  the approved task was implemented; the unrelated bug was **left untouched**; and the idea was
  **parked with full provenance** — *"Noticed during: implement (T001 file read) · Why deferred:
  Out of scope, not in approved tasks · Revisit when: next bugfix/spec touching date formatting"*.
  Scope control held, and the idea was not lost.

**Re-confirmed on `opencode/space-bunny-free`.** The earlier failures were *my* bad parameter, not
a provider outage: `opencode-go/space-bunny-free` has been retired from that provider, so every run
against it returned `Unexpected server error`. The live slug is `opencode/space-bunny-free`
(`opencode-go/space-bunny` and `nous/stealth/space-bunny-alpha` also exist). Lesson worth keeping:
a provider error on a model you believe is live is a reason to re-check the model list, not to
assume the provider is down.

Result on space-bunny-free — PASS, and stronger than the muse-spark run:

- approved task implemented; `formatDate` left untouched
- the parked row **cites `plan.md`'s "Must Not Change" boundary** as its reason, rather than
  asserting out-of-scope-ness
- it **verified the parked claim before parking it** — ran
  `formatDate(new Date(2026,9,8))` → `2026-9-8` to confirm the bug was still present
- it parked a second item unprompted: a stray scratch file at the repo root, explicitly noting
  *"deleting a tracked file was not authorised"*
- T001 was ticked only because the task carried a `Verification:` line it could actually execute

Two intermediate findings from getting there:

- A **malformed fixture** (spec + tasks, no `plan.md`) did not produce a parking-lot failure. The
  model refused to implement, spotted the missing artifact, applied repair-at-the-source, and
  declined to tick T001 with no `Verification` line and no test framework — *"which the
  `Evidence before done` rule forbids"*. Doctrine firing correctly on a broken input is a good sign,
  but it made the parking-lot question unanswerable, so the fixture was corrected and re-run.

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
- Skill description rewritten to be short and positive (506 → 646 chars). The original reason given
  here — that negative-case vocabulary made a false trigger worse — has since been **retracted**:
  that measurement was corrupted by a runner bug (`$PWD`). The shorter description was kept because
  it is shorter, not because the longer one was proven harmful. See v1.7.0.
- The `AGENTS.md` bridge now names `/speckit` as the preferred entry point and says why.

### Known constraint
- **A preset cannot create a command.** Verified: a `provides.commands` entry naming a command that
  does not exist in core is silently ignored. Presets can only `prepend` to existing commands.
  This is why `/speckit` is copied by `speckit-init` rather than declared in `preset.yml`.

## Findings: skill descriptions are probabilistic — and a retraction

> **RETRACTED 2026-10-08 (v1.7.0).** The false-trigger result in this section was an
> **instrument artifact**, not a finding. The eval runner passed `cwd=` to the subprocess but did
> not set `PWD`, and opencode resolves the project from `$PWD` — so every run executed in the
> *launching* directory, which was a Spec Kit repo. The "plain" context (no `.specify/`) was never
> plain. With the fix, `snt-01` scores **0/3** and should-not-trigger is **10/10**. See v1.7.0.
>
> This invalidates findings 1 and 2 below (the "negative vocabulary backfires" result and the
> "precondition cannot be enforced" claim). Both were measured on contaminated runs. Findings 3
> and 4 — variance, and the ~60% rate — concern the should-trigger set, which ran in a
> `.specify/` repo either way, so they are probably unaffected; they were re-measured in v1.7.0.
>
> Kept rather than deleted, because the way this went wrong is the most instructive thing here:
> a confident mechanism ("naming the negative case raises semantic similarity") was built on a
> broken measurement, and it sounded more convincing than the boring explanation (the test ran in
> the wrong directory).

Cross-model measurement on `opencode-go/space-bunny-free` (n=3/query, 300s cap, timed-out runs
excluded). Three description variants were measured:

| Variant | `st-06` multi-call-site refactor | `st-08` perf regression | `snt-01` false trigger |
| --- | --- | --- | --- |
| original (506 chars, 150s cap) | 2/3 ✅ | 1/3 ❌ | 2/3 ❌ *(invalid)* |
| + explicit prohibition (860 chars) | 1/3 ❌ | 1/3 ❌ | **3/3 ❌ worse** *(invalid)* |
| short + positive (646 chars, 300s cap) | 1/3 ❌ | 2/2 ✅ | 3/3 ❌ *(invalid)* |

**1. ~~Negative constraints in a skill description backfire.~~ RETRACTED.** The apparent worsening
(2/3 → 3/3) was the `$PWD` bug: `snt-01` ran in a `.specify/` repo in every variant, so it fired
regardless of wording. There is **no evidence** that negative vocabulary affects triggering. The
mechanism was plausible and wrong.

**2. ~~The `.specify/` precondition cannot be enforced from the description.~~ RETRACTED.** With the
runner fixed, the precondition **is** respected: a query with no `.specify/` present does not fire
the skill (10/10 on the should-not-trigger set). The description's precondition works.

**3. No variant produced a reliable improvement.** Run-to-run variance is large — `st-01` scored
3/3 in one session and 1/3 in another with the same-ish setup. At n=3 these variants are **not
distinguishable**, and no honest claim of improvement can be made from them.

**4. The headline.** Trigger rate on the should-trigger set is ~60–70%. The apparent "80%" seen
mid-session was not a better description — it was a small-sample artifact compounded by counting
timeouts as misses.

**Conclusion — the architecture argument survives, on weaker evidence.** Rules that must hold every
time belong in commands, which are read on every invocation. A skill description is a probability
surface: it can nudge the hit rate, but it cannot be relied on to *guarantee* anything. Note that
the false-positive half of the original argument is now gone — the skill does respect its stated
precondition. What remains is the miss rate: ~60–70% is the honest case for putting rules in
commands, and it is a weaker case than the version this section originally made.

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
