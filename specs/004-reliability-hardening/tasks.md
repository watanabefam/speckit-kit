# Tasks — Reliability Hardening

Every task names its verification. Tick only with a `Task <N>: complete (<evidence>)` ledger line.

- [x] T001 Fix `skip()` recursion; add `SKIPPED` list, INCOMPLETE verdict, `--strict`. — Verify: `./scripts/self-gate.sh --strict`
- [x] T002 Replace `jq` with `python3` in all four hook bodies; fail closed on parse error. — Verify: gate §1f body probes
- [x] T003 Add gate probes: block / allow / malformed / no-`jq` for the bash guard; block / allow / malformed for the write guard. — Verify: gate §1f
- [x] T004 Additive permission merge for an existing `opencode.json`, with `.bak`; report an existing `permission` key. — Verify: gate §5 probe
- [x] T005 Fix the refresh message and the Commands-block wording. — Verify: gate §1d/§3b text assertions
- [x] T006 Extend `speckit-check`: contract, permission, `verify`, prepend marker. — Verify: gate §5 tamper probes
- [x] T007 Harden `speckit-resume` with ledger identity. — Verify: gate §5 mismatch probe
- [x] T008 Add a second-install idempotence probe (prepends + permission present). — Verify: gate §5
- [x] T009 Bump preset to 1.14.0 and add the CHANGELOG entry. — Verify: gate version assertion
- [x] T010 Run the full gate on this machine; fix every failure; record evidence in `progress.md`. — Verify: `./scripts/self-gate.sh --strict`
