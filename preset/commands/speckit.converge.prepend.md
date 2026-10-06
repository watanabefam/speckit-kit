<!--
  spec-driven-development preset — command contribution.
  Composed with strategy: "prepend" (after frontmatter, before the command's steps).
  Contract: adds rules only. Never removes, reorders, or overrides the core command.
-->

## Step rules

### Completion requires evidence

Do not report completion because the code compiles, a single test passes, the requested file
was edited, or the implementation appears correct.

Completion requires evidence against the **approved specification and its acceptance
criteria**. State what you ran and what it showed.

### A report that finds problems is the report working

Do not round up to green. A `Partial` or `Fail` row is not a failure of the convergence report
— it is the report doing its job. Surface deviations and decide on them rather than hiding
them behind an optimistic summary.

### Check the boundaries you declared

Verify the plan's **Must Not Change** items are actually unchanged — a diff against those files
is the evidence, not an assertion that you were careful.

### Review the parking lot

The spec's `Future Work (parking lot)` is a queue, not a graveyard. At close-out, walk it and give
every item one of three outcomes:

- **promote** — it is worth doing; it becomes its own spec
- **keep parked** — with a reason and a revisit condition
- **delete** — deliberately, because it is no longer wanted

An item that gets none of these has been silently abandoned, which is the failure mode the parking
lot exists to prevent. Report the count and what happened to each.

### Handoff discipline

Close with what changed, what remains open, what needs approval, what was verified and how, and
which downstream artifacts are affected. Do not discard earlier decisions silently: if a later
step invalidated one, say which and why.
