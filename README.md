# speckit-kit

A reusable upgrade layer for [GitHub Spec Kit](https://github.com/github/spec-kit),
wired for **opencode** and **Freebuff/Codebuff**.

Spec Kit is deliberately minimal: its core templates are generic, and it installs no
extensions by default. This repo adds the parts worth having consistently across projects,
using Spec Kit's own extension points rather than forking it.

## What it provides

| Component | Mechanism | Purpose |
| --- | --- | --- |
| `preset/` | Spec Kit **preset**, `strategy: "append"` ×4 | Adds delivery principles to the constitution template, and problem framing, traceability and verification sections to the spec/plan/task templates — **without replacing core** |
| `skill/spec-driven-development/` | **Agent skill** (agentskills.io) | Carries the methodology via progressive disclosure — ~100 tokens until triggered |
| `global/working-agreements.md` | Global agent rules | Routing only (~25 lines): "this project uses Spec Kit, load the skill" |
| `bin/speckit-init` | Installer | One command to set a project up |
| `evals/` | Skill evaluations | Three scenarios testing the behaviours most likely to regress |

## Why append, not replace

Presets default to `replace`, which would mean hand-merging upstream template changes
forever — the fork problem, one level down. `strategy: "append"` means the core templates
keep improving underneath and this repo only owns its delta.

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
evals/skill-evals.json            skill evaluations
BUILD_PLAN.md                     how this was built + the research behind it
```
