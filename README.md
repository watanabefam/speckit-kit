# speckit-kit

A reusable upgrade layer for [GitHub Spec Kit](https://github.com/github/spec-kit),
wired for **opencode** and **Freebuff/Codebuff**.

Spec Kit is deliberately minimal: its core templates are generic, and it installs no
extensions by default. This repo adds the parts that are worth having consistently across
projects, using Spec Kit's own extension points rather than forking it.

## What it provides

| Component | Mechanism | Purpose |
| --- | --- | --- |
| `preset/` | Spec Kit **preset**, `strategy: "append"` | Adds problem framing, traceability, approval boundaries and verification sections to the spec/plan/task templates — **without replacing core** |
| `skill/spec-driven-development/` | **Agent skill** (agentskills.io) | Carries the methodology via progressive disclosure — ~100 tokens until triggered |
| `global/working-agreements.md` | Global agent rules | Routing only (~25 lines): "this project uses Spec Kit, load the skill" |
| `constitution/principles.md` | Optional seed | Eight generic project principles |
| `bin/speckit-init` | Installer | One command to set a project up |

## Why append, not replace

Presets default to `replace`, which would mean hand-merging upstream template changes
forever — the fork problem, one level down. `strategy: "append"` means the core templates
keep improving underneath and this repo only owns its delta.

## Why a skill, not more instructions

Research on agent instruction files is consistent: adherence degrades past roughly 150
lines, and bloated instruction files get ignored. Putting a 1,348-line methodology into an
always-loaded file would have made every session worse in every repo — including the ones
that never touch Spec Kit. As a skill, it costs ~100 tokens of metadata until the task
actually calls for it.

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

## Design notes

**Symlinks, not URLs.** opencode can fetch remote instruction files, but the fetch is
unauthenticated and returns an empty string on *any* failure (`session/instruction.ts:100`)
— a broken URL silently removes your instructions with no error. Symlinks have no network
dependency and no silent-failure mode.

**Freebuff reads skills.** It looks in `~/.agents/skills` and `.agents/skills`, the same
agentskills.io format opencode uses, so one skill serves both agents. (Freebuff's
`~/AGENTS.md` knowledge-file channel is used only for the routing file.)

**Preset installed with `--dev`, not `--from`.** Spec Kit's installer copies the whole
source directory into `.specify/presets/<id>/`. Keeping the preset in `preset/` means only
the preset is copied into each project, not this entire repo.

## Layout

```
bin/speckit-init                  installer
preset/                           spec-kit preset (append strategy)
skill/spec-driven-development/    agent skill + references
global/working-agreements.md      global routing rules
constitution/principles.md        optional constitution seed
BUILD_PLAN.md                     how this was built + the research behind it
```
