# speckit-kit

A reusable upgrade layer for [GitHub Spec Kit](https://github.com/github/spec-kit),
wired for **opencode** and **Freebuff/Codebuff**.

> **Not an expert, or using an AI assistant?** Give it this file and let it set everything up:
> [`QUICKSTART.md`](QUICKSTART.md) — one command, verified to work unattended.

Spec Kit is deliberately minimal: its core templates are generic, and it installs no
extensions by default. This repo adds the parts worth having consistently across projects,
using Spec Kit's own extension points rather than forking it.

## What it provides

| Component | Mechanism | Purpose |
| --- | --- | --- |
| `preset/` | Spec Kit **preset** — `strategy: "append"` on 4 templates **+ `prepend` on 5 commands** | Adds EARS requirements guidance and correctness properties, delivery principles and traceability sections to the templates, **and** puts each step's enforceable rules into the command that runs that step |
| `skill/spec-driven-development/` | **Agent skill** (agentskills.io) | The *reasoning* layer — why the rules exist and what they prevent. Does not restate them |
| `global/working-agreements.md` | Global agent rules | Routing only (~25 lines): "this project uses Spec Kit, load the skill" |
| `global/autonomy-contract.md` | Installed instruction file | The four-bucket handoff (Done · Continuing · Decision needed · Approval required). **One file, not prose in every command** |
| `permissions/opencode-permission.jsonc` | opencode config | The **mechanical boundary**: `deny` force-push / publish / destructive DB, `ask` on push, reset, clean. Installed into the project's `opencode.json` (never clobbering one that exists) |
| `commands/speckit.quick.md` | Installer-copied command | The fast lane for small work — a preset cannot create a command, so the installer copies it |
| `bin/speckit-init` | Installer | One command to set a project up |
| `bin/speckit-resume` | Kit tool | Computes the resume point from the ledger, so the resume rule is asserted, not interpreted |
| `evals/` | Skill evaluations | Behaviour evals + **trigger-accuracy evals** (the failure mode that's silent) |
| `scripts/self-gate.sh` + `.github/workflows/` | CI | The kit gates itself on every push, on Linux **and** macOS bash 3.2 |

## Why append, not replace

Presets default to `replace`, which would mean hand-merging upstream template changes
forever — the fork problem, one level down. `strategy: "append"` means the core templates
keep improving underneath and this repo only owns its delta.

## EARS requirements and correctness properties

Specs written with this preset are **executable**, in two layers:

1. **EARS notation** (`spec.md`). Every functional requirement uses one of the five EARS shapes —
   `THE <system> SHALL …` (ubiquitous), `WHEN` (event), `WHILE` (state), `WHERE` (optional
   feature), `IF…THEN` (unwanted behaviour) — with `SHALL` as the only normative keyword. EARS
   constrains prose into shapes a reviewer can write an acceptance check from. (Alistair Mavin
   et al., RE'09.)

2. **Correctness properties** (`plan.md`). Each testable requirement maps to a
   universally-quantified property starting `for any …`. Requirements that do not map cleanly
   get an **explicit opt-out** with a reason — never a vacuous property. Properties trace
   `FR-xxx → P-xxx → T0xx`, and the tasks template requires one property-based test task per
   property.

**Framework-agnostic by design.** The preset never hardcodes a PBT framework. `plan.md` holds a
*detection* step — look for `hypothesis`, `fast-check`, `jqwik`, `proptest`, `QuickCheck`,
`PropEr` in the target project — and records an explicit `adopt` or `fallback` decision that
`tasks.md` follows verbatim. A gate assertion enforces that no concrete framework name appears
in kit-owned normative text outside the one allowlisted detection table and the one "do not
hardcode" example.

Why this matters: example-based tests only check the cases someone thought of. A property is
checked against many generated inputs, so it finds the cases nobody did — and it keeps the link
from requirement to test explicit.

## Why the rules live in the commands, not only in the skill

The skill fires on roughly **60%** of relevant requests (measured — see `evals/`). A rule that
must *always* apply cannot live behind a probabilistic trigger. So each step's rules are prepended
to the command that runs that step:

| Command | Carries |
| --- | --- |
| `speckit.specify` | workflow selection, product reasoning, ask only what matters, record assumptions instead of inventing requirements |
| `speckit.plan` | inspect before proposing, the sweep for re-enumerated sets, repository-as-evidence, stop at the approval gate |
| `speckit.tasks` | every task traces to a requirement, one verifiable outcome, scope control |
| `speckit.implement` | approved work only, continuous execution with an execution budget, evidence before "done", tick tasks honestly, repair the earliest artifact |
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

**The rule has a checker, and the checker has a gate.** `scripts/check-section-integrity.sh` compares
an artifact's headings with the resolved template's: missing, reordered, or **empty** sections fail —
an empty required heading is `STUB`, because adding headings to satisfy a structure check is how
conformance becomes a ritual. A section that does not apply keeps its heading and says
`Not applicable — <reason>`; the gate runs the check over every `specs/*/spec.md`, so drift is a
failure rather than a discovery. Rationale and sources: `decisions/0004`.

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

## Usage

Start with the deterministic entry point:

```
/speckit
```

It classifies the request, picks the smallest workflow that fits, and routes to the right step. It
prints **one line stating which workflow it picked and why**.

Use `/speckit` rather than hoping the skill loads. The `spec-driven-development` skill fires on
roughly 60% of relevant requests — skill matching is semantic, so it is a probability surface. An
invoked command is deterministic: you typed it, so it ran.

Then the loop:

| Step | Command | Produces |
| --- | --- | --- |
| a small, well-understood fix | `/speckit.quick` | a `specs/quick-log.md` entry (no artifacts) |
| principles (once) | `/speckit.constitution` | `.specify/memory/constitution.md` |
| what and why | `/speckit.specify` | `spec.md` |
| how | `/speckit.plan` | `plan.md` |
| ordered work | `/speckit.tasks` | `tasks.md` |
| execute | `/speckit.implement` | the code |
| close out | `/speckit.converge` | convergence report |

Gates when warranted: `/speckit.clarify` (before plan), `/speckit.analyze` (after tasks),
`/speckit.checklist` (after plan).

**Freebuff** doesn't read `.opencode/commands/`, so it can't invoke `/speckit.*`. The `AGENTS.md`
block lists the command paths so it reads each step's file directly. Same workflow, no slash
commands.

## Upgrading, and reversing

**Upgrade an existing project** — re-run the installer. It detects the installed preset and uses
`specify preset update` (the idiomatic remove+add flow), reporting the version change:

```bash
speckit-init ~/path/to/project
# :: preset up to date: spec-driven-development v1.3.0
# :: updated preset: spec-driven-development 1.2.0 -> 1.3.0
```

Because the preset is installed from a local directory (`--dev`), an upgrade picks up whatever is
in `preset/` at that moment. `git pull` this repo, then re-run `speckit-init` per project.

**Check what a project has** — `specify preset info spec-driven-development` reports the installed
version, so drift across projects is visible.

**Check whether a repo is current** — `speckit-check` reports drift against the kit, changing
nothing:

```bash
speckit-check ~/path/to/repo
speckit-check --all ~/Documents/GitHub    # every kit-managed project under a dir
```

Exits 0 = current, 1 = needs the update (re-run `speckit-init`), 2 = not a Spec Kit project.

**Reverse it** — `speckit-uninit` removes the scaffolding and nothing else:

```bash
speckit-uninit --dry-run ~/path/to/project   # show what would happen
speckit-uninit ~/path/to/project
```

It removes `.specify/`, the `speckit.*` command files, and the two managed blocks in `AGENTS.md`.
It **preserves your own `AGENTS.md` content** and **keeps `specs/`** (your work, not scaffolding —
pass `--remove-specs` to delete it too). Verified: on a repo with a pre-existing `AGENTS.md`,
uninit leaves `git status` clean.

## Versioning

The preset follows [Semantic Versioning](https://semver.org/); changes are recorded in
[`CHANGELOG.md`](CHANGELOG.md). The self-gate fails if the current preset version has no changelog
entry.

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
QUICKSTART.md                   paste-to-your-AI setup; one command, verified unattended
commands/speckit.md               the /speckit entry point (deterministic; the 100% path)
commands/speckit.quick.md         the fast lane (installer-copied; no spec/plan/tasks artifacts)
permissions/opencode-permission.jsonc  the mechanical boundary, merged into the project opencode.json
bin/speckit-init                  installer (idempotent; uses `preset update`)
bin/speckit-uninit                reverse it (preserves your own content)
bin/speckit-resume                compute the resume point from the ledger (the rule, made mechanical)
preset/                           spec-kit preset (append ×4, prepend ×5)
skill/spec-driven-development/    agent skill + references
global/working-agreements.md      global routing rules
global/autonomy-contract.md       the four-bucket handoff (installed to .opencode/)
evals/                            behaviour + trigger evals, a scenario harness, hang regression test
scripts/self-gate.sh              the kit's own gate
.github/workflows/self-gate.yml   runs that gate on Linux and macOS
CHANGELOG.md                      version history
BUILD_PLAN.md                     how this was built + the research behind it
```

## Testing

Two things can go wrong with a skill, so there are two kinds of test:

- **Behaviour** (`evals/skill-evals.json`) — does it give good guidance once loaded?
- **Triggering** (`evals/trigger-evals.json`) — does it load at all? A skill that doesn't
  load fails *silently*: no error, the agent just handles the task itself. This is the
  documented most-common failure mode, so trigger rate is the primary metric. The **≥90%** is
  Anthropic's *aspirational example benchmark*, not a requirement (see `evals/README.md`);
  **false triggers are the hard failure** — those are defects.

`scripts/self-gate.sh` validates the preset manifest, the skill frontmatter, both eval files,
and runs `speckit-init` end-to-end on a scratch repo — checking all four templates compose and
that a re-run is idempotent. CI runs it on **both** Linux bash 5 and macOS system bash 3.2,
because a construct that parses on one and not the other ships an installer that silently does
nothing for every Mac user.

See `evals/README.md` for the runners and how to record results.

### Checking it actually works — the scenario pass

`scripts/self-gate.sh` asserts the **deterministic** half on every push. Three judgement scenarios
from `specs/003-autonomous-throughput/quickstart.md` need a real agent, so they live in
`evals/run-scenario-evals.py` and run on demand:

```sh
python3 evals/run-scenario-evals.py          # live: the boundary, the fast lane, the budget halt
python3 evals/run-scenario-evals.py --fake   # scripted agent, no model — what the gate runs
```

The live pass **spends model calls**, so it is deliberately not in CI (that would need an API key in
the runner). It asserts what is **observable** — a file that must still exist, artifacts that must not
have been created, a run that must end — and never the model's own words, because a self-report is
weakest exactly where these scenarios live. `--fake` is the same harness against a scripted agent,
which is what `self-gate.sh` §1j runs on every push, with a negative control per scenario.


## Verification that reports what it examined

`./scripts/verify` is still the one command, but it now dispatches to `bin/speckit-verify` when the
project has a manifest at `.specify/verify.json` (seeded by `speckit-init`; skip with
`--no-manifest`). Without a manifest the generated command sequence runs as before, so an existing
project keeps working.

A check is evidence only when three things are true, and the engine refuses to count it otherwise:

1. it declares where its expected value comes from (`oracle`: `spec` / `fixture` / `declared`), and
   that is not inside the code under test;
2. its declared `control` — a command that must **fail** — actually fails;
3. it examined more than nothing. `pytest` exiting 5, jest's "No tests found", `cargo`'s
   "running 0 tests" and `go`'s "no test files" all mean *nothing ran*, and none of them is a pass.

| Command | What it is for |
| --- | --- |
| `bin/speckit-verify` | the engine: selection, adapters, controls, verdict, report, record |
| `bin/speckit-ledger` | `append` / `read` / `verify` over the append-only `.specify/ledger.jsonl` |
| `bin/speckit-security` | `observe` (records a baseline), `changed` (reports), `block` (confirmed-live only) |
| `evals/run-passk.py` | pass@1, empirical pass^k and the constant-p bound, side by side |

**Changed vs full.** With no flags the engine selects the checks a change can plausibly affect and
prints the selection. `--all` is the full-suite mode for a scheduled job. A changed file matched by
no check makes the run `INCOMPLETE` — the report never widens a scoped run into "all tests pass".
A change to a shared or configuration file (`conftest.py`, `pyproject.toml`, a lockfile, the manifest)
selects every check and says `fallback:`, because a glob cannot bound the effect of a file every test
reads.

**Exit codes.** `0` PASS · `1` FAIL · `2` usage or configuration error · `3` INCOMPLETE (zero
examined, a skip, a vacuous check, an unmatched file, or a record that could not be written).

**Mutation is opt-in.** `--mutation` runs a bounded operator-level pass over changed Python files and
lists *candidates* to review — a survivor is a question, not a verdict. `--extreme` mutates whole
methods at once; its output is labelled less precise and never replaces an operator-level run.

**Security is staged.** `observe` records per-rule counts and blocks nothing; `changed` reports
without blocking; `block` refuses without a baseline and without `--confirm`, and fails only on a
credential a provider confirmed live on a rule class that has a baseline. The confirmation tier
sends the candidate credential to the provider — that is what verification means, and it is why the
tier is explicit. A clean scan never satisfies the environment-only credential rule.
