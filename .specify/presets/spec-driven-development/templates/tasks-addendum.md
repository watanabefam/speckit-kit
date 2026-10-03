---

<!--
  Appended by the spec-driven-development preset (strategy: append).
  The core task format above (phases, [P] markers, [Story] labels, checkpoints,
  dependency ordering) remains authoritative. This addendum adds the per-task detail
  block that makes each task traceable and independently verifiable.
-->

## Task Detail Block

The checkbox lines above give the plan. For any task that is not trivial, expand it using
this block. The point is that each task states **why it exists** and **how you will know it
is done** — not just what to edit.

```markdown
## T003: [Task Name]

- **Objective**: What this task achieves, in one line.
- **Addresses requirement(s)**: FR-004
- **Implements design decision(s)**: Where the design said this belongs.
- **Depends on**: T001, T002
- **Likely files**: Path or component, without guessing every file.
- **Scope boundaries**: What must NOT change while doing this.
- **Expected output**: Observable result.
- **Verification**: The exact command or check that proves it works.
- **Completion conditions**: What must be true to tick this off.
- **Risks / rollback**: What could go wrong, and how to undo it.
```

### Worked example

```markdown
## T003: Reject expired invitations during acceptance

- **Objective**: Reject expired invitations at acceptance time.
- **Addresses requirement(s)**: FR-004
- **Implements design decision(s)**: Validation happens in the service layer.
- **Depends on**: T001, T002
- **Likely files**: invitation service, invitation acceptance tests
- **Scope boundaries**:
  - Do not change the invitation expiry duration.
  - Do not alter email delivery.
- **Expected output**:
  - Expired invitations return the defined error.
  - Valid invitations continue to work.
- **Verification**: unit test for expired invitation; regression test for valid invitation.
- **Completion conditions**: tests pass; FR-004 acceptance criteria satisfied.
- **Risks / rollback**: Reversible by reverting the service-layer change; no migration.
```

## Task Rules

- Order tasks by dependency; keep them small enough to review in one pass.
- Put tests next to the behaviour they verify, not in a trailing phase.
- Every task traces to a requirement or an approved design decision.
- Do not create tasks for unapproved future work.
- Distinguish implementation, test, migration, documentation, and validation work.
- State the evidence that marks a task complete.
- Identify migrations and sequencing constraints explicitly.

## Requirement Coverage

A requirement with no task is unbuilt. A task with no requirement is scope creep. Check
before starting, not after.

| Requirement | Tasks | Covered? |
| --- | --- | --- |
| FR-001 | T002, T004 | ☐ |
| FR-002 | | ☐ |
