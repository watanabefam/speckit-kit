# Implementation Plan: EARS Executable Specifications

**Branch**: `001-ears-executable-specs` | **Date**: 2026-10-04 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/001-ears-executable-specs/spec.md`

## Summary

Add EARS-notation authoring guidance and property-based correctness properties to this kit so specifications become executable: EARS guidance goes into `preset/templates/spec-addendum.md` (all five patterns with syntax + examples), a `Correctness Properties` section (`for any …` mapping with explicit opt-out) goes into `preset/templates/plan-addendum.md`, and property-based test-task rules (one task per property, naming the per-project detected framework, never hardcoded) go into `preset/templates/tasks-addendum.md`. Delivery is `strategy: "append"` in place — no new preset entries, no core-template forks — extended with content assertions in `scripts/self-gate.sh`, and verified by the SC-004 skill-unloaded scratch-repo trial plus the SC-005 Linux/macOS gate.

## Technical Context

**Language/Version**: Markdown templates + Bash (3.2-compatible) installer + Python 3 gate scripts

**Primary Dependencies**: `specify-cli >=1.0.0,<2.0.0` (via `uv`), `git`, `python3`; no runtime dependencies added

**Storage**: N/A — files only (`preset/`, `skill/`, `bin/`, `scripts/`, `evals/`, `specs/`)

**Testing**: `scripts/self-gate.sh [--no-e2e]` (static manifest/frontmatter/eval checks + scratch-repo E2E: 4× `preset resolve` composition, marker-once, 3-run idempotency) + CI matrix Linux bash 5 / macOS bash 3.2; behaviour + trigger evals in `evals/` (runners not gate-run)

**Target Platform**: Linux + macOS (system bash 3.2.57 must parse everything)

**Project Type**: Developer tooling — Spec Kit preset (append strategy) + installer + agent skill

**Performance Goals**: `speckit-init` on a scratch repo < ~60s; `self-gate.sh --no-e2e` < ~30s; full gate < ~5 min

**Constraints**: `strategy: "append"` only (never replace); quoted version strings (`schema_version: "1.0"`, `speckit_version: ">=1.0.0,<2.0.0"`); bash 3.2-safe shell (no assoc arrays, `mapfile`, `wait -n`, `${var,,}`); installer idempotent (fixed point run2==run3, markers exactly once); templates language-agnostic (FR-008: zero hardcoded PBT framework names in kit text); appends must function with no skill loaded (FR-010); `lean` preset bypass is a documented limitation, not fixed

**Scale/Scope**: 4 existing append layers extended in place (~300 lines of template delta); 12 FRs, 5 SCs; mirror-set of ~6 files (preset.yml + 3 addenda + installed copy + self-gate + README/BUILD_PLAN docs)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

> Note: `.specify/memory/constitution.md` in this repo is the **unratified core placeholder** (all `[PRINCIPLE_N]` tokens, no project values). There are no enforceable gates to fail. The operative principles are the eight Delivery Principles in `preset/templates/constitution-addendum.md` (the pending constitutional content). Checked against those:

- [x] **I. Product Intent and Scope** — spec states problem (specs not executable), users (spec author / planner / implementer), MVP (US1+US2 EARS + properties), non-goals and `lean` out-of-scope. Plan Scope Confirmation mirrors it.
- [x] **II. Evidence Before Implementation** — Repository Findings (below) inspected preset, installer, gate, evals, core templates before proposing; research.md resolves EARS/PBT unknowns from sources, not assumptions.
- [x] **III. Explicit Assumptions** — carried in Carried Forward; spec Assumptions §1–6 preserved (append vehicle, 0-of-41 unverified, plan-time detection, fallback decision, lean bypass, ID conventions).
- [x] **IV. Verifiable Outcomes** — every FR is EARS-testable; SC-001..SC-005 are measurable with trial procedures in quickstart.md; no vacuous properties forced (FR-009 opt-out).
- [x] **V. Traceable Delivery** — FR → property (P-ID) → test-task chain extends existing FR → design → task traceability; Requirement-to-Design table below; tasks phase will enforce per-task FR/P-ID links.
- [x] **VI. Controlled Change** — Must-Not-Change list protects core templates, agent-context extension, `lean` behaviour, installer idempotency contract; version bump is patch/minor only.
- [x] **VII. Artifact Consistency** — plan repairs nothing in spec (spec passed checklist 2026-10-04 with zero NEEDS CLARIFICATION); any later contradiction goes back to spec first.
- [x] **VIII. Proportional Process** — template-kit change with 9:1 doc-to-code precedent (BUILD_PLAN F2); full plan warranted (new user-visible template behaviour ×3 artifacts + gate change + cross-OS verification). No new service, no dependency, no migration — no heavier process needed.

**Gate result: PASS** (no violations; nothing for Complexity Tracking).

*Post-Phase-1 re-check: PASS — design adds no new dependencies, no core-template forks, no hardcoded frameworks, no skill dependency; opt-out and fallback preserve IV/V; mirror-set update list preserves VI.*

## Project Structure

### Documentation (this feature)

```text
specs/001-ears-executable-specs/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
preset/
├── preset.yml                      # unchanged entry set (4 append targets); version bump only
└── templates/
    ├── spec-addendum.md            # += EARS authoring guidance (5 patterns + misuse note)
    ├── plan-addendum.md            # += Correctness Properties section + framework-decision record
    ├── tasks-addendum.md           # += property-test task rules + worked example
    └── constitution-addendum.md    # touch only if a 1-line principle needs it; else unchanged

