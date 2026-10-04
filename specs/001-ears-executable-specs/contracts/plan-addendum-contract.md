# Contract: plan-addendum (Correctness Properties)

Target: `preset/templates/plan-addendum.md` (appended after core plan-template).

## MUST contain

1. `## Correctness Properties` section with table columns:
   `| Property ID | Requirement | for-any statement | Non-mapped reason | notes/design |`
   - Property IDs `P-001…`; 1:many per requirement allowed.
   - Rule: each testable requirement maps to ≥1 `for any <domain>, <property>` row (FR-006).
   - Rule: non-mappable requirements carry NO property, with a one-line reason (FR-009).
2. Framework-decision record fields: `detected framework / version / signal / decision (use-detected | adopt-<name> | example-based-fallback-with-reason)` (FR-012-record).
3. Per-ecosystem signal table (manifest → framework names to grep; see research R4) written as detection instruction, never as defaults (FR-008).
4. Traceability note: requirement → property → test linkage; unmapped-without-reason and tests-without-requirements are defects (FR-011).

## MUST NOT contain

- Concrete framework defaults; skill dependency (same FR-008/FR-010 rules as spec contract).

## Gate probes

```bash
grep -q "## Correctness Properties" preset/templates/plan-addendum.md
grep -q "for any" preset/templates/plan-addendum.md
grep -q -i "non-mapped\|opt-out\|opt out" preset/templates/plan-addendum.md
grep -q -i "framework.*decision\|detected framework" preset/templates/plan-addendum.md
```
