# What we learned dogfooding spec-driven development

*Writing the spec is the easy part. Getting the spec to actually bind is the whole problem.*

Spec-driven development is having a moment. The pitch is simple and largely correct: write down
what you want before you write the code, make the artifacts the source of truth, and make the code
match them. `[Spec Kit](https://github.com/github/spec-kit)` is the reference implementation of
that loop — `constitution → specify → plan → tasks → implement → converge` — and the workflow is
genuinely good at keeping an AI coding agent on the rails.

We spent three weeks building a spec-driven development kit on top of Spec Kit. This post is not
about the loop. It's about the three things we got wrong, all of which failed *silently*, and what
they imply about where enforcement has to live.

## The problem SDD actually solves

Start from the failure mode, not the workflow.

An agent that reports success without verification is worse than one that reports a limitation,
because the limitation is invisible. Compiling is not evidence. One passing test is not evidence. An
edited file is not evidence.

That is the thing spec-driven development is really buying: it converts invisible failure into
detectable failure. Two requirements that don't map to work silently. A requirement that grew three
unrequested features while nobody was looking. A plan written fluently against the system the author
*assumed* rather than the one they *read*.

The artifacts work as a forcing function precisely because they're written down and checkable. That
much is well-trodden. The uncomfortable part is everything required to keep the forcing function
under load.

## Make the spec executable, or it's just prose

Our own feature spec for this work set the bar: requirements in EARS notation, each testable one
mapped to a universally-quantified correctness property.

EARS constrains prose into shapes a reviewer can write an acceptance check from. Five patterns —
`THE <system> SHALL …` (ubiquitous), `WHEN` (event), `WHILE` (state), `WHERE` (optional feature),
`IF…THEN` (unwanted behaviour) — with `SHALL` as the only normative keyword, RFC 2119 style.

Then in the plan, each testable requirement maps to a property that starts `for any`. Properties
trace `FR-xxx → P-xxx → T0xx`, and the tasks template requires one property-based test per property.

The payoff: example-based tests only check the cases somebody thought of. A property gets checked
against many generated inputs, so it finds the cases nobody did.

Two details we insisted on, both about resisting cargo-cult rigor:

- **An explicit opt-out.** A requirement that doesn't map cleanly to a universal property — "tone is
  welcoming" — gets a recorded reason and *no* property. Never force a vacuous one. A property that
  cannot fail is worse than no property, because it looks like coverage.
- **Never hardcode a framework.** The plan carries a *detection* step — look for `hypothesis`,
  `fast-check`, `jqwik`, `proptest`, `QuickCheck`, `PropEr` in the target project — and records an
  explicit adopt-or-fallback decision that tasks follow verbatim. Our self-gate now asserts that no
  concrete framework name appears in kit-owned normative text outside that one allowlisted table.

That's the shape of good SDD, actually: rigor where it constrains, and an explicit, written-down way
to decline it where it doesn't.

## Finding 1: `append` alone does not deliver the addendum

The obvious approach to extending Spec Kit's templates is a preset with `strategy: "append"` — the
core templates keep improving underneath, we only own our delta, and nobody has to hand-merge
upstream changes forever. The fork problem, one level down.

It worked. And then it didn't, on one artifact, silently.

A dogfood run produced a `plan.md` and a `tasks.md` carrying their appended sections, while
`spec.md` had **none** of them. The template had resolved correctly — 213 lines, addenda included —
and the command had explicitly instructed:

> Copy the resolved `spec-template` to `spec.md` as the starting point.

And the agent still produced a spec with zero appended sections.

The lesson is uncomfortable and worth stating plainly: **the template is not the instruction.** The
instruction the agent actually follows is the command. A correctly-resolved artifact sitting on disk
is inert data until something forces the agent to materialise it, and agents do not do that
consistently.

The fix was to stop trusting the template and start instructing the behaviour — `prepend` a
short section-integrity rule to `speckit.specify`, `speckit.plan` and `speckit.tasks`: materialise
the resolved template, edit it in place, never drop a section. (`prepend` composes with upstream
command updates rather than replacing them, and it has to insert *after* the YAML frontmatter.)

| | `spec.md` | `plan.md` | `tasks.md` |
| --- | --- | --- | --- |
| Before prepends | **0** appended sections | carried its sections | carried its sections |
| After prepends | all 5 | all 4 | all 3 |

Two consecutive runs, all sections present. The self-gate asserts the prepends are in the
materialised commands *and* that the frontmatter survived.

If your SDD setup composes guidance into templates, measure delivery. Not "does the template
resolve" — everyone checks that. Measure "does the artifact that lands have it."

## Finding 2: a skill is a probabilistic trigger

Our methodology lived in an agent skill. Sensible — research on agent instruction files is
consistent that adherence degrades past roughly 150 lines, and bloating an always-loaded file makes
every session in every repo worse. A skill costs ~100 tokens of metadata until the task calls for
it.

Then we measured the trigger rate: **~60%** of relevant requests.

So every rule we cared most about — the ones that must *always* apply — was being applied roughly
three times in five, and failing quietly on the other two. A skill that doesn't load produces no
error. The agent just handles the task itself, confidently, without the methodology.

The ecosystem had already answered this. Across 41 community presets, **39 use commands, 0 use
skills**.

So in v1.2.0 we moved the enforceable rules into the commands themselves — prepended to the command
that runs each step:

| Command | Carries |
| --- | --- |
| `speckit.specify` | workflow selection, product reasoning, ask only what matters, record assumptions instead of inventing requirements |
| `speckit.plan` | inspect before proposing, the sweep for re-enumerated sets, repository-as-evidence, stop at the approval gate |
| `speckit.tasks` | every task traces to a requirement, one verifiable outcome, scope control |
| `speckit.implement` | approved work only, evidence before "done", tick tasks honestly, repair the earliest artifact |
| `speckit.converge` | evidence-based completion, no rounding up to green, verify declared boundaries, handoff discipline |