scripts/
└── self-gate.sh                    # += content assertions (EARS / for-any / no-hardcode / opt-out)

bin/
└── speckit-init                    # unchanged (message text may mention new sections)

.specify/presets/spec-driven-development/  # committed installed copy, re-synced
evals/                               # unchanged runners; trigger/behaviour evals only if surface changes
README.md / BUILD_PLAN.md            # layout counts + limitation notes updated
```

**Structure Decision**: Single-repo preset kit — extend the four existing append files in place. No new template files, no new preset entries, no new top-level directories. This is the smallest diff that preserves the self-gate's `targets >= 4 + four exact names` assertion and `preset resolve` append ordering (SC-005).

## Complexity Tracking

> No constitution violations — table intentionally empty.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| — | — | — |

---

<!--
  Appended by the spec-driven-development preset (strategy: append).
  The core sections above (Summary, Technical Context, Constitution Check, Project
  Structure, Complexity Tracking) remain authoritative. These sections carry the
  design-phase reasoning the core template does not ask for.
-->

## Carried Forward

### Confirmed Decisions

- Delivery vehicle is `strategy: "append"` in `preset/preset.yml`; no core Spec Kit templates forked or replaced (spec Assumptions).
- EARS pattern set fixed at five (ubiquitous, event-driven, state-driven, unwanted-behaviour, optional-feature); SHALL-only normative verb per RFC 2119 (research R1).
- Properties live in the **plan** (`Correctness Properties`), not the spec — spec is behaviour authority, plan is verifiability bridge (US2/FR-006).
- No new preset entries/files; extend the 3 existing addenda in place (research R-d).
- Per-project PBT detection is a plan-time agent activity (2 greps); kit ships the instruction + signal table, not a registry (FR-008/FR-012).
- `lean` bypass is a documented limitation: pick `lean` or this preset, not both (spec edge case + assumption).

### Constraints

- `strategy: "append"` only; quoted versions; bash 3.2-safe; installer idempotent (markers once, run2==run3).
- Zero hardcoded PBT framework names in kit-owned template text (Hypothesis only as negative example); SC-003 enforces.
- Appends function with no skill loaded (FR-010 / SC-004) — template text must be self-contained.
- 100% requirements-accounted-for: every FR mapped XOR opted-out with one-line reason (FR-009 / SC-002).
- Requirement → property → test ID linkage preserved so unbuilt requirements and scope-creep tests are detectable (FR-011).

### Assumptions

- Community-catalog rationale (0 of 41 presets port EARS/PBT) taken from proposer, not re-verified; motivates but does not constrain.
- `specify-cli >=1.0.0,<2.0.0` append targets remain `spec/plan/tasks/constitution-template`.
- Agent can read manifest files (`package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml`, …) at plan time to detect the PBT framework.
- Projects with no PBT framework accept either adopting one or documented example-based fallback — decided per project in the plan, followed by tasks.
- Existing ID conventions hold (`FR-001`, `P-001`, `T00x`, `[P]`, phase organisation).

### Risks

- Template bloat: EARS + properties + PBT rules add ~100 lines across 3 addenda; authors may skip guidance → mitigated by compact tables + checklist probes, proportionality note (`lean` for small work).
- False-positive hardcode detection (framework name in negative example trips naive grep) → gate assertion scoped to kit-owned normative text with allowlisted negative-example line.
- Mirror-set drift (installed copy / gate / README stale) → Must-Change list + gate content checks + quickstart trial.

### Open Questions

- None blocking. Minor: whether `constitution-addendum.md` needs a one-line touch (e.g., verifiability wording) — decided in implementation; default is no change.

## Scope Confirmation

### In Scope

- EARS authoring guidance in `spec-addendum.md` covering all five patterns with syntax shape + ≥1 example each (FR-001..FR-005).
- `Correctness Properties` section in `plan-addendum.md` mapping each testable FR to ≥1 `for any …` property, with explicit opt-out + reason for non-mappable FRs (FR-006, FR-009, FR-012-record).
- Property-test task rules in `tasks-addendum.md`: one PBT task per property tracing FR-ID + P-ID and naming the plan-recorded framework (FR-007, FR-012-follow).
- Language-agnosticism guard: no concrete framework as default; per-project detection instruction (FR-008).
- Traceability preservation: requirement → property → test linkage (FR-011).
- Skill-independence: works with methodology skill unloaded (FR-010).
- Gate extension: content assertions for the above in `scripts/self-gate.sh`; re-synced installed copy; README/BUILD_PLAN doc updates.

### Out of Scope

- `lean` preset interaction fix — documented limitation, same as existing addenda (spec edge case 5).
- Machine-readable PBT registry YAML; auto-generated test code; EARS linter binary (checklist probes are human/review-compatible, optionally `speccheck`-style regex later).
- New preset entries, core-template forks, new dependencies, migrations.
- Re-verification of the 0-of-41 community-catalog claim.
- `constitution-addendum.md` principles rewrite (untouched unless a one-line touch proves necessary).

### Requirements Affected

- FR-001..FR-005 (EARS patterns) → `spec-addendum.md` guidance table.
- FR-006 (properties section) + FR-009 (opt-out) + FR-012 (framework decision record) → `plan-addendum.md`.
- FR-007 (PBT task per property) + FR-012 (follow decision) → `tasks-addendum.md`.
- FR-008 (no hardcoded framework) → all three addenda wording + gate negative test.
- FR-010 (append, skill-independent) → preset delivery + SC-004 trial.
- FR-011 (traceability) → property IDs + cross-artifact linkage + gate/contract checks.

## Repository Findings

### Relevant Components

- `preset/preset.yml` (47 lines): 4× `strategy: "append"` (constitution/spec/plan/tasks-template); `schema_version: "1.0"`, quoted versions, `speckit_version: ">=1.0.0,<2.0.0"`.
- `preset/templates/spec-addendum.md` (80 lines), `plan-addendum.md` (155 lines), `tasks-addendum.md` (70 lines), `constitution-addendum.md` (48 lines) — each `---` + append comment + `##` sections; zero EARS/`for any`/PBT text today.
- Committed installed copy `.specify/presets/spec-driven-development/` — identical today, must be re-synced.
- `bin/speckit-init` (229 lines): init + `preset remove/add --dev` + agent-context anchor + bridge markers + idempotent rewrite.
- `scripts/self-gate.sh` (190 lines, bash-3.2-safe) + `.github/workflows/self-gate.yml` (static matrix ubuntu+macos, E2E ubuntu-only on code changes).
- Core templates `.specify/templates/{spec,plan,tasks,constitution,checklist}-template.md` — upstream, do not fork; `checklist-template` intentionally untargeted.
- `evals/` (behaviour + 10/10 trigger evals; runners never gate-run), `specs/001-ears-executable-specs/{spec.md,checklists/requirements.md}` (109-line EARS spec, 12 FRs, checklist pass 2026-10-04).

