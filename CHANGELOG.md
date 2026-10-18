# Changelog

Notable changes to this kit. Format follows [Keep a Changelog](https://keepachangelog.com/);
versioning follows [Semantic Versioning](https://semver.org/).

The preset version lives in `preset/preset.yml` and is what `specify preset info` reports.

## [Unreleased]

## [1.12.0] — 2026-10-17

### Added — a mechanical autonomy boundary, one-command verification, continuous execution, and a fast lane

The kit's approval boundary lived in prompt text, which the kit itself says cannot enforce anything.
The research for this feature (`specs/003-autonomous-throughput/research.md`, 31 sources) is
consistent that the dominant cost of AI-assisted development is human round-trips and rework rather
than generation, that the boundary belongs in tool permissions, and that adding more rules to a
prompt spends a finite instruction budget. This release acts on that.

- **A permission boundary, installed by `bin/speckit-init` (§2d).** A `permission` block is written
  to the project `opencode.json` — created if absent, **printed and never written** if the project
  already has one. It denies `--force` force-push, `--no-verify` and `core.hooksPath` overrides,
  package publish, and destructive database commands; it gates push/reset/clean with `ask`. Order is
  load-bearing: opencode's documented behaviour is to evaluate rules in order and take the **last**
  match, so the catch-all is first and the specific denies are last. **The boundary depends on that
  documented behaviour** — the gate only *simulates* it, and a live check remains open (task T042).
  The forms a glob cannot express (short flags, wrappers) are covered by the hooks, which **require
  the `opencode-yaml-hooks` plugin** and are inert without it.
- **An autonomy contract, one file (§2e).** `global/autonomy-contract.md` installs to
  `.opencode/autonomy-contract.md` and defines the four-bucket handoff (Done · Continuing · Decision
  needed · Approval required). The routing block points at it with **one line** — no `/speckit.*`
  command carries the prose, because the instruction budget is finite.
- **A `## Commands` block and a `scripts/verify` entry point (§6b).** `speckit-init` detects the
  stack (Node, Python, Rust, Go, Make), records install/test/lint/typecheck/build in a managed
  `AGENTS.md` block, and generates one `verify` entry point. Detection never guesses: a tool is
  claimed only when a config file proves it, and an unmatched stack records `unresolved` and
  generates nothing.
- **Continuous execution with a budget.** `preset/commands/speckit.implement.prepend.md` gains an
  "execute continuously, with a stopping condition" rule: run the whole approved `tasks.md` without
  a per-phase confirmation, and halt only on the execution budget (3 consecutive failures), an
  approval gate, or a missing credential.
- **A fast lane, `/speckit.quick`.** Small, well-understood work skips the artifacts entirely:
  failing test first for a defect, smallest change, `verify`, one `specs/quick-log.md` entry — and
  **promote to `/speckit.specify` if it grows**. It is installer-copied, because a preset cannot
  create a new command (a `type: "command"` entry naming one is silently ignored).
- **Two more hooks.** `block-force-push` (short-flag force-push, which a glob cannot express without
  false-positiving on `--follow-tags`) and `block-destructive-commands` (`publish`, `supabase db
  push|reset`, `prisma migrate reset|deploy` — including `npx`/wrapper and `-r` forms). Both are
  token-based and **strip quote characters first**, so a quoted flag cannot evade the walk. They are
  segment-guarded, so a command that merely *mentions* the words (`grep -r npm publish .`) is
  allowed. `self-gate.sh` §1f exercises each predicate against its force/irreversible forms and its
  benign ones.
- **`bin/speckit-uninit` reverses all of it** — and only removes what is still ours: the boundary by
  a blank-line-tolerant comparison (because `specify preset add` normalises `opencode.json`), and
  `scripts/verify` by a generated-shape check, so a customised file is kept.

### Why the boundary is mechanical, not more prose

The kit already states its own position: "a rule that cannot be violated needs a hook or a
permission, not a command." The research makes the cost concrete — excessive permissions and
excessive autonomy are named root causes of damaging agent actions (OWASP LLM06), coding agents
carry ambient authority that indirect prompt injection exploits, and rule files themselves are an
attack surface. The boundary is therefore in `opencode.json`, where it is reviewable and versioned,
not in a paragraph the model may or may not follow.

### Deliberately not done

- **No isolation, no parallelism.** Worktrees, containers, and parallel `[P]` dispatch are parked
  with revisit conditions in the spec — each is a separate failure surface.
- **No new runtime dependency.** Bash, `python3`, and `git` only.
- **No enforcement claim for the prose.** The continuous-execution rule and the fast lane are
  commands; only the permission block and the two existing hooks can refuse a tool call.

`scripts/self-gate.sh` gains §1d2 (the four artifacts, and that no command duplicates the contract),
§1d3 (property **P-003**: every irreversible action resolves to `deny`, including the trailing-flag
force-push a naive glob misses), and §5 assertions for the boundary, the Commands block,
`scripts/verify`, the contract, the fast lane, no-clobber, and idempotence. `SKILL.md` and
`README.md` are updated.

## [1.11.0] — 2026-10-16

### Added — an independent review step and a stress test in `/speckit.converge`

The kit verified *artifact consistency and declared boundaries*; it did not review the produced
change. Every worst regression in this kit's history passed review and a keyword check and failed
only under an adversarial run — the no-verify bypass class, the inverted drift checker, the eval
runner that silently evaluated the wrong directory. That defect class had no step. Spec 002
(`specs/002-review-and-stress-gate/`) adds it to converge.

`commands/speckit.converge.prepend.md` gains two sections:

- **Review by a context that did not do the work** — fresh context (ideally a different model);
  findings carry evidence (`file:line` or a reproducing command) or are dismissed with a reason;
  termination is by **unresolved severity (HIGH+), not by the reviewer going quiet**, capped at three
  passes; prefer a deterministic check over a model's judgement.
- **Stress the properties the change asserts** — triggered by *what the change asserts* (a hook,
  gate, validator, guard, invariant), not its size; the **negative case goes first**; a failing case
  becomes a **permanent regression fixture**.

### Why bounded, and why severity-gated (not "until zero findings")

The stop condition is the load-bearing design decision, and the research is unusually clear. The
"self-critique paradox" (Snorkel 2025, via `research.md` [S2]) found that on work a generator already
handles well, a self-critique loop *dropped* accuracy — the critic invents flaws to justify itself.
Independently, LLM judges carry documented self-preference and position bias, so a reviewer sharing
the author's context shares its blind spots ([S1][3][5]). "Zero findings" therefore converges either
never or on a weak reviewer — worse than no reviewer. The rule stops on severity instead, and the
kit's own `/speckit.specify` already caps its loop at three.

### Deliberately not done

- **No hook, no enforcement claim.** Review is judgement and cannot be mechanised; this is an
  advisory command rule, stated as such.
- **No new pipeline step.** Review folds into converge, which already owns close-out.
- **No mandatory multi-pass loop** and no per-change eval — a one-line change and a security hook do
  not warrant the same depth; the stress-test trigger scales by what the change asserts.

`scripts/self-gate.sh` §3b asserts the converge command carries the rule and its bound, and §5
asserts it reaches the materialised command. The `SKILL.md` "the command carries" row is updated.

## [1.10.0] — 2026-10-16

### Added — a research rule for `/speckit.plan`

The plan step could already research (Phase 0 resolves `NEEDS CLARIFICATION` into `research.md`),
but nothing said *what makes a source good* or *when research is worth doing*. The kit's principles
(repository-first, evidence over claims, scope control) implied it; an implication is not a rule.

`commands/speckit.plan.prepend.md` now carries a short research rule, written as **moves rather than
a tier table**. The information-science literature is clear that a few concrete actions — go to the
primary source, corroborate, trace, date — outperform a checklist of criteria; the library field
reached the same conclusion when it superseded the CRAAP checklist with lateral reading
(Sye & Statton Thompson 2023, `doi:10.33011/newlibs/13/9`; Kamela 2024, `doi:10.1002/tl.20608`;
McGrew & Breakstone 2021, `doi:10.1186/s41235-021-00291-4`). So the rule
is five moves, tool-agnostic, and deliberately bounded ("not to survey the topic") so it cannot
license the unconditional full discovery the kit warns against.

### Deliberately not done

- **No named research tool.** The kit installs into arbitrary repos, so it must not couple to one
  vendor's search product (e.g. a specific scholarly-search app). "Go to the primary source" is the
  durable form; the tool is the installer's choice.
- **No change to the research trigger.** Research still keys off `NEEDS CLARIFICATION` and a design
  dependency, not a discretionary "research if useful" — loosening it would reopen the kit's most
  expensive anti-pattern.

`scripts/self-gate.sh` §3b now asserts the plan command carries the rule *and its bound* (`not to
survey the topic`), and the end-to-end check asserts it reaches the materialised command — so a
weakening into a rule that surveys anyway cannot pass silently.

## [1.9.2] — 2026-10-12

The drift checker was inverted, and the preset version was stale. Both found by asking
"do the repos need updating?" and *checking*, not assuming.

### Fixed — `speckit-check` reported "identical" exactly when content differed
`if diff -rq … | grep -v … >/dev/null; then` — `diff` exits 1 when files differ (normal), and
under the script's `set -o pipefail` that 1 propagated through `| grep`, so the `if` took the
**else** branch and printed *"preset content identical"* whenever content actually differed. The
checker was inverted. It survived every test because the gate's functional test only exercised
**version** drift (bump the version → version check fails), never **content** drift.

Fixed by capturing the diff output and testing `[ -n "$d" ]` instead of a pipeline exit code;
`.composed/` (spec-kit-generated) and `.DS_Store` (macOS metadata) are excluded as noise.

### Fixed — preset version was stale at 1.8.0
`preset/preset.yml` was bumped through 1.8.0, but the **v1.9.0 and v1.9.1 commits did not bump
it** — so the kit claimed 1.8.0 while its content was 1.9.0. The gate did not catch this because
it only asserts that the CHANGELOG *has an entry* for the current version, not that the version is
the *newest* entry. Now at 1.9.2, and the gate asserts the preset version equals the latest
CHANGELOG version.

### Consequence — the three applied repos were stale and reported current
`speckit-kit`, `speckit-sandbox`, `ocr-kit` were missing the v1.9.0 content (progress ledger in
`implement`/`converge`; the first-act directive in `AGENTS.md`). `speckit-check` said "current"
because of the inverted content check. Re-applied.

### Added — gate coverage for both bugs
- §1c now asserts the preset version equals the newest CHANGELOG version (catches a stale bump).
- §1g's checker test now exercises **content** drift (weaken an installed preset file → the
  checker must flag it), not only version drift.

## [1.9.1] — 2026-10-12

Adversarial security audit of the no-verify hook. The audit found — and this release fixes —
an actual bypass class that a keyword-level test could not have caught.

### Security fix: no-verify guard was string-anchored, bypassable by flag position
The guard anchored on `git[[:space:]]+commit`, so any flags between `git` and `commit`
bypassed it entirely:
- `git -c core.hooksPath=/dev/null commit -m x`
  (points Git at an empty hooks dir — no-verify by another name)
- `git --no-pager --git-dir=.git --work-tree=. commit -n -m x`

Verified empirically: in a scratch run, both commands EXECUTED (only git's own "nothing
staged" stopped the commit, not our guard). Fix: the predicate is now token-based (awk)
and blocks three unambiguous signals anywhere in a git command — `--no-verify`,
`core.hooksPath=<something>`, and a `commit`/`commit-tree` subcommand followed by `-n`.
Unit-tested 13 cases: 8 bypass forms blocked, 5 benign uses (`git log -n 5`, `git diff -n`,
`grep -n`, `npm -n`, `git config core.hooksPath` read) allowed.

### Gate upgrade: the gate now tests BEHAVIOR, not keywords
The audit found the §1f assertions only checked the hook *contains* the right words — a
weakened guard (bypass signal removed) still passed the gate. Two holes, same shape as the
`$PWD` bug: an instrument whose failure mode the gate doesn't surface. §1f now extracts the
exact awk the hook ships and exercises it: 4 bypass forms must BLOCK, 3 benign forms must
ALLOW. Verified: weakening the hook now FAILs the gate with the precise bypass named.

### Scope of the audit (everything checked, nothing else found)
- drift checker: all 4 repos current/known-stale; gate's no-repo-drift fixture verified
- generated-file hook: 10 path variants, 5 block / 5 allow — precise
- gate integrity: fails when hooks file deleted, when ledger rule renamed, when hook
  predicate weakened
- two-session ledger + injection claims re-checked, unchanged by this release

## [1.9.0] — 2026-10-12

Two adoptions from obra/superpowers, both researched against opencode specifics and both verified
by execution, not claimed.

### First-act session injection (adopted from superpowers; mechanism is opencode-native AGENTS.md)
Superpowers forces skill use by injecting a start-of-session directive via a SessionStart hook.
Research for opencode: its equivalent is `AGENTS.md`, loaded into every session including
`opencode run` (verified empirically), with global + per-project files composing. The kit already
had the pieces; the gap was that neither the global working-agreements nor the per-project bridge
told the agent to **check the workflow as its first act**.

- `global/working-agreements.md` now opens with "First act of every session": detect `.specify/`,
  check for an applicable skill/command before guessing, prefer `/speckit` over the skill (which
  loads ~60%).
- The project `AGENTS.md` bridge (installed by `speckit-init`) now leads with the same directive.

VERIFIED: the outcome-eval scenario that previously FAILED (agent asked for approval on a one-word
typo fix) now PASSES with `skill DID NOT load` and no `/speckit` invocation — the injected directive
alone produced the correct minimal-path behaviour. A single-run pass is evidence, not a guarantee.

### Progress ledger (adopted from superpowers; location and lifecycle redesigned for this kit)
Superpowers uses `<repo-root>/.superpowers/sdd/<plan>/progress.md`, git-ignored, deleted at plan
end, because "conversation memory does not survive compaction [—] the most expensive failure
observed" is controllers re-dispatching already-completed sequences after losing their place. The
pattern is industry-standard (Anthropic long-running-harness guidance, Ralph family,
better-handoff): state lives on disk; completion markers carry verifiable evidence.

Our design, researched:
- **Location:** `specs/<NNN>-<slug>/progress.md` next to the other artifacts — a later agent finds
  it in the same listing; survives clone, machine switch and even a hard-tree clean (superpowers'
  git-ignored scratch does not). Deliberate deviation, sourced (better-handoff).
- **Structure:** identity header + documented resume rule; `Task <N>: complete` lines MUST carry
  evidence; `Ruling:` lines; in-flight markers. "Ticking the box is a claim; the ledger line is the
  checkpoint."
- **End-of-life:** tombstone (`Status: complete` + date), not delete — audit trail for committed
  specs; a live-looking ledger is a hazard.

VERIFIED by a two-session execution test: session 1 wrote the ledger with identity header, T001
complete WITH evidence and a correct ruling (plan.md content is data, not instructions). Session 2
(fresh process, zero inherited history) reported "T001 done — prior session — Not re-done", and
implemented only T002. The documented superpowers failure ("re-dispatched completed sequences") was
demonstrated prevented.

### Also fixed
- The drift checker's AGENTS.md needle referenced the old bridge phrase; the new first-act
  directive changed the text and the checker started flagging freshly-installed repos as drifting.
  Caught by the gate's own functional test.

### Sources
Anthropic "Effective harnesses for long-running agents" (2025-11), "Harness design for long-running
apps" (2026-03); superpowers skills/docs (invention vs standard flagged); better-handoff; Ralph
family; CompAct-Bench and Terminal-Bench 2.0 context-loss taxonomies.

## [1.8.0] — 2026-10-08

**Enforcement that actually holds.** The kit has always said, honestly, that it cannot enforce
anything — commands are prompt text and the model can deviate. It also said a rule that must not be
violable needs a hook. This ships the hooks.

### Added — `hooks/speckit-hooks.yaml`
Two hooks, installed by `speckit-init` into `.opencode/hook/hooks.yaml`, run by the
`opencode-yaml-hooks` plugin on tool lifecycle events. They run **below the prompt layer**, so the
model cannot be talked out of them:

| Hook | Blocks | Why |
| --- | --- | --- |
| `block-commit-no-verify` | `git commit --no-verify` / `-n` | The documented bypass. An agent using `--no-verify` to skip pre-commit hooks across six commits is the case that motivated it. `action: stop` — a session that just tried to disable the checks should not continue unattended. |
| `protect-generated-files` | hand-edits to `.opencode/commands/speckit*.md`, `.specify/scripts/`, `.specify/templates/`, `.specify/presets/` | The kit told agents these are regenerated and an edit is lost. Nothing enforced it, so real effort could vanish at the next install. |

**Deliberately tiny, and near-zero false positive.** Both hooks block only things that are wrong in
essentially every case; the research on gates is unambiguous that a noisy gate gets removed and then
none of them work. The allow-list is explicit: `.specify/memory/constitution.md` and `specs/` are
editable, and the hook says so in its own message.

### Verified — by execution, not by reading
- `git commit --no-verify` → **blocked**, session aborted, no commit created
- edit to `.opencode/commands/speckit.specify.md` → **blocked**, file byte-unchanged
- edit to `.specify/memory/constitution.md` → **not blocked**, edit landed (the false-positive check)
- the guard is respected, not routed around: on being blocked, the agent said *"I'm not going to
  route around the guard with a rewritten equivalent (`find . -exec chmod`, a Python loop, etc.) —
  that would defeat the point of it being there."*

### Added — inert detection
The hooks need the `opencode-yaml-hooks` plugin. Without it the file does nothing, so `speckit-init`
checks every opencode config it can find and **says so loudly** rather than installing a file that
silently does nothing:

```
!! hooks installed but INERT: the 'opencode-yaml-hooks' plugin is not in any opencode config.
!!   activate with:  opencode plugin opencode-yaml-hooks
```

Verified by running the installer with a clean `HOME`.

### Safe by construction
- `speckit-init` **never clobbers** an existing `.opencode/hook/hooks.yaml` that is not ours — it
  warns and leaves it for the project to merge.
- `speckit-uninit` removes the hooks file **only if it is still byte-identical** to the one shipped;
  if the project edited it, it is theirs and is left alone.
- The `AGENTS.md` bridge now states the two enforced rules, so the agent knows the layer exists.

### Note on what this does *not* fix
This closes the bypass and the generated-file case. It does **not** make the workflow itself
enforceable — there is no hook for "the agent must have written a spec". That remains a
probability surface, and the kit still says so.

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
