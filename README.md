# speckit-kit

A reusable upgrade layer for [GitHub Spec Kit](https://github.com/github/spec-kit),
wired for **opencode** and **Freebuff/Codebuff**.

Spec Kit is deliberately minimal: its core templates are generic, and it installs no
extensions by default. This repo adds the parts worth having consistently across projects,
using Spec Kit's own extension points rather than forking it.

## What it provides

| Component | Mechanism | Purpose |
| --- | --- | --- |
| `preset/` | Spec Kit **preset** — `strategy: "append"` on 4 templates **+ `prepend` on 5 commands** | Adds delivery principles and traceability sections to the templates, **and** puts each step's enforceable rules into the command that runs that step |
| `skill/spec-driven-development/` | **Agent skill** (agentskills.io) | The *reasoning* layer — why the rules exist and what they prevent. Does not restate them |
| `global/working-agreements.md` | Global agent rules | Routing only (~25 lines): "this project uses Spec Kit, load the skill" |
| `bin/speckit-init` | Installer | One command to set a project up |
| `evals/` | Skill evaluations | Behaviour evals + **trigger-accuracy evals** (the failure mode that's silent) |
| `scripts/self-gate.sh` + `.github/workflows/` | CI | The kit gates itself on every push, on Linux **and** macOS bash 3.2 |

## Why append, not replace

Presets default to `replace`, which would mean hand-merging upstream template changes
forever — the fork problem, one level down. `strategy: "append"` means the core templates
keep improving underneath and this repo only owns its delta.

## Why the rules live in the commands, not only in the skill

The skill fires on roughly **60%** of relevant requests (measured — see `evals/`). A rule that
must *always* apply cannot live behind a probabilistic trigger. So each step's enforceable
rules are prepended to the command that runs that step:

| Command | Carries |
| --- | --- |
| `speckit.specify` | workflow selection, product reasoning, ask only what matters, record assumptions instead of inventing requirements |
| `speckit.plan` | inspect before proposing, the sweep for re-enumerated sets, repository-as-evidence, stop at the approval gate |
| `speckit.tasks` | every task traces to a requirement, one verifiable outcome, scope control |
| `speckit.implement` | approved work only, evidence before "done", tick tasks honestly, repair the earliest artifact |
| `speckit.converge` | evidence-based completion, no rounding up to green, verify declared boundaries, handoff discipline |

This is also what the ecosystem does: across 41 community presets, **39 use commands, 0 use
skills**. A command is already loaded when it runs, so this costs nothing extra — there is no
progressive-disclosure argument for putting step rules in a skill.

The skill remains as the *reasoning* layer, and explicitly defers: **if the skill and a command
disagree, the command wins.**

Verified with the skill fully disabled (`~/.agents/skills` emptied): `/speckit.specify` still
stated a workflow choice, recorded substantive assumptions rather than inventing requirements,
and produced a spec carrying all five appended sections.

## Why there are also command prepends

**`append` alone is not enough.** An addendum only reaches an artifact if the agent resolves
the composed template — and agents do not do that consistently. A dogfood run produced a
`plan.md` and a `tasks.md` carrying their appended sections while `spec.md` silently had
none, even though the template resolved correctly (213 lines, addenda included) and the
command explicitly instructed *"Copy the resolved `spec-template` to `spec.md` as the
starting point."*

The command is the instruction the agent actually follows, so the preset also **prepends a
short section-integrity rule** to `speckit.specify`, `speckit.plan` and `speckit.tasks`. It
tells the agent to materialise the resolved template, edit it in place, and never drop a
section. `prepend` composes with upstream command updates instead of replacing them, and it
inserts *after* the YAML frontmatter (verified — the first line stays `---`).

Verified effect: before the prepends, a generated `spec.md` had **0** appended sections;
after, two consecutive runs produced specs with **all 5**, a plan with all 4, and a tasks
file with all 3. `scripts/self-gate.sh` now asserts the prepends are present in the
materialised commands and that the frontmatter survived.

This is the same pattern the community's `toc-navigation` preset uses. `specassay` uses
`append` alone and has the same latent flaw.

## Why the constitution is a template append, not a seed file

The obvious approach — dropping a `.specify/memory/constitution.md` into place — is the one
Spec Kit's own architecture doc warns against. Initialisation seeds that file **once** and
preserves existing files byte-for-byte; `/speckit.constitution` then resolves the composed
`constitution-template` **at runtime**. A hand-placed file is a materialized copy, and the
docs are explicit that materialized edits *"get shadowed or clobbered on the next
recompose."*

So the principles live in the preset's `constitution-template` append. The first
`/speckit.constitution` run composes them in properly.

## Why a skill, not more instructions

Research on agent instruction files is consistent: adherence degrades past roughly 150
lines, and bloated instruction files get ignored. Putting a 1,348-line methodology into an
always-loaded file would have made every session worse in every repo — including ones that
never touch Spec Kit. As a skill it costs ~100 tokens of metadata until the task calls for it.

## Install

Once, globally:

```bash
# skill — one symlink serves BOTH opencode and Freebuff (~/.agents/skills is read by both)
ln -s ~/Documents/GitHub/speckit-kit/skill/spec-driven-development \
      ~/.agents/skills/spec-driven-development

# global routing rules
mkdir -p ~/.config/opencode
ln -s ~/Documents/GitHub/speckit-kit/global/working-agreements.md ~/.config/opencode/AGENTS.md
ln -s ~/Documents/GitHub/speckit-kit/global/working-agreements.md ~/.AGENTS.md

# installer on PATH
ln -s ~/Documents/GitHub/speckit-kit/bin/speckit-init ~/.local/bin/speckit-init
```

Per project:

```bash
speckit-init ~/path/to/project
speckit-init --with-bug --with-assess ~/path/to/project
```

Then run `/speckit.constitution` as the first step of the loop — that is what applies the
delivery principles.

## Design notes

**Symlinks, not URLs.** opencode can fetch remote instruction files, but the fetch is
unauthenticated and returns an empty string on *any* failure (`session/instruction.ts:100`)
— a broken URL silently removes your instructions with no error. Symlinks have no network
dependency and no silent-failure mode.

**Freebuff reads skills.** It looks in `~/.agents/skills` and `.agents/skills`, the same
agentskills.io format opencode uses, so one skill serves both agents. Freebuff's
`~/AGENTS.md` knowledge-file channel is used only for the routing file.

**Preset installed with `--dev`, not `--from`.** Spec Kit's installer copies the whole
source directory into `.specify/presets/<id>/`. Keeping the preset in `preset/` means only
the preset is copied into each project, not this entire repo.

## Alternatives worth knowing

The Spec Kit community catalog has ~40 presets, several of which overlap this one. They are
mostly **discovery-only** in the catalog, so install them with `--from`:

| Preset | Overlap / difference |
| --- | --- |
| `specassay` | Heavier traceability *system*: durable IDs (`FR-LOG-01`), `Carries:` fields, `@covers` annotations, a `trace-manifest.json`, CI gates, a companion extension. Appends to spec/tasks/constitution. Adopt if you want a full ID regime. |
| `openup-governance` | Composes OpenUP lifecycle governance into constitution + spec + plan + tasks, and wraps `/tasks` and `/implement`. Closest targeting to this repo. |
| `workflow-preset` | Behaviour-first specification and "agent-native handoff orchestration". |
| `explicit-task-dependencies` | Explicit `depends on T###` declarations plus an execution-wave DAG. |
| `test-first-governance` | TDD/BDD Gherkin scenarios, traceability, risk-based quality gates. |
| `lean` | **Bundled** (`specify preset add lean`, no download). Replaces the five core commands with stripped-down prompts — "just the prompt, just the artifact". |

### Proportionality: use `lean`, don't expect this preset to downscale

This repo's addenda are unconditional: they add substance to spec/plan/tasks at every scale.
There is no "small feature" mode, and that is deliberate — Spec Kit's own answer to
proportionality is a **preset choice**, not conditional logic inside templates.

Stay away from `lean` if you want these addenda, and vice versa. `lean` **replaces the core
commands with prompts that generate artifacts directly, bypassing the template files
entirely** — so every section this preset appends has no effect under `lean`. The two are
mutually exclusive in practice: pick `lean` for small, well-understood work, and this preset
when the artifact quality is worth the ceremony.

Notably, **none of the 40 community presets ship an agent skill** — the methodology layer
that makes an agent *behave* is not provided by any of them. That is this repo's main
differentiator, alongside the opencode+Freebuff wiring.

See `BUILD_PLAN.md` for the research and decisions behind the structure.

## Layout

```
bin/speckit-init                  installer
preset/                           spec-kit preset (append strategy, 4 targets)
skill/spec-driven-development/    agent skill + references
global/working-agreements.md      global routing rules
evals/                            behaviour + trigger-accuracy evals, and two runners
scripts/self-gate.sh              the kit's own gate
.github/workflows/self-gate.yml   runs that gate on Linux and macOS
BUILD_PLAN.md                     how this was built + the research behind it
```

## Testing

Two things can go wrong with a skill, so there are two kinds of test:

- **Behaviour** (`evals/skill-evals.json`) — does it give good guidance once loaded?
- **Triggering** (`evals/trigger-evals.json`) — does it load at all? A skill that doesn't
  load fails *silently*: no error, the agent just handles the task itself. This is the
  documented most-common failure mode, so trigger rate is the primary metric (**≥90%** on
  relevant queries, **0** false triggers).

`scripts/self-gate.sh` validates the preset manifest, the skill frontmatter, both eval files,
and runs `speckit-init` end-to-end on a scratch repo — checking all four templates compose and
that a re-run is idempotent. CI runs it on **both** Linux bash 5 and macOS system bash 3.2,
because a construct that parses on one and not the other ships an installer that silently does
nothing for every Mac user.

See `evals/README.md` for the runners and how to record results.