### Existing Behavior

- `preset resolve <template>` layers `1. [base] core → 2. [append] spec-driven-development v1.0.0`; core authoritative, addenda additive (BUILD_PLAN G1/G9).
- Gate validates manifest shape, frontmatter, eval JSON shape, E2E composition (4 resolves), marker-once, 3-run AGENTS.md fixed point (run1≈run2 whitespace-insensitive, run2==run3 byte-identical). No addenda-body content assertions today.
- `lean` replaces core commands, bypassing template files — all appends inert under `lean` (README §§103–113, BUILD_PLAN F2). Inherited by new sections.

### Existing Tests

- Covered: installer parse (both bash), preset manifest shape, eval JSON parse/counts, E2E composition + markers + idempotency.
- Not covered (this feature adds): addenda-body content (EARS table, Correctness Properties, PBT rules), no-hardcode negative test, opt-out/traceability linkage, generated-artifact section presence. Evals runners and cross-model runs remain out of gate scope.

### Project Conventions

- Append style: `---`, append HTML comment, `##` sections with `[placeholder]` guidance; core untouched.
- Traceability: `FR-001`/`SC-001`/`T00x`+`[P]`+`[USn]`/`CHK001`, pipe tables; new `P-001` property IDs follow the same discipline.
- Bash 3.2 compat; quoted versions; skill-independence; language-agnosticism (concrete frameworks only as negative examples).

