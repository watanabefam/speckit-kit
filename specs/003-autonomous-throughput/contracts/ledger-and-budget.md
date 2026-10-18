# Contract — Execution budget and ledger

**Consumers:** `/speckit.implement` (follows it), the agent (writes the ledger), the self-gate
(asserts the rule is present).
**Requirements:** FR-008, FR-009, FR-010.

## Continuous execution (FR-008)

The implement step executes the whole approved `tasks.md` without a per-phase confirmation. The
existing per-phase checkpoint and the checklist "proceed anyway?" prompt are removed from the happy
path; the decision is recorded in the ledger instead of asked.

## The execution budget (FR-009)

The stopping condition, stated in the implement prepend:

| Parameter | Default | Meaning |
| --- | --- | --- |
| `max_consecutive_failures` | 3 | halt after this many task failures in a row |
| `halt_on` | `budget`, `gate`, `missing_credential` | the only reasons to stop |

On halt: execution stops, the failing tasks are **left unticked** in `tasks.md`, and the reason is
recorded. A pass resets the consecutive-failure counter to 0. The budget is the design response to
compounding errors: autonomy needs ground truth each step and a stopping condition (research finding 3).

## Per-task commit and ledger line (FR-010)

On each task completion:

1. Commit for that task (on the feature branch; never `main`).
2. Append one ledger line to `specs/<NNN>-<slug>/progress.md`:

```
Task 3: complete (commits a1b2c3d..e4f5a6b — ./scripts/verify -> exit 0; new test for FR-004 passes)
```

On a failure that is retried:

```
Task 3: fix round 1/3 (verify still failing: assertion in tests/permission.test.sh:42; commits f3a2b1c..)
```

**Rules (unchanged from the existing implement prepend, now enforced by the budget):**

- A task is `DONE` **iff** it has a `complete` ledger line — the resume rule.
- A line without evidence is a claim, not a checkpoint.
- Never tick a box to make the list look finished.
- The ledger names its plan; a ledger naming a different plan is archived, never merged.

## Resume (P-005)

A run that loses context reads the ledger first, resumes at the first task without a `complete` line,
and re-verifies the named commits with `git log` before trusting them. A completed task is never
repeated.

## Interaction with the boundary

Continuous execution is safe only because the permission block (contract `permission-block.md`) refuses
irreversible actions at the tool layer. If the boundary is not installed, continuous execution should
not be relied on — the two ship together in US1+US3.

## Acceptance

1. A three-task plan completes with no per-phase confirmation.
2. A plan with a persistently failing task halts at the budget, leaves it unticked, records the reason.
3. Each completed task has a commit and a ledger line with evidence.
4. An interrupted run resumes without repeating a completed task (SC-006).
