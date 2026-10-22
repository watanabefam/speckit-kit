<!-- SPECKIT-BRIDGE START -->
# Spec-Driven Development (Spec Kit)

This project uses Spec Kit. Requirements are written down before code is written, and the
artifacts under `specs/` are the source of truth.

**First act of any session in this project: check the workflow before acting.** If the request
is software work, `spec-driven-development` applies — do not improvise from memory. Prefer
`.opencode/commands/speckit.md` (the `/speckit` entry point): it classifies the request, picks the
smallest workflow that fits, and routes. You are not exempt because the task looks simple.

**Load the `spec-driven-development` skill before specifying, planning, or implementing.**
It carries the workflow, approval gates, traceability and verification rules.

**The skill loads on roughly 60% of relevant requests — `/speckit` is the reliable path.** Invoke
it when you need the workflow to apply for certain.

**End every response with the four-bucket handoff** — Done (with evidence) · Continuing · Decision
needed · Approval required — defined in `.opencode/autonomy-contract.md`. Reversible, in-scope work
is autonomous; only the irreversible, external, or costly needs approval.

## Two rules that are enforced, not advised

`.opencode/hook/hooks.yaml` (requires the `opencode-yaml-hooks` plugin) runs below the prompt layer,
so unlike everything above it cannot be talked out of:

- **`git commit --no-verify` is blocked.** Do not try to skip the project's checks, and do not route
  around this with an equivalent — fix what the check is complaining about, or run the check
  directly to see the failure.
- **Generated files are not hand-edited.** `.opencode/commands/speckit*.md`, `.specify/scripts/`,
  `.specify/templates/` and `.specify/presets/` are regenerated and an edit there is lost. Change
  the kit instead. `.specify/memory/constitution.md` and `specs/` are yours to edit.

## If you cannot invoke `/speckit.*` commands

Agents that do not read `.opencode/commands/` (e.g. Freebuff/Codebuff) can run each step by
reading the command prompt directly and following it as instructions:

| Step | File |
| --- | --- |
| entry point | `.opencode/commands/speckit.md` |
| fast lane (small work) | `.opencode/commands/speckit.quick.md` |
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
at specs/003-autonomous-throughput/plan.md
<!-- SPECKIT END -->

<!-- SPECKIT-COMMANDS START -->
## Commands

Detected for this project by `speckit-init`. Run `./scripts/verify` for the checks this project records.

| Purpose | Command |
| --- | --- |
| install | unresolved — set by hand, or re-run `speckit-init` after adding a manifest |
| test | `make test` |
| lint | unresolved — set by hand, or re-run `speckit-init` after adding a manifest |
| typecheck | unresolved — set by hand, or re-run `speckit-init` after adding a manifest |
| build | unresolved — set by hand, or re-run `speckit-init` after adding a manifest |
| **verify** | `./scripts/verify` |
<!-- SPECKIT-COMMANDS END -->