### Constraints Discovered

- **Mirror-set** (update together): `preset/preset.yml` + `preset/templates/*.md` + installed copy + `self-gate.sh` (§3 + §5 hardcode the 4 names) + `README.md` (×4 table/layout/testing) + `BUILD_PLAN.md` (D1 says ×3 — already stale). Missing one = green gate with broken composition or stale docs.
- **Do-not-touch**: core templates, `agent-context` extension internals (whitespace quirk tolerated), `lean` behaviour, `.specify/integrations/speckit.manifest.json` hashes (tooling-regenerated).
- `checklist-template` stays untargeted — EARS misuse detection belongs in `spec-addendum.md` guidance + `requirements.md` lifecycle, not a 5th preset entry.

## Architecture Overview

Extend three existing append files in place, following the established `---` + comment + `##` pattern. The spec addendum gains a compact 5-row EARS table (pattern | keyword | shape | use-when | example) plus ordering/complexity footnotes; the plan addendum gains a `Correctness Properties` table (`P-ID | FR | for-any statement | opt-out reason | notes`) plus a framework-decision record and the PBT signal table; the tasks addendum gains a one-rule-per-property task rule plus a T003-style worked example. A small set of `grep`-compatible content assertions in `self-gate.sh` locks the new sections and the no-hardcode guard. No new files in the preset, no schema change, no dependency — the smallest diff the gate can verify and SC-005 can compose.

## Major Components

- **EARS guidance block (`spec-addendum.md`)** — 5-pattern table with SHALL-only rule, generic `<system>`/`<trigger>` placeholders, complex-requirement footnote, misuse pointer to checklist. Serves FR-001..FR-005, FR-010.
- **Correctness Properties section (`plan-addendum.md`)** — `P-001…` table with `for any <domain>, <property>` statements, non-mapped rows with one-line reasons, framework-decision record (`detected / version / adopt-vs-fallback`), per-ecosystem signal table. Serves FR-006, FR-009, FR-012-record, FR-011-link.
- **Property-test task rules (`tasks-addendum.md`)** — "one PBT task per property" rule, FR-ID + P-ID tracing, plan-recorded framework naming, co-location (no trailing phase), fallback-following, T003-style example. Serves FR-007, FR-012-follow.
- **Gate content assertions (`scripts/self-gate.sh`)** — presence checks for the three sections, `for any` syntax spot-check, no-hardcode negative test (allowlisted example), opt-out/traceability linkage check. Serves SC-003/SC-005 regression protection.
- **Doc re-sync** — installed copy, README counts, BUILD_PLAN D1 correction, `requirements.md`-style EARS checklist item. Serves SC-005 idempotency/composition evidence.

## Data Flow

Spec author writes EARS requirements (spec-addendum guidance) → planner maps each testable FR to `for any …` properties or explicit opt-out and records the PBT framework decision (plan-addendum section + signal table) → task generator emits one PBT task per property naming the recorded framework (tasks-addendum rules) → implementer + gate verify: self-gate content assertions, scratch-repo trial (SC-004), SC-002 100%-accounted-for audit, SC-003 zero-hardcode grep.

## Interfaces and Contracts

- `preset/templates/spec-addendum.md` MUST contain: five EARS pattern rows with `SHALL` shapes + ≥1 example each; SHALL-only boilerplate (RFC 2119); complex-requirement footnote. See `contracts/spec-addendum-contract.md`.
- `preset/templates/plan-addendum.md` MUST contain: `## Correctness Properties` table with `Property ID | Requirement | for-any statement | Non-mapped reason | notes`; framework-decision record; signal table; opt-out rule. See `contracts/plan-addendum-contract.md`.
- `preset/templates/tasks-addendum.md` MUST contain: per-property PBT task rule with FR-ID + P-ID tracing + framework naming; co-location rule; fallback-following rule; worked example. See `contracts/tasks-addendum-contract.md`.
- `preset/preset.yml` MUST keep 4 append targets, quoted versions, `>=1.0.0,<2.0.0` bound. See `contracts/preset-contract.md`.
- `scripts/self-gate.sh` MUST assert the above (presence + no-hardcode + linkage) without breaking bash 3.2 parse or the existing 4-target/E2E/idempotency assertions.

