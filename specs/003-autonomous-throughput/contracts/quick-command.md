# Contract — `/speckit.quick` (the fast lane)

**Consumers:** the user, the `/speckit` entry point (routes to it), the installer (copies it), the
self-gate (asserts it).
**Requirements:** FR-011, FR-012, FR-013.

## Why it is installer-copied, not a preset command

A Spec Kit preset cannot create a new command: a `type: "command"` entry naming a command that does not
exist is silently ignored (`bin/speckit-init:83`–`:85`). `/speckit.quick` therefore ships as
`commands/speckit.quick.md` and is **copied** into `.opencode/commands/`, exactly as `commands/speckit.md`
is.

## Routing (FR-011)

The `/speckit` entry point's routing table gains a row:

| If the work is | Run |
| --- | --- |
| small, well-understood, and reversible | `/speckit.quick` |

The classification already exists in `/speckit` §1 ("short path"). The fast lane makes that path a
command instead of improvisation.

## The command (target shape)

```markdown
---
description: Fast lane for small, well-understood work — no spec/plan/tasks artifacts.
---

# /speckit.quick — the fast lane

Use only when the change is small, well-understood, and reversible. If it is not, stop and run
`/speckit` to enter the full workflow.

1. **State the cause or the intent in two lines.** If you cannot, it is not fast-lane work.
2. **For a defect, write the failing test first.** It must fail for the stated reason before you
   touch the fix. (FR-012)
3. **Make the smallest change** that makes the test pass. No adjacent refactors, no "while I'm here".
4. **Run the recorded verification** (`./scripts/verify`, or the command in the `## Commands` block).
   State what you ran and what it showed.
5. **Append one entry** to `specs/quick-log.md`:

   ```
   ## 2026-10-17 — <one-line summary>
   Evidence: <command> -> <result>
   Parked: <anything noticed but not done, or "none">
   ```
6. **If the change grew** beyond a small, reversible edit — more than one component, a new dependency,
   a schema or contract change, or unclear behaviour — **stop and promote**: run `/speckit.specify`
   with what you have learned. Do not finish it here. (FR-013)

Do not create `spec.md`, `plan.md`, or `tasks.md`. The log entry is the only artifact.
```

## Boundaries

- **Promotion is mandatory on overrun.** The lane exists to be left when it stops fitting; completing a
  medium change silently through it is the failure mode the rule prevents.
- **No artifact inflation.** If a change needs a spec, it is not fast-lane work.
- **The log is append-only.** It is the traceability substitute for the artifacts the lane skips.

## Acceptance

1. A one-line fix runs through the lane with zero spec/plan/tasks artifacts and one log entry (SC-004).
2. A defect handled here has a failing test before the fix.
3. An overrunning change stops and promotes to `/speckit.specify`.
