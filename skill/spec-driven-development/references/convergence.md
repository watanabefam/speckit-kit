# Convergence Report

Used to close out a feature. Load when the work is implemented and needs to be reconciled
against the specification before calling it done.

Do not skip this because tests pass. Tests passing is one row of one table.

```markdown
# Convergence Report: [Feature]

## Artifact Status

- Specification reviewed: Yes / No
- Plan reviewed: Yes / No
- Tasks completed: Yes / No

## Requirement Verification

| Requirement | Acceptance Criteria | Evidence | Status |
| --- | --- | --- | --- |
| FR-001 | AC-001 | the test or review that proves it | Pass / Fail / Partial |

## Scope Review

- [ ] All MVP requirements are implemented.
- [ ] Non-goals were not unintentionally implemented.
- [ ] Future work was not included without approval.
- [ ] Scope changes are recorded.

## Edge Cases

- [ ] Expected edge cases were handled.
- [ ] Failure paths were tested.
- [ ] Error messages and responses are appropriate.
- [ ] Boundary conditions were checked.

## Regression Review

- [ ] Relevant existing tests pass.
- [ ] Existing behaviour remains compatible where required.
- [ ] New tests cover the changed behaviour.

## Quality Review

Mark each as reviewed or "not applicable — because …". Do not silently skip.

- [ ] Security
- [ ] Privacy
- [ ] Accessibility
- [ ] Performance
- [ ] Observability
- [ ] Documentation

## Deviations

### Planned but Changed

### Why

### Affected Artifacts

## Remaining Risks

## Final Decision

- Complete
- Complete with known limitations
- Requires changes

## What Changed / What Remains Open
```

## Rules

Do not report completion merely because:

- the code compiles
- a single test passes
- the requested file was edited
- the implementation appears correct

Completion requires evidence against the approved specification and its acceptance criteria.

A "Partial" or "Fail" row is not a failure of the report — it is the report working. Surface
it and decide, rather than rounding up.
