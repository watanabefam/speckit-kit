# Contract — Autonomy contract

**Consumers:** the agent (follows it at the end of every response), the installer (installs it once),
the self-gate (asserts exactly one exists and no command duplicates it).
**Requirements:** FR-004.

## Location

One file, installed to the target project as `.opencode/autonomy-contract.md`, and pointed at by
**one line** in the `SPECKIT-BRIDGE` block of `AGENTS.md`:

```markdown
**End every response with the four-bucket handoff** defined in `.opencode/autonomy-contract.md`.
```

The pointer is not the contract; the file is. No `/speckit.*` command carries equivalent prose (the
instruction budget is finite — research finding 5).

## The file (target shape, ~25 lines)

```markdown
# Autonomy contract

End every response with these four sections. Omit a section only when it is empty.

## Done
What changed, with the evidence that proves it. Not "the code compiles" — the command you ran and
what it showed.

## Continuing
Autonomous next actions you are taking now. Do not list reversible local work as a question; do it.
If there is nothing safe to continue, say so.

## Decision needed
A choice that needs the user, with **one** recommendation, its trade-off, and what is blocked until
it is made. Not a menu.

## Approval required
Actions not taken until explicitly approved — irreversible, external, costly, or destructive. State
the exact command, the target, the impact, and the rollback.

**Autonomous by default:** reading and editing project files in scope, running tests/linters/
formatters, fixing failures caused by your own changes, committing on the feature branch, updating
docs and tests.
**Never without approval:** deleting data or branches, force-pushing, publishing packages, running
destructive database commands, changing auth/secrets, deploying, spending money, or anything on the
project's deny list.
```

## Rules

- **Four buckets, fixed names.** Renaming them breaks the handoff's predictability.
- **Evidence, not assertion** in `Done` — consistent with the kit's existing "evidence before done"
  rule.
- **Approval is specific** — exact command, target, impact, rollback. This is the design response to
  automation bias: a gate must require evidence, not a yes/no (research finding 6).
- **One file.** If a second copy appears in a command, the gate fails (FR-004).

## Why a file, not command prose

The kit's per-command prompts are already 1.7k–3.0k words. Adding a ~25-line contract to each would
spend the instruction budget the research identifies as the binding constraint, and duplicate the same
text in five places that can drift apart.

## Acceptance

1. Exactly one `.opencode/autonomy-contract.md` is installed.
2. The bridge block contains exactly one pointer line.
3. No `preset/commands/*.prepend.md` contains the four bucket headings (gate assertion).