## Dependencies

- None new. `specify-cli >=1.0.0,<2.0.0` (existing bound), `uv`, `python3`, `git` — all pre-existing. Explicitly no PBT library added to this repo (language-agnostic kit; frameworks are per-target-project decisions).

## Error Handling

- **Pattern misuse** (WHEN/state swap, missing SHALL, compound SHALLs): detectable at review via checklist probes in spec-addendum; Tier-1 structural faults block, Tier-2 vagueness is advisory (research R3).
- **Non-mappable requirement**: not an error — explicit opt-out row with reason; coverage audit counts mapped XOR opted-out as 100%.
- **No PBT framework in target project**: not an error — plan records adopt-vs-fallback decision; tasks follow it; gate does not require a framework present in this repo.
- **Hardcoded framework in kit text**: gate FAIL (negative test); fix by replacing with detection instruction + negative-example phrasing.
- **`lean` active**: expected no-op for all appends; quickstart documents the pick-one constraint; not reported as failure.
- **Mirror-set drift** (installed copy stale): caught by E2E `preset resolve` composition check on a scratch repo; fix by re-running installer sync.

## Security and Privacy

Not applicable — markdown template text + shell/Python gate checks; no credentials, no network calls, no user data, no auth/billing surface. Installer remains non-destructive (backup + marker-scoped rewrite).

## Performance and Reliability

Not performance-sensitive. Reliability is idempotency + composition: re-run reaches a fixed point (run2==run3), markers appear exactly once, all four templates resolve the append layer (SC-005). Gate runtime budget: static <30s, full <5min. Known limit: `lean` bypass (by design).

## Validation Strategy

- `scripts/self-gate.sh` (both bash 5 + 3.2) + full E2E on scratch repo: 4× `preset resolve` composition, new-section content greps, no-hardcode negative test, marker-once, 3-run fixed point.
- SC-004 trial: generate spec + plan + tasks on a scratch repo with the methodology skill unloaded; assert EARS requirements, Correctness Properties section, and property-test tasks all present.
- SC-002 audit: trial spec with ≥8 requirements incl. ≥2 non-mappable → 100% mapped XOR opted-out.
- SC-003 grep: zero hardcoded framework names in kit-owned template text (allowlisted negative example only).
- SC-001 spot check: 5 consecutive requirements convertible to acceptance checks without author clarification.
- Manual: `specify preset resolve` append order inspection; README/BUILD_PLAN/mirror-set review. See `quickstart.md`.

## Alternatives Considered

| Option | Advantages | Disadvantages | Decision |
| --- | --- | --- | --- |
| New `properties-addendum.md` + 5th preset entry | Clean separation of new content | Gate churn (targets/files lists), resolve-order risk, larger mirror-set; no spec requirement | Rejected |
| Fork/replace core templates | Full control of layout | Fork problem (hand-merge upstream forever); fails `append`-only gate; breaks installer model | Rejected |
| Hardcode per-language PBT defaults in templates | Shorter plan-time work | Violates FR-008, fails SC-003, version drift | Rejected |
| Machine-readable PBT registry YAML | Precise detection | Maintenance burden, drift; spec assumes instruction-only | Rejected |
| Properties in spec instead of plan | Single-artifact locality | Spec is behaviour authority; properties are design-phase bridge (US2/FR-006 place them in plan) | Rejected |
| Separate properties file | Avoids plan growth | Breaks append-only simplicity; harder to gate; weaker traceability | Rejected |
| One mega PBT task per feature | Fewer tasks | Loses per-property traceability (FR-011), unreviewable | Rejected |
| Hard lint-fail on all style points incl. vague words | Strictest | False positives on domain terms; reviewer fatigue | Rejected (Tier-1 block + Tier-2 advisory instead) |
| Full prose per EARS pattern (multi-example) | Most instructive | Bloats every spec; authors skip it | Rejected (compact table + footnote) |
| MUST-only or SHALL/MUST interchange | IETF familiarity | Breaks EARS recognisability + linter compatibility; doubles detection surface | Rejected (SHALL-only, RFC 2119) |

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
| --- | --- | --- | --- |
| Template bloat → authors skip guidance | Med | Med | Compact tables (~30-line EARS block); checklist probes; `lean` documented for small work |
| WHEN/WHILE/IF confusion persists | Med | Med | Use-when line per pattern row; Tier-1/Tier-2 checklist split; complex-example footnote |
| Vacuous forced properties for qualitative reqs | Low | High | FR-009 opt-out mandatory; coverage counts mapped XOR opted-out; gate checks reason present |
| Hardcoded framework slips into kit text | Low | High | Negative-test grep in gate with allowlisted example; review checklist item |
| Mirror-set drift (installed copy/gate/README stale) | Med | Med | Must-Change list; E2E composition check; quickstart mirror audit step |
| `lean` users expect appends to apply | Low | Low | Documented mutually-exclusive pick in README/spec/plan/quickstart; not a defect |
| Gate regex false positives (e.g., negative example) | Low | Med | Scope greps to normative text; allowlist the documented negative-example line |

