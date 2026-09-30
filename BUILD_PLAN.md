# speckit-kit — Build Plan

**Status:** ✅ complete — all gates passed
**Last updated:** 2026-09-30

Reusable Spec Kit customization for opencode + Freebuff/Codebuff.

---

## Why this exists

Spec Kit (`specify` CLI) is per-project and ships minimal, generic templates. This repo
packages a reusable upgrade: a preset that appends missing template sections, a skill that
carries the SDD methodology via progressive disclosure, a global routing file, and an
installer.

## Decisions (LOCKED — do not re-litigate)

| # | Decision | Settled by |
| --- | --- | --- |
| D1 | Templates ship as a **preset** with `strategy: "append"` ×3 — not project-local overrides, not `replace` | spec-kit presets.md; `scripts/bash/common.sh:637-650`; `presets/scaffold/preset.yml`; `_manifest.py:29-30` |
| D2 | Methodology ships as a **skill** (progressive disclosure), not always-on context | Anthropic Agent Skills; arXiv 2606.15828 (>150-line adherence cliff); community "files vs skills" |
| D3 | Preset lives in `preset/`, installed with `specify preset add --dev` — not root-level + `--from` | `presets/_manager.py:398` (`copytree` copies whole dir); `:589-601` (archive root discovery) |
| D4 | **opencode AND Freebuff/Codebuff both read `~/.agents/skills/`** — one symlink serves both; identical agentskills.io format | opencode docs (global agent-compatible); freebuff `sdk/src/skills/load-skills.ts:118-131`; `common/src/constants/skills.ts`; `freebuff/SPEC.md:287` |
| D5 | Symlinks beat a remote URL — no network dependency, no silent-failure mode | opencode `session/instruction.ts:96` (no auth), `:100` (`return ""` on any error) |
| D6 | Install `agent-context` only by default; `bug`/`assess` opt-in | spec-kit EXTENSION-USER-GUIDE, "Minimal Extensions" |
| D7 | Repo is **private**; `--dev` needs no public URL | consequence of D3 + D5 |
| D8 | Principles ship as a **`constitution-template` append**, not a seeded `.specify/memory/constitution.md`. The seed flag was removed. | spec-kit `presets/ARCHITECTURE.md` "Constitution lifecycle"; `constitution-sync` README (materialization is an escape hatch; materialized edits "get shadowed or clobbered on the next recompose") |
| D9 | Keep the custom preset rather than adopting a community one, and document the alternatives | no community preset ships a skill; `specassay` requires a full durable-ID regime; `openup-governance` is the closest targeting |

### What D8 corrects

The first build shipped `constitution/principles.md` plus a `--seed-constitution` flag. Research
showed that is the **materialized-copy anti-pattern** the architecture doc warns about: init
seeds `constitution.md` once, and `/speckit.constitution` composes the live template at
runtime. A hand-placed file fights that. The principles now live in the preset, and the first
`/speckit.constitution` run applies them. `constitution/principles.md` was deleted so there is
one authoritative copy.

### What D9 corrects

A process failure: the catalog was never searched before designing. It holds ~40 community
presets, several overlapping this one (`specassay`, `openup-governance`, `workflow-preset`,
`explicit-task-dependencies`, `test-first-governance`). The build is still justified — none ship
a skill, and the agent wiring is unique — but the alternatives are now documented in the README.


### What D4 corrects

An earlier draft claimed Freebuff has no skill support, based on a `search/code` query
returning 0 hits. That API had already returned `ERR` on this repo in the same session, so
the null result was bad evidence. The repo tree proves skills exist. Lesson recorded here so
the correction isn't undone later.

## Content decomposition

The source doc is 1,348 lines. Only ~4 sections survive in any form; the rest either
duplicates core templates or is disproportionate.

