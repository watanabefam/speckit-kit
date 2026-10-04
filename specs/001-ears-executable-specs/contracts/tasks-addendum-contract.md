# Contract: tasks-addendum (property-test tasks)

Target: `preset/templates/tasks-addendum.md` (appended after core tasks-template).

## MUST contain

1. Task rule: **one property-based test task per correctness property**, each tracing `FR-ID + P-ID` and naming the plan-recorded framework (FR-007).
2. Co-location rule: property tests sit with their story's behaviour, not in a trailing phase.
3. Fallback rule: where the plan recorded adopt-vs-fallback, tasks follow that decision verbatim (FR-012-follow).
4. T003-style worked example showing Objective / Addresses requirement(s) / property link / framework / Verification / Completion conditions.
5. Requirement Coverage note extended to properties: every `P-ID` has a task; every PBT task traces to a `P-ID`.

## MUST NOT contain

- Concrete framework defaults; skill dependency (FR-008/FR-010 as above).

## Gate probes

```bash
grep -q -i "one property-based test.*per.*propert\|per correctness property" preset/templates/tasks-addendum.md
grep -q "P-ID\|P-001\|property ID" preset/templates/tasks-addendum.md
grep -q -i "framework" preset/templates/tasks-addendum.md
```
