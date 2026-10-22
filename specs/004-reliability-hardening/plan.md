# Plan — Reliability Hardening

**Spec:** `spec.md` · **Tasks:** `tasks.md` · **Ledger:** `progress.md`

## Approach

Fix in dependency order: make the gate honest first (it is the oracle for everything else), then
close the two fail-open paths, then widen the checker and resume.

## Decisions

- **D1 — Remove `jq`; use `python3` in hook bodies.** `python3` is already required by the
  installer and `speckit-resume`. Removing a dependency is better than checking for it, and it
  removes the exact condition under which the guards silently stood aside.
- **D2 — Fail closed on unparseable payloads (exit 2).** The plugin always sends JSON; anything else
  is an unexpected shape. Allowing it is how a guard disappears when the payload shape changes.
- **D3 — Additive JSON merge only for `opencode.json`.** JSONC with comments cannot be round-tripped
  safely, so `.jsonc` keeps the print-only path and says why.
- **D4 — Skips are a third state.** The verdict becomes PASS / FAIL / INCOMPLETE; `--strict` turns
  INCOMPLETE into a non-zero exit for CI.
- **D5 — Behavioural probes, not string checks.** Extract each hook body from the YAML and execute it
  with real payloads, including a `PATH` with no `jq`.
- **D6 — Checker uses evidence already present.** It greps for the prepend marker in each composed
  command and for the permission/contract/verify artifacts, instead of trusting a version string.
- **D7 — Resume compares ledger identity.** Backward compatible: a ledger with no header still works.

## Risks

- **Hook latency.** Python startup adds ~40 ms per guarded call. Acceptable; the prefilter means it
  only runs for candidate commands.
- **False blocks on malformed payloads.** Deliberate: a guard that cannot read its input must not
  allow the action.
- **Policy change for skips.** CI that relied on skips exiting 0 now needs `--strict` to see them;
  the default keeps the old exit code but stops calling a skip a PASS.

## Verification

`./scripts/self-gate.sh --strict` and `make test`, plus the browser-free probes inside the gate.
