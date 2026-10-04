# Quickstart: EARS Executable Specifications

**Feature**: `001-ears-executable-specs` | **Date**: 2026-10-04

Validation guide proving the feature works end-to-end. No implementation code here — procedures + expected outcomes only. Details live in `contracts/` and `data-model.md`.

## Prerequisites

- `specify` CLI on PATH (`uv tool install specify-cli`), `git`, `python3`, `bash`.
- This repo at the feature branch; methodology skill **unloaded/disabled** (SC-004 requires the trial to pass without it).
- Linux or macOS (SC-005 requires both; run the gate on each where possible).

## Scenario 1 — Preset composes with new sections (SC-005 core)

```bash
./scripts/self-gate.sh --no-e2e
specify preset resolve spec-template | grep -A2 -i "EARS"
specify preset resolve plan-template | grep -A2 "Correctness Properties"
specify preset resolve tasks-template | grep -Ai "property"
```

- **Expected**: self-gate `PASS`; each resolve shows `1. [base] core → 2. [append] spec-driven-development` and the new section text in append order (after core sections).

## Scenario 2 — Scratch-repo trial, skill unloaded (SC-004 + SC-001)

```bash
T="$(mktemp -d)" && git init -q "$T" && (cd "$T" && echo "# scratch" > README.md && git add -A && git -c user.email=e@e -c user.name=e commit -qm init)
./bin/speckit-init "$T"
cd "$T" && specify preset resolve spec-template > /tmp/spec-t.txt && specify preset resolve plan-template > /tmp/plan-t.txt && specify preset resolve tasks-template > /tmp/tasks-t.txt
# Author a trial spec with ≥8 requirements incl. ≥2 non-mappable (e.g., tone/UX), generate plan + tasks from the composed templates
```

- **Expected**: Generated spec requirements all in EARS form (reviewer converts 5 consecutive requirements into acceptance checks with zero author questions — SC-001); plan has a `for any …` property per testable requirement and explicit opt-out reasons for the ≥2 non-mappable ones (SC-002: 100% accounted for); every property has a PBT task naming the scratch project's framework/decision with zero hardcoded kit defaults (SC-003); all three artifacts produced with no skill loaded (SC-004).

## Scenario 3 — Full gate on both OSes (SC-005)

```bash
./scripts/self-gate.sh
# on the other OS (Linux ↔ macOS):
/bin/bash -n bin/speckit-init && ./scripts/self-gate.sh --no-e2e
```

- **Expected**: `SELF-GATE: PASS` on both; 4 markers exactly once; re-run fixed point (run2==run3, run1≈run2 whitespace-only); no marker duplication.

## Scenario 4 — Guardrails (FR-008 / FR-009 / FR-011 / lean)

```bash
# Zero hardcoded frameworks in kit-owned normative text (allowlisted negative example only):
grep -rniE "hypothesis|fast-check|proptest|quickcheck|gopter|rapid|swiftcheck|jqwik|kotest|fscheck|cscheck|rantly|streamdata" preset/templates/ | grep -v -i "do NOT hardcode\|never hardcoded\|negative example"
# Opt-out + traceability present:
grep -n -i "opt.out\|non-mapped\|Non-mapped reason" preset/templates/plan-addendum.md
grep -n "P-001\|Property ID" preset/templates/plan-addendum.md preset/templates/tasks-addendum.md
```

- **Expected**: First grep empty (SC-003); opt-out rule + `P-ID | FR` linkage present (FR-009/FR-011); `lean` documented as mutually exclusive (pick `lean` or this preset) — verifying under `lean` is explicitly out of scope.

## Pass criteria summary

| Criterion | Check |
| --- | --- |
| SC-001 | 5/5 sampled requirements convertible without clarification |
| SC-002 | 100% of trial requirements mapped XOR opted-out |
| SC-003 | Every property has a PBT task naming the project framework; zero kit-hardcoded names |
| SC-004 | Trial passes with skill unloaded |
| SC-005 | Gate passes Linux + macOS; append order correct; re-run idempotent, no marker duplication |