## Requirement-to-Design Traceability

| Requirement | Design Decision | Reason |
| --- | --- | --- |
| FR-001 | EARS guidance table in `spec-addendum.md` (5 rows, shapes + examples) | Ubiquitous authoring guidance lives where requirements are written |
| FR-002 | Event-driven row: `WHEN <trigger> THE SYSTEM SHALL <response>` + WHEN-event probe | Triggered responses need the point-event form |
| FR-003 | State-driven row: `WHILE <state> THE SYSTEM SHALL <response>` + WHILE-state probe | Continuous-state responses need the state form |
| FR-004 | Unwanted-behaviour row: `IF <cond> THEN THE SYSTEM SHALL <mitigation>` + IF-for-faults probe + second-pass note | Fault coverage is the #1 omission source; reserved for 2nd pass |
| FR-005 | Optional-feature row: `WHERE <feature> THE SYSTEM SHALL <response>` + WHERE-as-variant probe | Variant-gating distinct from location/state |
| FR-006 | `Correctness Properties` table in `plan-addendum.md` (`P-ID \| FR \| for-any \| reason \| notes`) | Design-phase verifiability bridge; 1:many allowed |
| FR-007 | Per-property PBT task rule + worked example in `tasks-addendum.md` (FR-ID + P-ID + framework name) | Closes property→test loop with traceability |
| FR-008 | Detection-instruction + signal table; zero concrete defaults; gate negative test | Language-agnosticism; SC-003 enforcement |
| FR-009 | Opt-out rows (no P-ID, one-line reason); coverage = mapped XOR opted-out | No vacuous properties; SC-002 accounting |
| FR-010 | Append-only delivery; self-contained template text; SC-004 skill-unloaded trial | Works without the skill; no core forks |
| FR-011 | `P-001…` IDs extending FR→design→task traceability; gate linkage check | Unbuilt requirements / scope-creep tests detectable |
| FR-012 | Framework-decision record in plan (detected/version/adopt-vs-fallback); tasks follow it | Missing-framework projects supported without mandating a dep |

## Implementation Boundaries

### Must Change

- `preset/templates/spec-addendum.md` (EARS guidance block)
- `preset/templates/plan-addendum.md` (Correctness Properties + framework-decision + signal table)
- `preset/templates/tasks-addendum.md` (PBT task rules + example)
- `scripts/self-gate.sh` (content + no-hardcode + linkage assertions, bash-3.2-safe)
- `.specify/presets/spec-driven-development/` (re-sync installed copy)
- `README.md` + `BUILD_PLAN.md` (counts, layout, D1 ×3→×4 correction, limitation notes)
- New: `specs/001-ears-executable-specs/{research,data-model,quickstart}.md`, `contracts/`, and an EARS checklist item (checklists lifecycle)

### Must Not Change

- `.specify/templates/*.md` core templates (upstream; append only)
- `preset/preset.yml` entry set / schema / version bounds (patch/minor bump text only; no 5th target, no `replace`)
- `.specify/extensions/agent-context/*` internals (not ours)
- `lean` preset behaviour (documented limitation, not a defect)
- `.specify/integrations/speckit.manifest.json` hashes (tooling-regenerated)
- Installer idempotency contract (markers once, fixed point) and bash 3.2 compatibility
- Skill `SKILL.md` methodology layer (templates must not depend on it per FR-010)

## What Changed / What Remains Open

- **Changed from the spec:** Nothing material — spec passed its checklist with zero NEEDS CLARIFICATION; design resolves delivery shape (extend-in-place vs new files), SHALL-only rule, Tier-1/Tier-2 review split, and gate assertion scope, all within spec authority.
- **Still open:** Whether `constitution-addendum.md` needs a one-line touch — default no; decided at implementation.
- **Needs approval:** Plan approach (extend-in-place + gate assertions + skill-unloaded trial) before `/speckit.tasks`.
