<!-- SPECKIT-BRIDGE START -->
# Spec-Driven Development (Spec Kit)

This project uses Spec Kit. Requirements are written down before code is written, and the
artifacts under `specs/` are the source of truth.

**Load the `spec-driven-development` skill before specifying, planning, or implementing.**
It carries the workflow, approval gates, traceability and verification rules.

## If you cannot invoke `/speckit.*` commands

Agents that do not read `.opencode/commands/` (e.g. Freebuff/Codebuff) can run each step by
reading the command prompt directly and following it as instructions:

| Step | File |
| --- | --- |
| constitution | `.opencode/commands/speckit.constitution.md` |
| specify | `.opencode/commands/speckit.specify.md` |
| plan | `.opencode/commands/speckit.plan.md` |
| tasks | `.opencode/commands/speckit.tasks.md` |
| implement | `.opencode/commands/speckit.implement.md` |
| converge | `.opencode/commands/speckit.converge.md` |
| clarify | `.opencode/commands/speckit.clarify.md` |
| analyze | `.opencode/commands/speckit.analyze.md` |
| checklist | `.opencode/commands/speckit.checklist.md` |

Substitute the user's feature description wherever the prompt expects `$ARGUMENTS`.
<!-- SPECKIT-BRIDGE END -->
<!-- SPECKIT START -->
For additional context about technologies to be used, project structure,
shell commands, and other important information, read the current plan
<!-- SPECKIT END -->
