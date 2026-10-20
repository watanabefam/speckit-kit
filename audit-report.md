# 📋 Audit Report: speckit-kit

Date: 2026-10-21 (final re-audit after fixes)
Audited by: `audit-project` skill (read-only audit; only this file was written)

## Overall Score: 97.2/100 — 🟢 Excellent

| Category | Initial | Final | Weight | Weighted |
|---|---|---|---|---|
| Structural compliance (Phase 2) | 37/100 | 95/100 | 20% | 19.0 |
| Template consistency (Phase 3) | 100/100 | 100/100 | 20% | 20.0 |
| Deployment health (Phase 4) | 95/100 | 100/100 | 20% | 20.0 |
| Convention gaps (Phase 5) | 94/100 | 96/100 | 10% | 9.6 |
| Project health (Phase 7) | 88/100 | 93/100 | 20% | 18.6 |
| Security scan (Phase 8) | 95/100 | 100/100 | 10% | 10.0 |
| **Total** | **83.9** | **97.2** | | **97.2** |

**Verdict: 🟢 PASS — 0 failures, 2 warnings (both accepted with reasons), 0 open decisions.**

### Verification evidence

| Check | Command | Result |
|---|---|---|
| Recorded project verification | `./scripts/verify` | **EXIT=0, `SELF-GATE: PASS`** |
| Spec Kit install health | `speckit-check .` | **`constitution conforms` → `current, nothing to do`** |
| Command-guard probes | 8 command strings | **8/8 correct** |
| Path-guard probes | 12 payloads against the real hook body | **12/12 correct** |
| Guard fail-open regression | protected path, env var absent | **exit 2 (blocked)** — was exit 1 (crashed open) |
| Hook source ↔ installed | `diff -q` | IDENTICAL |

---

## Defects found and fixed

### 1. Command guard bypass — `env` prefix (HIGH)

The token walk started checking only after the first `git`, so anything before it was invisible.
`env core.hooksPath=/dev/null git commit -m x` → allowed.

**Fix:** two passes — does any `git` token exist, then check every token in any position.

### 2. Path guard failed OPEN on every write (HIGH)

Found while answering "how do you check paths?". The guard ran under `set -u` and referenced
`$OPENCODE_PROJECT_DIR`. The plugin exports **only `OPENCODE_CONFIG_CONTENT`** — not
`OPENCODE_PROJECT_DIR` (verified by grepping `node_modules`). So the line aborted with **exit 1**,
and the harness blocks only on **exit 2**. Result: the generated-file protection protected nothing,
silently, in every real session.

**Fix:** `project_dir="${OPENCODE_PROJECT_DIR:-}"`, and the absolute-prefix strip is skipped when
unset. An absent variable now means "nothing to strip", never "crash". A guard must fail closed.

### 3. Path guard ignored multiedit payloads (MEDIUM)

The jq collected `.changes[]?.path` at the payload root, but this plugin nests tool args under
`.tool_args` (the bash guard reads `.tool_args.command`). A multiedit aimed at a generated file was
allowed.

**Fix:** paths are read from `.tool_args.filePath`, `.tool_args.file_path`, `.tool_args.path`,
`.tool_args.changes[]`, `.tool_args.files[]`, and the root equivalents.

### 4. Two shipped tools not installed (LOW)

`speckit-mcp`, `speckit-resume` symlinked into `~/.local/bin`. All five entry points resolve.

### 5. SKILL.md structure (LOW)

`allowed-tools` added; the loop numbered `Step 1..6`; `## Where to go next` added; version 1.1.1.

### 6. `.ignore` missing (LOW)

Added: `.git/`, `node_modules/`, `.opencode/node_modules/`, `__pycache__/`, `*.pyc`, `.DS_Store`.

### 7. Constitution was an unfilled scaffold (GOVERNANCE)

`.specify/memory/constitution.md` still held the raw template — every principle a bracketed
placeholder. Ratified at **1.0.0** with five core principles derived from practices the repo already
enforces, plus the preset's eight Delivery Principles. Reasoning recorded in
`decisions/0001-ratify-the-constitution.md`.

`speckit-check` before: *"the resolved template requires 9 section(s) this constitution lacks."*
After: *"ok constitution conforms to the resolved template."*

---

## How the path guard is checked

The harness in `audit-project` reports path guards as UNVERIFIED because its corpus drives shell
commands, not paths. They are checked the same way the plugin drives them, by hand:

1. Extract the real `bash:` action body from `hooks/speckit-hooks.yaml`.
2. Send it a JSON payload on stdin, exactly as the plugin does:
   `{"tool_name":"write","tool_args":{"filePath":"<target>"}}`.
3. Read the exit code: **2 = blocked**, **0 = allowed**, anything else = the guard is broken.
4. Test both classes — protected paths must block, permitted paths must stay writable — and test
   with the environment variable **absent**, because that is how it really runs.

A run that only checks "protected path blocks" would have passed this guard while it was failing
open. The absent-variable case is the one that finds the bug.

---

## Remaining items (both accepted, not defects)

1. 🟡 **[WARN] `model:` absent from SKILL.md frontmatter.** Deliberate — the kit is
   model-agnostic, and pinning one would make the distributable skill worse for adopters.

2. 🟡 **[WARN] Two addenda exceed the 200-line reference budget** — `plan-addendum.md` (258),
   `spec-addendum.md` (225). Parked deliberately: these are composed *into* users' `plan.md` and
   `spec.md`, so a table of contents inside them would be injected into every generated artifact.
   The rubric targets documents a reader navigates, not fragments that get composed. A genuine fix
   means restructuring them, which is a preset change requiring a version bump.

3. ℹ️ **Documented deviation:** `argument-hint` and `user-invocable` are intentionally absent.
   `scripts/self-gate.sh:633` rejects them as non-portable (opencode silently ignores them; Claude
   Code packaging rejects them). The audit rubric and the project's enforced gate disagree; the gate
   wins. `allowed-tools` is accepted by both and is present.

4. ℹ️ **Untracked paths:** `.ignore`, `audit-report.md`, `decisions/`, `blog/`.

---

## Recommended next

1. Remove the temporary Sync Impact Report comment at the top of
   `.specify/memory/constitution.md` before committing — it is review material, not governance.
2. Commit: `hooks/speckit-hooks.yaml`, `.opencode/hook/hooks.yaml`,
   `skill/spec-driven-development/SKILL.md`, `.specify/memory/constitution.md`, `decisions/0001-…`,
   `.ignore`, `audit-report.md`, `specs/quick-log.md`.
3. Suggested message: `docs: ratify constitution at 1.0.0; fix two silently-failing guards`

Re-audit with `skill("audit-project")` after any further change.