| Source section | Destination | Rationale |
| --- | --- | --- |
| §5 principles | `preset/templates/constitution-addendum.md` → `constitution-template` (append) | concise, generic, high value. **Not** a seed file — see D8 |
| §7 spec template | `preset/templates/spec-addendum.md` | **~65% redundant** with core (`FR-001`, Given/When/Then, priorities, edge cases, assumptions, `SC-001` all already present) — shipped only Carried Forward, Problem, Goals, Non-Goals, Dependencies, MVP/Future, Validation Plan, Traceability |
| §9 plan template | `preset/templates/plan-addendum.md` | core plan template is sparse — most of §9 is genuinely new. **Highest value.** |
| §10 task template | `preset/templates/tasks-addendum.md` | core has `T00x`/deps/`[P]`/phases — added per-task requirement link, scope boundaries, verification |
| §4 + §20 rules | `global/working-agreements.md` | compressed to routing only (~25 lines) |
| §3 Layer 1 | `skill/.../SKILL.md` | the methodology, via progressive disclosure |
| §7–§11 rules | `skill/.../SKILL.md` | workflow selection, gates, handoff, scope, verification |
| §12 convergence | `skill/.../references/convergence.md` | |
| §14 existing project | `skill/.../references/existing-project.md` | |
| §16 + §17 | `skill/.../references/anti-patterns.md` | merged; largely redundant with §4/§20 |
| §1/§0/§8 phase mapping | — | already correct — that *is* spec-kit |

---

## Tasks

### Phase 1 — Repo scaffold
- [x] T001 `git init ~/Documents/GitHub/speckit-kit`
- [x] T002 `.gitignore` + `README.md`
- [x] T003 Write `BUILD_PLAN.md` (this file)
- [x] T004 Move `speckit-init` → `bin/`; symlink back so PATH still resolves

### Phase 2 — Preset  → gate G1
- [x] T005 `preset/preset.yml` — `schema_version: "1.0"`, quoted version strings, `strategy: "append"` ×3
- [x] T006 `preset/templates/plan-addendum.md` (§9)
- [x] T007 `preset/templates/tasks-addendum.md` (§10)
- [x] T008 `preset/templates/spec-addendum.md` (§7 subset)

### Phase 3 — Skill  → gate G4
- [x] T009 `skill/spec-driven-development/SKILL.md` (990 words, ~1.3k tokens)
- [x] T010 `skill/.../references/convergence.md` (§12)
- [x] T011 `skill/.../references/existing-project.md` (§14)
- [x] T012 `skill/.../references/anti-patterns.md` (§16+§17)

### Phase 4 — Global + installer
- [x] T013 `global/working-agreements.md` (25 lines, routing only)
- [x] T014 `constitution/principles.md` (§5)
- [x] T015 `bin/speckit-init`: `preset add --dev`, flags `--with-bug` / `--with-assess` / `--seed-constitution`, bridge trimmed 58 → 28 lines

### Phase 5 — Wiring
- [x] T016 Symlink skill → `~/.agents/skills/spec-driven-development`  **(serves opencode + Freebuff)**
- [x] T017 Symlink global → `~/.config/opencode/AGENTS.md`
- [x] T018 Symlink global → `~/.AGENTS.md`

### Phase 6 — Verify + commit  → gates G2,G3,G5,G6,G7,G8
- [x] T019 Verify gates (results below)
- [x] T020 `speckit-init` verified on a copy of a real repo (`audit-project`) and on `speckit-sandbox`
- [x] T021 Create private GitHub remote + push

### Phase 7 — Post-research corrections
- [x] T022 Add `constitution-template` append; delete `constitution/principles.md`
- [x] T023 Remove `--seed-constitution` from `speckit-init`
- [x] T024 Bound `speckit_version` to `">=1.0.0,<2.0.0"`
- [x] T025 Write three skill evaluations (`evals/`)
- [x] T026 Run evals 1 and 2 against a live agent
- [x] T027 Document community-preset alternatives in the README

---

## Verification gates — results

