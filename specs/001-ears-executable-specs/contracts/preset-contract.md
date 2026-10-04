# Contract: preset manifest + gate

## preset/preset.yml MUST keep

- `schema_version: "1.0"` (quoted), quoted `version:` and `requires.speckit_version: ">=1.0.0,<2.0.0"`.
- Exactly the 4 existing append targets (`constitution/spec/plan/tasks-template`), all `strategy: "append"` — no 5th entry, no `replace`, no core fork.
- Every `file:` exists on disk.

## scripts/self-gate.sh MUST assert (bash-3.2-safe)

- Existing assertions unchanged: 4-target shape, 4× `preset resolve` composition, 4 markers exactly once, 3-run fixed point.
- New content assertions: EARS rows (spec contract probes), Correctness Properties + `for any` + opt-out + framework-decision (plan probes), per-property task rule + P-ID + framework (tasks probes).
- Negative test: zero hardcoded PBT framework names in `preset/templates/` normative text (allowlist: the documented "do NOT hardcode" negative-example line only).
- Linkage spot-check: `P-` IDs referenced across plan/tasks addenda; opt-out wording present.

## Mirror-set (update together or the gate lies)

`preset/templates/*.md` + `preset.yml` + `.specify/presets/spec-driven-development/` (re-sync) + `self-gate.sh` (§3 + §5) + `README.md` + `BUILD_PLAN.md`.

## Known limitation (not a defect)

Under the `lean` preset all appends are inert (commands bypass template files). Documented in README/spec/plan/quickstart; never asserted in the gate.
