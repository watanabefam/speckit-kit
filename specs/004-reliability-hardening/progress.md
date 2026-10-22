# Progress — plan: specs/004-reliability-hardening/plan.md

Ledger for `specs/004-reliability-hardening`. One line per task, evidence in parentheses.
`bin/speckit-resume` reads the plan identity from the first line and the tasks from here.

Task 1: complete (`skip()` no longer self-calls; gate §0 green; no-specify run: `SELF-GATE: INCOMPLETE`, exit 1, skip named)
Task 2: complete (all four hook bodies use python3; malformed payload exits 2; no `jq` in any body)
Task 3: complete (gate §1f: block 2/2, allow 2/2, malformed 2/2, no-jq 1/1 — "guard bodies block 2/2…")
Task 4: complete (brownfield fixture: permission added, plugin/theme preserved, `.bak` written; existing `permission` left unchanged)
Task 5: complete (refresh message is truthful; Commands block wording updated; `AGENTS.md` diff is one line)
Task 6: complete (checker §4b/4c; tamper probes: contract, permission, prepend, verify all exit 1; integration status parsed)
Task 7: complete (resume oracle: wrong-plan ledger exit 2 with no `RESUME`; matching header still resumes)
Task 8: complete (second install byte-identical; older kit `hooks.yaml` upgraded; gate green)
Task 9: complete (preset 1.14.0; CHANGELOG entry is the newest release; gate §1c green)
Task 10: complete (`./scripts/self-gate.sh --strict` → `SELF-GATE: PASS`, exit 0; `make test` exit 0; `speckit-check .` → current)
