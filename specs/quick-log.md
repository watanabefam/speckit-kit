# Quick lane log

Fast-lane entries — small, well-understood, reversible work. No spec/plan/tasks artifacts.

## 2026-10-21 — audit findings: guard bypass, SKILL.md structure, missing tools, .ignore

Cause (two lines): the hook's token walk only inspected tokens *after* the first `git`, so
`env core.hooksPath=/dev/null git commit` escaped it. Separately, SKILL.md lacked a portable
`allowed-tools` field, numbered steps, and a handoff; `speckit-mcp` / `speckit-resume` were not
installed; no `.ignore` existed.

Change: two-pass awk predicate in `hooks/speckit-hooks.yaml` (synced to `.opencode/hook/hooks.yaml`);
`allowed-tools` added, loop numbered `Step 1..6`, `## Where to go next` added, version 1.1.1;
both tools symlinked into `~/.local/bin`; `.ignore` created.

Evidence: `./scripts/verify` -> `SELF-GATE: PASS` (exit 0). Guard predicate probed with 8 command
strings -> 8/8 correct (4 bypasses BLOCK, 4 benign ALLOW). `guard-behavior.py` -> 0 fail, 0 warn.
`speckit-check .` -> install current.

Parked: (1) `argument-hint` / `user-invocable` NOT added — `scripts/self-gate.sh:633` rejects them
as non-portable, so the audit rubric conflicts with the project's own gate; recorded as a
documented deviation. (2) TOC for `plan-addendum.md` (258 lines) / `spec-addendum.md` (225) —
those are composed into users' artifacts, so a TOC would be injected into every generated
plan/spec; needs restructuring, not a fast-lane edit. (3) Constitution amendment offering 9
sections — governance decision, not a defect.

## 2026-10-21 — path guard: fail-open crash and multiedit blind spot

Cause (two lines): the generated-file guard ran under `set -u` while reading `$OPENCODE_PROJECT_DIR`,
which the plugin never exports (it provides only `OPENCODE_CONFIG_CONTENT`) — so the line aborted with
exit 1, and only exit 2 blocks, meaning the guard protected nothing. Its jq also read `changes[]` at
the payload root, while this plugin nests tool args under `tool_args`.

Change: `project_dir="${OPENCODE_PROJECT_DIR:-}"` with the prefix-strip skipped when unset; path
collection now reads `tool_args.filePath|file_path|path`, `tool_args.changes[]`,
`tool_args.files[]` and the root equivalents. Synced to `.opencode/hook/hooks.yaml`.

Evidence: 12 payload probes against the real hook body -> 12/12 correct (6 protected BLOCK, 6
permitted ALLOW). Fail-open regression: protected path with the env var absent -> exit 2 (was exit 1).
`./scripts/verify` -> `SELF-GATE: PASS`. `diff -q` source vs installed -> IDENTICAL.

Parked: none.

## 2026-10-21 — constitution ratified at 1.0.0

Not a fast-lane change: it is a governance amendment, so it carries its own artifact
(`decisions/0001-ratify-the-constitution.md`) rather than only a log entry. `.specify/memory/
constitution.md` had never been filled in — it was still the raw scaffold with every placeholder.
Five core principles were derived from practices the repo already enforces; the preset's eight
Delivery Principles were kept verbatim.

Evidence: `speckit-check .` -> `ok constitution conforms to the resolved template` (before: nine
sections missing). `./scripts/verify` -> `SELF-GATE: PASS`.

Parked: the temporary Sync Impact Report comment at the top of the constitution is still present; it
must be removed before committing.

## 2026-10-21 — section-integrity check stops reporting phantom failures

Fast lane, one script plus its tests. `check-section-integrity.sh` compared heading strings
verbatim, so a spec that wrote `### Key Entities` was reported MISSING against the template's
`### Key Entities *(include if feature involves data)*`. The artifact was right; the checker was
wrong. Since a check that fires on conformant work gets ignored or deleted, this mattered.

Headings are now normalised before comparison — trailing whitespace, a trailing `⚠️`, a trailing
guidance parenthetical and a trailing italic note are stripped. Two further bugs surfaced while
testing and are fixed in the same file:

- **Repeated headings read as reordered.** `tasks-template` contains `### Worked example` twice. The
  inner search restarted from the top of the artifact for every requirement, so the second
  requirement matched the first occurrence, which sat behind the cursor. The template failed against
  itself. The search now takes the first occurrence strictly after the cursor, which still detects a
  genuine move (the heading exists, but not ahead of the cursor).
- **Order waivers matched the un-normalised name.** `## Requirements Syntax (EARS)` no longer
  exists as a string once normalised, so the waiver had to move to `## Requirements Syntax`.

Evidence: all three resolved templates now pass against themselves; `003/spec.md` went 2 missing -> 1
(the remainder is real: "which document wins" is prose, not a heading); `003/plan.md` conformant.
Controls still bite — dropping `## Success Criteria` and dropping `### Implementation for User Story 2`
both fail. `self-gate.sh` 3d now runs five cases including the two that would have caught the bugs
above (guidance note omitted -> accept; `OPTIONAL` section absent -> accept; resolved `tasks-template`
-> accept). `./scripts/verify` -> `SELF-GATE: PASS`, exit 0.

Same change closed a dead path: the generated `/speckit.plan` command tells the agent to run
`.specify/scripts/check-section-integrity.sh`, but nothing created it, so the command pointed at a
script that was not there. `speckit-init` now installs the script at that path (it takes the project
root as an argument, so it works from either location) and replaces a stale copy, since
`.specify/scripts/` is a generated tree. Gate coverage: a fresh install must ship it executable, a
re-run must leave it unchanged, and this repo's copy must match the source byte for byte.