| Gate | Result | Evidence |
| --- | --- | --- |
| **G1** preset composes, not replaces | ✅ PASS | `preset resolve spec-template` → `1. [base] core` → `2. [append] spec-driven-development v1.0.0` |
| **G2** addenda land in generated artifacts | ✅ PASS | generated `spec.md` (213 lines): core sections to line 120, addendum from line 142 — correct append order |
| **G3** idempotent | ✅ PASS | 2 extra runs → AGENTS.md 32 lines, each marker exactly once, 11 commands, 1 preset |
| **G4** skill frontmatter valid | ✅ PASS | name regex OK, ≤64, matches dir; description 500 ≤1024; L2 ≈1.3k tokens |
| **G5** **trigger test** | ✅ PASS | `opencode run` → `→ Skill "spec-driven-development"`, correctly applied proportional process |
| **G6** integration status clean | ✅ PASS | `Integration status: OK`, 0 modified/missing managed files |
| **G7** no marker duplication | ✅ PASS | each of the 4 markers exactly once |
| **G8** both agents discover the skill | ⚠️ **opencode: PASS (executed)** · Freebuff: **source-verified only** | opencode `debug skill` lists it; Freebuff has no CLI to test — verified via `load-skills.ts:118-131` |
| **G9** all four templates compose | ✅ PASS | `preset resolve` shows an `[append]` layer for constitution/spec/plan/tasks; constitution template contains the principles |
| **G10** skill evals | ✅ 2 of 3 run · ✅ pass | eval 1 proportional-process PASS; eval 2 injection-resistance PASS (agent refused, cited the rule, deleted nothing); eval 3 unrun |

G8 is the only partial: Freebuff's discovery is proven from its loader source and the shared
path, not from execution, because Freebuff ships as a desktop app with no CLI.

---

## Run log

- **2026-09-30** — repo created, `git init`, `gh` auth confirmed (`watanabefam`).
- **2026-09-30** — researched and corrected D4 (Freebuff *does* support skills). One symlink
  now serves both agents instead of the opencode-only wiring originally planned.
- **2026-09-30** — real-repo test on a copy of `audit-project`: `.gitignore` unchanged, branch
  stayed `main`, existing `.opencode/` config untouched, 132-line `AGENTS.md` preserved.
  Found the bridge block was +64 lines → **trimmed to +28**.
- **2026-09-30** — found and repaired a stale pre-marker section in the sandbox `AGENTS.md`
  (hand-written before the markers existed, so it could not be auto-replaced). Applied the
  "repair the earliest artifact" rule to our own build.
- **2026-09-30** — all gates run; G5 confirmed by live agent invocation.
- **2026-09-30** — post-build research pass (Anthropic skill authoring best practices +
  spec-kit community catalog + spec-kit preset architecture).
  - Validated: SKILL.md 162 lines (<500), references all <100 lines so no TOC needed, references
    one level deep, description third-person with what+when. `append` mechanism confirmed by
    precedent — `specassay` v0.5.3 uses `type: template` + `strategy: append`.
  - Found and fixed **D8** (constitution was the materialized-copy anti-pattern).
  - Found and recorded **D9** (catalog was never searched before designing).
  - Found: 0 of 40 community presets ship a skill.
  - Added three evaluations and ran two live: eval 1 (proportional process) passed — the agent
    made no ceremony for a one-word fix and honestly reported the file didn't exist; eval 2
    (untrusted input) passed decisively — the agent detected the injection, refused it, cited
    the rule, and confirmed nothing was deleted.

---

## Known limitations

- **Pre-marker AGENTS.md content** cannot be auto-replaced. The installer is non-destructive:
  if a repo already has hand-written Spec Kit guidance *without* `SPECKIT-BRIDGE` markers, the
  script appends rather than replaces, which can duplicate. It backs up first. Marker-based
  content is always replaced in place.
- **Home-dir duplication edge case** — for projects directly under `~` with no `AGENTS.md` of
  their own, opencode's `findUp` can reach `~/.AGENTS.md` *and* load the global. Harmless at
  25 lines; not engineered around.

---

## Open items

- **O1** Which real repos to apply to (deferred — `speckit-init <path>` per repo)
- ~~**O2** Should `--seed-constitution` default on?~~ — **resolved:** the flag is gone; the
  principles are a `constitution-template` append (D8)
- **O3** Fate of this file: keep as build record, move to `docs/`, or delete
- **O4** Evals have not been run across model tiers (Anthropic's checklist asks for this). Eval
  3 is written but unrun.
