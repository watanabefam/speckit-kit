# Changelog

Notable changes to this kit. Format follows [Keep a Changelog](https://keepachangelog.com/);
versioning follows [Semantic Versioning](https://semver.org/).

The preset version lives in `preset/preset.yml` and is what `specify preset info` reports.

## [Unreleased]

## [1.3.0] — 2026-10-04

EARS requirements and correctness properties (feature 001).

### Added
- **EARS guidance** in `spec-addendum.md`: the five patterns (`THE <system> SHALL`, `WHEN`,
  `WHILE`, `WHERE`, `IF…THEN`), the `SHALL`-only / RFC 2119 rule, fixed clause order, common
  misuse, and a language-agnostic guard. Shapes verified against Mavin et al., RE'09.
- **Correctness Properties** section in `plan-addendum.md`: a `for any …` property table, the
  explicit opt-out rule, a framework-decision record, and a per-ecosystem *detection* table.
- **Property-test task rules** in `tasks-addendum.md`: one task per P-ID, both-ID tracing,
  co-location, fallback-following, a worked example, and a Property column in Requirement
  Coverage.
- Self-gate §3c: asserts the EARS shapes, the RFC 2119 and clause-order rules, the properties
  section, the task rules, and a **no-hardcode guard** for PBT framework names.

## [1.2.0] — 2026-10-04

Step rules moved into the commands.

### Added
- Command contributions (`strategy: "prepend"`) on `speckit.specify`, `speckit.plan`,
  `speckit.tasks`, `speckit.implement` and `speckit.converge`, carrying each step's enforceable
  rules. The skill fires on ~60% of relevant requests, so rules that must always apply cannot
  live behind a probabilistic trigger.
- Self-gate §3b: every command entry is a prepend, each contribution carries its rules, and none
  ships its own frontmatter.

### Changed
- The skill is now the *reasoning* layer and points at the commands as authoritative
  ("if the skill and a command disagree, the command wins") instead of restating the rules.

## [1.1.0] — 2026-10-04

Addendum reliability.

### Added
- Section-integrity prepends on `speckit.specify`, `speckit.plan` and `speckit.tasks`, so the
  appended template sections are not silently dropped. Before this, a generated `spec.md` had
  **0** appended sections; after, three consecutive artifacts carried all of theirs.

### Fixed
- `append` alone did not guarantee delivery: it depended on the agent resolving the composed
  template, which agents do inconsistently.

## [1.0.0] — 2026-09-30

First working version.

### Added
- Preset with `strategy: "append"` on the constitution, spec, plan and tasks templates.
- `spec-driven-development` skill (agentskills.io), discovered by both opencode and Freebuff
  from `~/.agents/skills/`.
- `global/working-agreements.md` routing file.
- `bin/speckit-init` installer.
- `scripts/self-gate.sh` + CI on Linux bash 5 and macOS system bash 3.2.
- Behaviour and trigger-accuracy evals.