*(Later releases extended the `speckit.implement` row with an execution budget and added the
`/speckit.quick` fast lane — see `CHANGELOG.md`.)*

A command is already loaded when it runs. There is no progressive-disclosure argument for putting
step rules in a skill.

The skill stayed, but changed job: it's the *reasoning* layer — why each rule exists and what it
prevents — and it explicitly defers. **If the skill and a command disagree, the command wins.**

We verified with the skill fully disabled (`~/.agents/skills` emptied): `/speckit.specify` still
stated a workflow choice, still recorded substantive assumptions instead of inventing requirements,
and still produced a spec carrying all five appended sections.

The generalisable version: put *rules* where execution is guaranteed; put *reasoning* in whatever
progressive-disclosure mechanism you like. Those are different jobs and they have opposite
placement constraints.

## Finding 3: don't materialize what a template owns

The third failure was subtler, and it was an architecture error rather than a prompt error.

We wanted delivery principles to live in the project's constitution. The obvious approach: drop a
`.specify/memory/constitution.md` into place during init.

That's the approach Spec Kit's own architecture doc warns against. Initialisation seeds that file
**once** and preserves existing files byte-for-byte, and `/speckit.constitution` then resolves the
composed `constitution-template` **at runtime**. A hand-placed file is a *materialized copy*, and
materialized edits get shadowed or clobbered on the next recompose.

So the principles live in the preset's `constitution-template` append, and the first
`/speckit.constitution` run composes them in properly.

This is the same species of bug as Finding 1. There, the template resolved and the agent ignored
it. Here, the template would resolve and get overwritten. Both are silent. Both are invisible until
you diff the artifact against what you thought you shipped.

The rule I'd generalise: **before you hand-place a file, find out whether something else composes
it at runtime.** If something does, your file is a cache entry with no invalidation strategy.

## The failure mode that has no error message

The reason all three of the above matter more than usual in an agent context is this:

> A requirement with no task is unbuilt. A task with no requirement is scope creep.

These two failure modes are symmetric, and **both are completely silent**. Nothing throws. The
build is green. The tests pass. One of them is just quietly wrong, and no amount of CI on the code
will ever tell you, because the code is doing exactly what was written down — the written-down part
is what failed.

That's the real argument for traceability. Not bureaucracy. The traceability is the only place the
failure is visible at all.

It also puts the burden where it belongs: if you can only afford one habit, make it the trace. Every
task traces to a requirement, one verifiable outcome per task, and repair contradictions at the
*earliest* affected artifact rather than patching the symptom downstream.

## The unglamorous work is most of the work

None of the findings above came from the methodology. They came from plumbing, and I'd budget for it
honestly:

- **Test the trigger, not just the behaviour.** A skill can give excellent guidance once loaded and
  still load 60% of the time. We have two eval suites for exactly this reason, and trigger rate is
  the primary metric — ≥90% on relevant queries, **0** false triggers. A skill that doesn't load is
  the documented most-common failure mode precisely because it has no symptom.
- **Test both bashes.** CI runs our self-gate on Linux bash 5 *and* macOS system bash 3.2. A
  construct that parses on one and not the other ships an installer that silently does nothing for
  every Mac user.
- **Symlinks, not URLs.** Our remote instruction fetch was unauthenticated and returned an empty
  string on *any* failure — a broken URL silently removed your instructions with no error. Symlinks
  have no network dependency and no silent-failure mode.
- **Gate the kit on itself.** The self-gate validates the preset manifest, skill frontmatter, both
  eval files, and runs `speckit-init` end-to-end on a scratch repo, checking all four templates
  compose and that a re-run is idempotent. It fails if the current preset version has no changelog
  entry.

Every one of these is a guard against a failure that looks exactly like success.

## Proportion is a preset choice, not conditional logic

One more thing worth stealing: the temptation inside any SDD setup is to build conditional logic
into the templates — "if this is a small change, do less." Don't.

Running full product discovery on a small, well-understood maintenance task is a *failure*, not
diligence. But branching logic inside a template is where methodology goes to die: every future
reader has to reason about the branches, and the branches are exactly the part no test covers.

Spec Kit's answer is a preset choice. `lean` is bundled and replaces the five core commands with
stripped-down prompts. It's genuinely good for small, well-understood work. It's also mutually
exclusive with addenda in practice — `lean` bypasses the template files entirely, so every appended
section has no effect under it.

Pick `lean` for small work. Pick a real preset when artifact quality is worth the ceremony. Don't
try to express both as conditional logic inside one template.

## The takeaway

If you're adopting spec-driven development, and especially if you're running it with an AI coding
agent, the loop itself is table stakes. Four things actually determine whether it works:

1. **Make the spec executable.** Constrained requirement shapes, properties traceable to tests — and
   an explicit way to decline a property you can't honestly write.
2. **Verify delivery, not just composition.** A resolved template that the agent ignored produces a
   green run. Diff the artifact against what you think you shipped.
3. **Put rules where execution is guaranteed, reasoning where it's cheap.** Commands beat skills for
   anything that must always apply. Skills are for the *why*.
4. **Know which template owns each file before you hand-place it.** If something composes it at
   runtime, your copy is a cache entry with no invalidation.

And audit for the failure that never errors: the requirement that got no task, the task that got no
requirement. Everything else on this list is engineering. That one is the point.

---

*Repo: `speckit-kit` — a reusable upgrade layer for GitHub Spec Kit. `BUILD_PLAN.md` has the full
research behind each decision; `evals/` has the runners and recorded results.*