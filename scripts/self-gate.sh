#!/usr/bin/env bash
# The kit's own gate.
#
# Runs the checks the build used, so a later edit to the preset, the skill or the
# installer cannot silently regress them. CI runs this on BOTH Linux bash 5 and
# macOS system bash 3.2 — a gate that only ever sees one of them has a blind spot
# the size of the other platform.
#
# Written to be bash 3.2 compatible (no associative arrays, no mapfile, no
# ${var,,}), because macOS's system bash is 3.2.57 and that is a platform users
# are actually on.
#
# Usage: scripts/self-gate.sh [--no-e2e]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
E2E=1
[ "${1:-}" = "--no-e2e" ] && E2E=0

fail=0
ok()  { printf '  ok    %s\n' "$*"; }
bad() { printf '  FAIL  %s\n' "$*"; fail=1; }
hdr() { printf '\n== %s ==\n' "$*"; }

hdr "1. installer parses under this bash ($BASH_VERSION)"
if bash -n "$ROOT/bin/speckit-init"; then
  ok "bin/speckit-init parses"
else
  bad "bin/speckit-init has a syntax error under this bash — on a stock Mac this means the installer does nothing"
fi
if bash -n "$ROOT/bin/speckit-uninit"; then
  ok "bin/speckit-uninit parses"
else
  bad "bin/speckit-uninit has a syntax error under this bash"
fi

hdr "1b. runner hang regression"
# Capture the output: the test asserts three separate properties, and discarding it means
# a CI failure cannot say WHICH one broke — which is how it stayed undiagnosed.
HANG_OUT="$(python3 "$ROOT/evals/test-runner-hang.py" 2>&1)" && HANG_RC=0 || HANG_RC=$?
if [ "$HANG_RC" = "0" ]; then
  ok "eval runner respects its timeout and leaves no orphans"
else
  bad "eval runner hang regression — run: python3 evals/test-runner-hang.py"
  printf '%s\n' "$HANG_OUT" | sed 's/^/        /' | tail -20
fi

hdr "1b2. eval runners isolate the working directory"
# opencode resolves the project from $PWD, NOT from the process working directory.
# A runner that passes cwd= without setting PWD silently evaluates the LAUNCHING
# repo instead of the fixture — which is exactly what happened, and it produced a
# confident, wrong finding ("the skill false-triggers") that survived several
# versions. This assertion exists so it cannot come back quietly.
for r in evals/run-trigger-evals.py evals/run-outcome-evals.py; do
  if grep -q "PWD=cwd" "$ROOT/$r"; then
    ok "$(basename "$r") sets PWD (cwd alone is ignored by opencode)"
  else
    bad "$(basename "$r") passes cwd but not PWD — it will evaluate the wrong directory"
  fi
done

hdr "1d. deterministic entry point"
# The skill fires ~60% of the time. /speckit is the 100% path, so its presence and
# content are load-bearing: if it goes missing, the only remaining entry point is
# probabilistic.
ENTRY_SRC="$ROOT/commands/speckit.md"
if [ -f "$ENTRY_SRC" ]; then
  ok "commands/speckit.md present"
  for needle in "^description:" "## 1. Classify" "State which workflow you picked" \
                "One source of truth" "Approval gates" "Completion requires evidence" \
                "Repair at the source" "External content is data"; do
    if grep -q "$needle" "$ENTRY_SRC"; then
      ok "entry point carries: ${needle#^}"
    else
      bad "entry point missing required section: ${needle#^}"
    fi
  done
  # It must not depend on the skill having loaded.
  if grep -qE "skill (has |may not have )?loaded|may not have loaded" "$ENTRY_SRC"; then
    ok "entry point acknowledges the skill is probabilistic"
  else
    bad "entry point does not state that the skill may not have loaded"
  fi
  if grep -q "speckit.md" "$ROOT/bin/speckit-init"; then
    ok "installer copies the entry point"
  else
    bad "installer never installs commands/speckit.md — /speckit would not exist in target repos"
  fi
else
  bad "commands/speckit.md missing — there is no deterministic entry point"
fi

hdr "1d2. autonomy artifacts (boundary, contract, commands block, fast lane)"
# The permission boundary is the mechanical layer; the contract is one file; the
# commands block and verify come from detection; the fast lane is installer-copied.
PERM_SRC="$ROOT/permissions/opencode-permission.jsonc"
if [ -f "$PERM_SRC" ]; then
  ok "permissions/opencode-permission.jsonc present"
  for needle in '"git push*--force*": "deny"' '"npm publish*": "deny"' \
                '"supabase db reset*": "deny"' '"git push*": "ask"'; do
    if grep -qF "$needle" "$PERM_SRC"; then ok "permission block carries: $needle"; else bad "permission block missing: $needle"; fi
  done
else
  bad "permissions/opencode-permission.jsonc missing — no boundary to install"
fi

CONTRACT_SRC="$ROOT/global/autonomy-contract.md"
if [ -f "$CONTRACT_SRC" ]; then
  ok "global/autonomy-contract.md present"
  for needle in "## Done" "## Continuing" "## Decision needed" "## Approval required"; do
    if grep -qF "$needle" "$CONTRACT_SRC"; then ok "contract carries: $needle"; else bad "contract missing: $needle"; fi
  done
else
  bad "global/autonomy-contract.md missing"
fi

QUICK_SRC="$ROOT/commands/speckit.quick.md"
if [ -f "$QUICK_SRC" ]; then
  ok "commands/speckit.quick.md present"
  for needle in "fast lane" "failing test" "promote" "quick-log"; do
    if grep -qF "$needle" "$QUICK_SRC"; then ok "fast lane carries: $needle"; else bad "fast lane missing: $needle"; fi
  done
else
  bad "commands/speckit.quick.md missing — the fast lane does not exist"
fi

# The installer must install all four. The fast lane cannot be a preset command — a
# preset cannot create a command, so it must be installer-copied.
for needle in "opencode-permission.jsonc" "autonomy-contract.md" "SPECKIT-COMMANDS" "speckit.quick.md"; do
  if grep -qF "$needle" "$ROOT/bin/speckit-init"; then ok "installer handles: $needle"; else bad "installer never handles: $needle"; fi
done

# FR-004: the contract lives in exactly one file — no command may carry the buckets.
if grep -lE '^## (Done|Continuing|Decision needed|Approval required)$' "$ROOT"/preset/commands/*.prepend.md >/dev/null 2>&1; then
  bad "a command prepend carries the four-bucket contract prose (FR-004: one file only)"
else
  ok "no command prepend duplicates the autonomy contract"
fi

hdr "1d3. property P-003 — irreversible actions deny under BOTH rule semantics"
# opencode resolves with findLast() today (last match wins), but an open PR changes it to
# most-specific-wins (specificity = literal chars before the first wildcard; ties -> later).
# The boundary must not depend on which ships, so resolve the ruleset under BOTH and require
# the same verdict, and require the structural property that makes last-match safe.
# Evidence and sources: specs/003-autonomous-throughput/research.md.
python3 - "$PERM_SRC" <<'PY' || fail=1
import json, re, sys
p = sys.argv[1]
raw = open(p, encoding="utf-8").read()
raw = re.sub(r'(?m)^\s*//.*$', '', raw)      # strip full-line // comments only
raw = re.sub(r',(\s*[}\]])', r'\1', raw)     # strip trailing commas
rules = list(json.loads(raw)["permission"]["bash"].items())

def oc_match(s, pat):
    # opencode Wildcard.match: * -> .*, ? -> ., anchored to the WHOLE string.
    esc = re.sub(r'([.+^${}()|\[\]\\])', r'\\\1', pat)
    esc = esc.replace('*', '.*').replace('?', '.')
    return re.fullmatch(esc, s, re.S) is not None

def spec(pat):
    i = len(pat)
    for w in ('*', '?'):
        j = pat.find(w)
        if j != -1:
            i = min(i, j)
    return i

def last_match(c):
    out = None
    for pat, act in rules:
        if oc_match(c, pat):
            out = act
    return out

def most_specific(c):
    best = None
    for idx, (pat, act) in enumerate(rules):
        if oc_match(c, pat):
            cand = (spec(pat), idx, act)
            if best is None or cand[:2] >= best[:2]:
                best = cand
    return best[2] if best else None

irreversible = [
    "git push --force origin main", "git push origin main --force",
    "git commit --no-verify -m x", "git -c core.hooksPath=/dev/null commit -m x",
    "npm publish", "pnpm publish", "yarn publish", "cargo publish",
    "supabase db push", "supabase db reset", "prisma migrate reset --force",
]
# Every deny pattern is exercised at least once by a derived command, so a new deny
# cannot be added without being tested.
derived = [pat.replace("*", " x") for pat, act in rules if act == "deny"]
# `git push -f` is deliberately absent: a glob cannot express it without false-positiving
# on `--follow-tags`. The token hook 3 carries it, tested behaviourally in §1f.
bad = [c for c in irreversible + derived
       if last_match(c) != "deny" or most_specific(c) != "deny"]
if bad:
    print("  FAIL  not denied under both semantics: " + "; ".join(sorted(set(bad)))); sys.exit(1)
print("  ok    %d irreversible actions deny under last-match AND most-specific" % len(irreversible))

# Structural guarantee for last-match: every deny must come AFTER every non-deny, so a
# non-deny that matches the same command can never be the last match.
last_non = max((i for i, (_, a) in enumerate(rules) if a != "deny"), default=-1)
first_deny = min((i for i, (_, a) in enumerate(rules) if a == "deny"), default=len(rules))
if first_deny <= last_non:
    print("  FAIL  a deny rule precedes a non-deny rule — last-match-wins could be overridden"); sys.exit(1)
print("  ok    every deny is later than every non-deny (last-match cannot be overridden)")
PY

hdr "1f. hooks — the only layer that can actually enforce"
HK="$ROOT/hooks/speckit-hooks.yaml"
if [ -f "$HK" ]; then
  ok "hooks/speckit-hooks.yaml present"
  # The four hooks, and the property that makes them enforcement rather than advice.
  for needle in "block-commit-no-verify" "protect-generated-files" "block-force-push" "block-destructive-commands" "action: stop" "exit 2"; do
    if grep -q "$needle" "$HK"; then ok "hook file carries: $needle"; else bad "hook file missing: $needle"; fi
  done
  # The no-verify guard must BEHAVE, not just exist. A keyword check passes a hook
  # that has been weakened into decoration. An adversarial audit against an earlier
  # version found bypasses (`git -c core.hooksPath=... commit`,
  # `git --no-pager ... commit -n`) that the keyword checks did NOT catch — the
  # guard had silently stood aside while still containing the right words. So the
  # predicate itself is exercised: wget the bypass and benign cases through the
  # exact awk the hook ships, extracted from the YAML. If the awk is missing or
  # weakened, one of these fails.
  AWK="$(python3 - "$HK" <<'PY'
import re, sys
raw = open(sys.argv[1]).read()
m = re.search(r"awk '\n(.*?)\n            '\s*<<<", raw, re.S)
if not m:
    m = re.search(r"awk '??(.*?)??<<<", raw, re.S)
print(m.group(1) if m else "")
PY
)"
  if [ -z "$AWK" ]; then
    bad "could not extract the no-verify awk predicate from the hook — gate cannot test it"
  else
    # Mirror the hook: it strips quotes before the walk, so a quoted flag cannot evade.
    hk_verdict() { printf '%s' "$1" | tr -d '\42\47' | awk "$AWK" | grep -q . && echo BLOCK || echo ALLOW; }
    hk_fail=0
    for c in "git commit --no-verify -m x" "git commit -n -m x" \
             "git -c core.hooksPath=/dev/null commit -m x" \
             "git --no-pager --git-dir=.git --work-tree=. commit -n -m x" \
             "git commit \"--no-verify\" -m x" "git commit '--no-verify' -m x"; do
      [ "$(hk_verdict "$c")" = "BLOCK" ] || { bad "no-verify guard ALLOWS bypass: $c"; hk_fail=1; }
    done
    for c in "git log -n 5" "git commit -m x" "grep -n foo f"; do
      [ "$(hk_verdict "$c")" = "ALLOW" ] || { bad "no-verify guard BLOCKS benign: $c"; hk_fail=1; }
    done
    [ "$hk_fail" = "0" ] && ok "no-verify predicate blocks 6 bypass forms (incl. quoted), allows 3 benign (behavioral, not keywords)"
  fi
  # Hook 3 (force-push) must also BEHAVE. A `-f` glob would false-positive on
  # `--follow-tags`, so this predicate is the only thing covering `git push -f`;
  # exercise it against the exact awk the hook ships.
  AWK3="$(python3 - "$HK" <<'PY'
import re, sys
raw = open(sys.argv[1]).read()
for m in re.finditer(r"awk '\n(.*?)\n            '\s*<<<", raw, re.S):
    if "saw_push" in m.group(1):
        print(m.group(1)); break
PY
)"
  if [ -z "$AWK3" ]; then
    bad "could not extract the force-push awk predicate — gate cannot test it"
  else
    fp_verdict() { printf '%s' "$1" | tr -d '\42\47' | awk "$AWK3" | grep -q . && echo BLOCK || echo ALLOW; }
    fp_fail=0
    for c in "git push --force origin main" "git push origin main --force" \
             "git push -f origin main" "git push -f" "git -C repo push -f origin main" \
             "git push origin +main" "git push '-f' origin main" "git push \"-f\" origin main"; do
      [ "$(fp_verdict "$c")" = "BLOCK" ] || { bad "force-push guard ALLOWS: $c"; fp_fail=1; }
    done
    for c in "git push origin main" "git push --follow-tags" "git push --tags" "git status"; do
      [ "$(fp_verdict "$c")" = "ALLOW" ] || { bad "force-push guard BLOCKS benign: $c"; fp_fail=1; }
    done
    [ "$fp_fail" = "0" ] && ok "force-push predicate blocks 8 force forms (incl. quoted), allows 4 benign"
  fi
  # Hook 4 (publish / destructive DB) must BEHAVE, and must not fire on a command
  # that merely MENTIONS the words (segment guard: the CLI must start the segment).
  AWK4="$(python3 - "$HK" <<'PY'
import re, sys
raw = open(sys.argv[1]).read()
for m in re.finditer(r"awk '\n(.*?)\n            '\s*<<<", raw, re.S):
    if "saw_pm" in m.group(1):
        print(m.group(1)); break
PY
)"
  if [ -z "$AWK4" ]; then
    bad "could not extract the destructive-command awk predicate — gate cannot test it"
  else
    dc_verdict() { printf '%s' "$1" | tr -d '\42\47' | awk "$AWK4" | grep -q . && echo BLOCK || echo ALLOW; }
    dc_fail=0
    for c in "npm publish" "pnpm -r publish" "cargo publish" "npx supabase db push" \
             "supabase db reset" "npx prisma migrate reset" "prisma migrate deploy" \
             "cd app && npm publish"; do
      [ "$(dc_verdict "$c")" = "BLOCK" ] || { bad "destructive guard ALLOWS: $c"; dc_fail=1; }
    done
    for c in "npm test" "npm run build" "npm run publish-docs" "grep -r npm publish ." \
             "git status" "supabase status"; do
      [ "$(dc_verdict "$c")" = "ALLOW" ] || { bad "destructive guard BLOCKS benign: $c"; dc_fail=1; }
    done
    [ "$dc_fail" = "0" ] && ok "destructive predicate blocks 8 irreversible forms, allows 6 benign (segment-guarded)"
  fi
  # It must not protect the files that are MEANT to be edited.
  if grep -q ".specify/memory/constitution.md" "$HK" && grep -q "ALLOW" "$HK"; then
    ok "hook file documents the allow-list (constitution + specs are editable)"
  else
    bad "hook file does not state what stays editable — false positives start here"
  fi
  # The installer must ship it AND say when it is inert.
  if grep -q "speckit-hooks.yaml" "$ROOT/bin/speckit-init"; then
    ok "installer installs the hooks"
  else
    bad "installer never installs hooks/speckit-hooks.yaml"
  fi
  if grep -qi "inert" "$ROOT/bin/speckit-init"; then
    ok "installer warns when the hooks plugin is absent (inert, not silently useless)"
  else
    bad "installer would install hooks without checking the plugin — they would do nothing silently"
  fi
  if grep -q "hooks.yaml" "$ROOT/bin/speckit-uninit"; then
    ok "uninit removes the hooks it installed"
  else
    bad "uninit leaves .opencode/hook/hooks.yaml behind"
  fi
else
  bad "hooks/speckit-hooks.yaml missing — the kit claims it cannot enforce anything, and this is the fix"
fi

hdr "1g. drift checker"
CK="$ROOT/bin/speckit-check"
if [ -x "$CK" ]; then
  ok "bin/speckit-check present and executable"
  # It must be READ-ONLY — it reports, it does not repair. A checker that writes is
  # a checker nobody runs against a repo they care about.
  #
  # Comment lines are stripped before matching, because a comment cannot mutate anything. This
  # check once failed on a comment that merely NAMED the forbidden tokens while explaining why
  # they were avoided — a false positive that punishes documenting the rule. Match code only.
  if grep -v '^[[:space:]]*#' "$CK" | grep -qE "speckit-init\\?\"|rm -rf|cp -"; then
    bad "speckit-check appears to mutate — it must only report"
  else
    ok "speckit-check is read-only (no writes, only advises running speckit-init)"
  fi
  # It must know about every component the installer ships, or it will report
  # 'current' while a repo is missing something.
  missing=""
  for c in "speckit.md" "hooks/speckit-hooks.yaml" "AGENTS.md" "preset/preset.yml"; do
    grep -q "$c" "$CK" || missing="$missing $c"
  done
  if [ -z "$missing" ]; then
    ok "speckit-check covers entry point, hooks, bridge and preset"
  else
    bad "speckit-check does not check:$missing"
  fi
  # The functional checks need the `specify` CLI (they install into a scratch repo).
  # The STATIC gate job deliberately does not install it, so without this guard the
  # section failed on a missing tool rather than on a defect. §5 already skips the same way.
  if ! command -v specify >/dev/null 2>&1; then
    printf '  skip  specify CLI not on PATH — the functional drift checks need it\n'
  else
  # Functional: a deliberately-stale repo must be flagged, a current one must not.
  # (Previously this checked the kit's own repo, which was kept stale on purpose;
  # the user has since approved updating it, so the fixture is stale by construction.)
  TD="$(mktemp -d)"; git init -q "$TD" 2>/dev/null
  touch "$TD/README.md"; git -C "$TD" add -A
  git -C "$TD" -c user.email=e@e -c user.name=e commit -qm init
  "$ROOT/bin/speckit-init" "$TD" >/dev/null 2>&1 || true
  # A fresh install may legitimately return 3 (a governance DECISION: its constitution can lag
  # the template's appended sections). It must NEVER return 1 (drift) or 2. Capture the code and
  # the output, so a failure says WHICH property broke — the lesson from the changelog where
  # discarding the failing test's output made a CI failure undiagnosable.
  _rc=0; _ckout="$(bash "$CK" "$TD" 2>&1)" || _rc=$?
  if [ "$_rc" = "0" ] || [ "$_rc" = "3" ]; then
    ok "speckit-check reports a freshly-installed repo as current or decision-needed (exit $_rc)"
  else
    bad "freshly-installed repo reported as drifting (exit $_rc) — detection or install is broken"
    printf '%s\n' "$_ckout" | tail -8 | sed 's/^/        /'
  fi
  # now make it stale on purpose — TWO ways, because the checker once handled
  # version drift but was INVERTED on content drift (a `pipefail` bug it survived
  # because only the version path was tested).
  #
  # (a) version drift
  python3 - "$TD/.specify/presets/spec-driven-development/preset.yml" <<'PY'
import re, sys
p = sys.argv[1]
s = open(p).read()
s = re.sub(r'^(\s+)version:\s+"([^"]+)"\s*$',
           lambda m: m.group(1) + 'version: "9.9.9"', s, count=1, flags=re.M)
open(p, "w").write(s)
PY
  grep -q 'version: "9.9.9' "$TD/.specify/presets/spec-driven-development/preset.yml" \
    || bad "test fixture: could not make the installed preset stale before checking"
  rc=2; bash "$CK" "$TD" >/dev/null 2>&1 || rc=$?
  if [ "$rc" = "1" ]; then
    ok "speckit-check flags a deliberately-stale repo (drift detected)"
  else
    bad "stale repo reported as current (exit $rc, want 1) — detection is broken"
  fi

  # (b) CONTENT drift with version UNCHANGED — the inverted-check regression.
  # Restore the version, then weaken a content file; the checker must still flag it.
  "$ROOT/bin/speckit-init" "$TD" >/dev/null 2>&1 || true
  printf '\n# drift probe\n' >> "$TD/.specify/presets/spec-driven-development/commands/speckit.implement.prepend.md"
  rc=2; bash "$CK" "$TD" >/dev/null 2>&1 || rc=$?
  if [ "$rc" = "1" ]; then
    ok "speckit-check flags CONTENT drift at the same version (inverted-check regression)"
  else
    bad "content drift at unchanged version reported as current (exit $rc, want 1)"
  fi
  rm -rf "$TD"
  TMPD="$(mktemp -d)"; mkdir -p "$TMPD/.specify"
  rc=2
  bash "$CK" "$TMPD" >/dev/null 2>&1 || rc=$?
  if [ "$rc" = "2" ]; then
    ok "speckit-check exits 2 on a non-kit .specify/ project (not the kit's, nothing to compare)"
  else
    bad "speckit-check exited $rc on a non-kit project (want 2)"
  fi
  rm -rf "$TMPD"
  fi
else
  bad "bin/speckit-check missing — no way to tell whether an existing repo needs the update"
fi

hdr "1i. ledger resume (T021) — the rule is mechanical, so it has an oracle"
# T021's behavioural half has no oracle — it is the agent's behaviour. So the rule was
# extracted into bin/speckit-resume, which supplies an oracle for the RULE, and the
# behaviour is then asserted metamorphically: progress is monotone and no task completes
# twice across a resume. Fault injection is aimed at a representative boundary (after
# task N's commit), not at a random instant.
RS="$ROOT/bin/speckit-resume"
if [ ! -x "$RS" ]; then
  bad "bin/speckit-resume missing — the resume rule is not mechanical"
else
  ok "bin/speckit-resume present and executable"
  python3 - "$RS" <<'PY' || fail=1
import os, subprocess, sys, tempfile

rs = sys.argv[1]

def resume(tasks, ledger):
    d = tempfile.mkdtemp(prefix="resume-")
    open(os.path.join(d, "tasks.md"), "w").write(tasks)
    if ledger is not None:
        open(os.path.join(d, "progress.md"), "w").write(ledger)
    r = subprocess.run([rs, d], capture_output=True, text=True)
    return r.stdout.strip(), r.returncode

def mk(n):
    return "".join(f"- [ ] T{i:03d} task {i}\n" for i in range(1, n + 1))

def completed(text):
    return {int(l.split()[1].rstrip(":")) for l in text.splitlines()
            if l.startswith("Task ") and ": complete" in l}

bad = 0

# --- the oracle: cases where the expected resume point is known by construction ---
cases = [
    ("no ledger",                              mk(3), None, "RESUME T001"),
    ("empty ledger",                           mk(3), "", "RESUME T001"),
    ("first complete",                         mk(3), "Task 1: complete (x)\n", "RESUME T002"),
    ("two complete",                           mk(3), "Task 1: complete\nTask 2: complete\n", "RESUME T003"),
    ("all complete",                           mk(3), "".join(f"Task {i}: complete\n" for i in range(1, 4)), "COMPLETE"),
    ("gap at 2 (1 and 3 done)",                mk(3), "Task 1: complete\nTask 3: complete\n", "RESUME T002"),
    ("a fix round is not completion",          mk(2), "Task 1: fix round 1/3\n", "RESUME T001"),
    ("a tick with no ledger line is not done", "- [x] T001 a\n- [ ] T002 b\n", "Task 2: complete\n", "RESUME T001"),
]
for name, tasks, ledger, want in cases:
    got, rc = resume(tasks, ledger)
    if got != want or rc != 0:
        print(f"  FAIL  {name}: got {got!r} rc={rc}, want {want!r}")
        bad = 1
if not bad:
    print(f"  ok    resume oracle: {len(cases)} cases (gaps, fix rounds, tick-without-ledger)")

# --- metamorphic relations across a targeted interrupt ---
# Kill after task 2's commit (a representative boundary), then resume to completion.
# Invariants that must hold whatever the agent does:
#   M1 monotone progress    — the completed set never shrinks
#   M2 no double completion — no task is recorded complete twice
ledger = "Task 1: complete (a)\nTask 2: complete (b)\n"
prev = completed(ledger)
if not bad:
    for expect in ["RESUME T003", "RESUME T004", "RESUME T005", "COMPLETE"]:
        got, _ = resume(mk(5), ledger)
        if got != expect:
            print(f"  FAIL  interrupt/resume: got {got!r}, want {expect!r}"); bad = 1; break
        if expect.startswith("RESUME"):
            n = int(expect.split()[1][1:])
            ledger += f"Task {n}: complete (x)\n"
            cur = completed(ledger)
            if not cur >= prev:
                print("  FAIL  M1: progress went backwards across a resume"); bad = 1; break
            if len(completed(ledger.replace(f"Task {n}: complete (x)\n", ""))) != len(prev):
                print("  FAIL  M2: a task was completed twice"); bad = 1; break
            prev = cur
if not bad:
    print("  ok    targeted interrupt: resume is monotone and completes no task twice")

sys.exit(bad)
PY
  # The rule must be USED, not just available — the implement step points at it.
  if grep -q "speckit-resume" "$ROOT/preset/commands/speckit.implement.prepend.md"; then
    ok "the implement step points at speckit-resume (the rule is used, not reinterpreted)"
  else
    bad "the implement step does not reference speckit-resume — the rule is still prose"
  fi
fi

hdr "1j. scenario evals (T033) — the judgement scenarios, against a scripted agent"
# Eight of the twelve quickstart scenarios are deterministic and asserted above. The three
# judgement ones need a real agent, so their harness runs here against a scripted fake —
# which proves the harness works without spending a model call. The live pass is separate.
SC_OUT="$(python3 "$ROOT/evals/run-scenario-evals.py" --fake 2>&1)" && SC_RC=0 || SC_RC=$?
if [ "$SC_RC" = "0" ] && printf '%s' "$SC_OUT" | grep -q "SCENARIOS: PASS"; then
  ok "scenario harness passes against a scripted agent (S4, S8)"
else
  bad "scenario harness failed — run: python3 evals/run-scenario-evals.py --fake"
  printf '%s\n' "$SC_OUT" | sed 's/^/        /' | tail -10
fi
# A harness that cannot fail proves nothing, so the assertions get a negative control.
if python3 - "$ROOT/evals/run-scenario-evals.py" <<'PY'
import importlib.util, pathlib, sys, tempfile
spec = importlib.util.spec_from_file_location("rse", sys.argv[1])
m = importlib.util.module_from_spec(spec)
spec.loader.exec_module(m)
d = pathlib.Path(tempfile.mkdtemp())
(d / "specs").mkdir()
(d / "specs" / "plan.md").write_text("x")          # the fast lane took the full workflow
sys.exit(0 if (m.s8("done", d) and m.s4("I ran it", d)) else 1)
PY
then
  ok "scenario assertions are load-bearing (they fail a negative control)"
else
  bad "scenario assertions are vacuous — they passed a negative control"
fi

hdr "1e. novice quickstart"
QS="$ROOT/QUICKSTART.md"
if [ -f "$QS" ]; then
  ok "QUICKSTART.md present"
  # The whole point is that it works when pasted to an AI cold, so the command it
  # names must be the one that actually installs everything.
  if grep -q "speckit-init" "$QS"; then
    ok "quickstart points at speckit-init (the command that installs /speckit too)"
  else
    bad "quickstart does not name speckit-init"
  fi
  if grep -q "/speckit.constitution" "$QS"; then
    ok "quickstart tells the user to run /speckit.constitution first"
  else
    bad "quickstart omits /speckit.constitution"
  fi
  if grep -qE "Do not ask them anything technical|Do not ask the user anything technical" "$QS"; then
    ok "quickstart is written for an agent, not a human"
  else
    bad "quickstart is not addressed to an AI assistant"
  fi
else
  bad "QUICKSTART.md missing — no path for a non-expert or an AI to set this up"
fi

hdr "1c. changelog + version"
if [ -f "$ROOT/CHANGELOG.md" ]; then
  ok "CHANGELOG.md present"
  _v=$(grep -E '^\s+version:' "$ROOT/preset/preset.yml" | head -1 | sed 's/.*"\(.*\)".*/\1/')
  if grep -q "## \[$_v\]" "$ROOT/CHANGELOG.md"; then
    ok "CHANGELOG has an entry for the current preset version ($_v)"
  else
    bad "CHANGELOG has no entry for preset version $_v"
  fi
  # The version must be the NEWEST changelog entry, not merely present. A stale
  # preset version (e.g. left at 1.8.0 through the 1.9.0/1.9.1 releases) passed the
  # presence check because an old entry still matched. Found by audit.
  _latest=$(grep -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' "$ROOT/CHANGELOG.md" | head -1 | tr -d '#[] ')
  if [ "$_v" = "$_latest" ]; then
    ok "preset version is the newest CHANGELOG release ($_latest)"
  else
    bad "preset version $_v is behind the newest CHANGELOG release $_latest"
  fi
else
  bad "CHANGELOG.md missing"
fi

hdr "2. skill frontmatter"
python3 - "$ROOT/skill/spec-driven-development" <<'PY' || fail=1
import os, re, sys
base = sys.argv[1]
p = os.path.join(base, "SKILL.md")
if not os.path.isfile(p):
    print("  FAIL  SKILL.md missing"); sys.exit(1)
raw = open(p, encoding="utf-8").read()
m = re.match(r'^---\n(.*?)\n---\n', raw, re.S)
if not m:
    print("  FAIL  no YAML frontmatter"); sys.exit(1)
fm = m.group(1)
name = (re.search(r'^name:\s*(.+)$', fm, re.M) or [None, ""])[1].strip()
desc = (re.search(r'^description:\s*(.+)$', fm, re.M) or [None, ""])[1].strip()
ok = True
if not re.match(r'^[a-z0-9]+(-[a-z0-9]+)*$', name):
    print(f"  FAIL  name {name!r} fails ^[a-z0-9]+(-[a-z0-9]+)*$"); ok = False
if not (1 <= len(name) <= 64):
    print(f"  FAIL  name length {len(name)} not in 1..64"); ok = False
if name != os.path.basename(base):
    print(f"  FAIL  name {name!r} != directory {os.path.basename(base)!r}"); ok = False
if not (1 <= len(desc) <= 1024):
    print(f"  FAIL  description length {len(desc)} not in 1..1024"); ok = False
lines = raw.count("\n")
if lines >= 500:
    print(f"  FAIL  SKILL.md is {lines} lines — Anthropic recommends under 500"); ok = False

# --- frontmatter portability ---------------------------------------------------
# The portable spec fields are name, description, license, compatibility, metadata,
# allowed-tools. opencode recognises five of those and SILENTLY IGNORES the rest —
# so a stray top-level field looks like it works and does nothing. Claude Code
# packaging hard-errors on unknown keys. Either way, only spec fields belong here.
ALLOWED = {"name", "description", "license", "compatibility", "metadata", "allowed-tools"}
top = [ln.split(":", 1)[0].strip() for ln in fm.splitlines()
       if ln.strip() and not ln[0].isspace() and ":" in ln]
extra = [k for k in top if k not in ALLOWED]
if extra:
    print(f"  FAIL  non-spec frontmatter field(s): {', '.join(extra)} "
          f"(opencode ignores them silently; Claude Code packaging rejects them)"); ok = False
else:
    print(f"  ok    frontmatter uses only spec fields ({', '.join(sorted(top))})")

# metadata values must be strings per the spec (a bare 1.0 parses as a float)
if "metadata:" in fm:
    bad_md = [ln.strip() for ln in fm.splitlines()
              if ln.startswith((" ", "\t")) and ":" in ln
              and not re.match(r'^\s*[A-Za-z0-9_-]+:\s*(".*"|\'.*\'|\S+)$', ln)]
    if bad_md:
        print(f"  FAIL  metadata value(s) not plain strings: {bad_md}"); ok = False

# --- description style (official guidance: third person, what + when) ----------
# "Always write in third person. The description is injected into the system prompt."
if re.match(r'^(Use this|You |I |Helps with|This skill)', desc):
    print("  FAIL  description opens in the imperative/second person; "
          "official guidance requires third person (e.g. 'Spec-driven development for …')")
    ok = False
else:
    print("  ok    description is third person")

# --- the kit must not claim it can enforce anything ----------------------------
# Commands guarantee INVOCATION, not COMPLIANCE. Claiming otherwise is the exact
# error official guidance corrects: "context, not enforced configuration".
for rel in ("skill/spec-driven-development/SKILL.md", "README.md", "commands/speckit.md"):
    fp = os.path.join(os.path.dirname(base), rel)
    if not os.path.isfile(fp):
        continue
    body = open(fp, encoding="utf-8").read()
    if re.search(r'\benforceable rules\b', body, re.I):
        print(f"  FAIL  {rel} still claims 'enforceable rules' — commands cannot enforce"); ok = False
if ok:
    print("  ok    no 'enforceable rules' claim (commands guarantee invocation, not compliance)")

# --- references must state when to read them ----------------------------------
refs_dir = os.path.join(base, "references")
if os.path.isdir(refs_dir):
    ref_files = sorted(f for f in os.listdir(refs_dir) if f.endswith(".md"))
    named = sum(1 for f in ref_files if f in raw)
    if named != len(ref_files):
        print(f"  FAIL  {len(ref_files)-named} reference file(s) not linked from SKILL.md"); ok = False
    elif "| Read this | When |" not in raw:
        print("  FAIL  references are linked but no 'Read this / When' table — "
              "official guidance: make the read trigger explicit"); ok = False
    else:
        print(f"  ok    all {len(ref_files)} references linked with an explicit read trigger")

if ok:
    print(f"  ok    skill frontmatter valid (name={name}, {lines} lines, desc {len(desc)} chars)")
sys.exit(0 if ok else 1)
PY

hdr "3. preset manifest"
python3 - "$ROOT/preset" <<'PY' || fail=1
import os, re, sys
base = sys.argv[1]
p = os.path.join(base, "preset.yml")
raw = open(p, encoding="utf-8").read()
ok = True
def need(cond, msg):
    global ok
    if cond: print(f"  ok    {msg}")
    else:    print(f"  FAIL  {msg}"); ok = False

need('schema_version: "1.0"' in raw, 'schema_version is "1.0"')
for key in ("id:", "name:", "version:", "description:"):
    need(re.search(r'(?m)^\s+%s' % re.escape(key), raw) is not None, f"preset.{key.rstrip(':')} present")
# Version strings must be quoted or YAML parses 1.0 as a float and the validator rejects it.
need(re.search(r'(?m)^\s+version:\s*"', raw) is not None, "version is a quoted string")
need(re.search(r'(?m)^\s+speckit_version:\s*"', raw) is not None, "requires.speckit_version is a quoted string")
need('strategy: "append"' in raw, 'uses strategy: "append" (never replace)')

# Every declared template file must exist, and the append targets must be core template names.
targets = re.findall(r'name:\s*"([a-z0-9-]*template)"', raw)
files   = re.findall(r'file:\s*"([^"]+)"', raw)
need(len(targets) >= 4, f"declares at least 4 append targets (found {len(targets)})")
for t in ("constitution-template", "spec-template", "plan-template", "tasks-template"):
    need(t in targets, f"targets {t}")
for f in files:
    need(os.path.isfile(os.path.join(base, f)), f"file exists: {f}")
sys.exit(0 if ok else 1)
PY

hdr "3b. command contributions (this is what makes the rules actually apply)"
python3 - "$ROOT/preset" <<'PY' || fail=1
import os, re, sys
base = sys.argv[1]
raw = open(os.path.join(base, "preset.yml"), encoding="utf-8").read()
ok = True
def need(cond, msg):
    global ok
    if cond: print(f"  ok    {msg}")
    else:    print(f"  FAIL  {msg}"); ok = False

# Every command entry must be a prepend. `replace` would stop us composing with
# upstream command updates, and the rules here are additive by design.
cmds = re.findall(r'type:\s*"command".*?(?=type:\s*"|\Z)', raw, re.S)
need(len(cmds) >= 5, f"declares at least 5 command entries (found {len(cmds)})")
bad = [c for c in cmds if 'strategy: "prepend"' not in c]
need(not bad, "every command entry uses strategy: prepend (never replace)")

# Each command must carry the specific rules for its step. These are the rules that
# used to live only in the skill, which fires on roughly 60% of relevant requests -
# so their presence in the command is the whole point of this preset.
expected = {
    "commands/speckit.specify.prepend.md":   ["Section integrity", "resolve-template.sh", "Choose the workflow first", "Ask only what materially matters"],
    "commands/speckit.plan.prepend.md":      ["Section integrity", "resolve-template.sh", "Sweep before you list", "go to the primary source", "not to survey the topic", "Never cite what you did not open", "Stop at the approval gate"],
    "commands/speckit.tasks.prepend.md":     ["Section integrity", "resolve-template.sh", "traces to a requirement", "recorded verification command", "Control scope"],
    "commands/speckit.implement.prepend.md": ["Evidence before", "Tick tasks honestly", "execution budget", "earliest"],
    "commands/speckit.converge.prepend.md":  ["Completion requires evidence", "round up to green", "did not do the work", "Every finding carries evidence", "Stop when no UNRESOLVED", "Send the negative case first", "Handoff discipline"],
}
files = set(re.findall(r'(?m)^\s+file:\s*"(commands/[^"]+)"', raw))
for f, markers in expected.items():
    need(f in files, f"declared: {os.path.basename(f)}")
    p = os.path.join(base, f)
    if not os.path.isfile(p):
        need(False, f"exists: {f}"); continue
    body = open(p, encoding="utf-8").read()
    missing = [m for m in markers if m not in body]
    need(not missing, f"{os.path.basename(f)} carries its rules" + (f" (missing: {missing})" if missing else ""))
    # A contribution must not carry its own frontmatter - prepend inserts after the
    # command's frontmatter, so a second block would corrupt the command.
    need(not body.lstrip().startswith("---"), f"{os.path.basename(f)} has no frontmatter of its own")
sys.exit(0 if ok else 1)
PY

hdr "3c. EARS + correctness properties (feature 001)"
python3 - "$ROOT/preset" <<'PY' || fail=1
import os, re, sys
base = sys.argv[1]
ok = True
def need(cond, msg):
    global ok
    if cond: print(f"  ok    {msg}")
    else:    print(f"  FAIL  {msg}"); ok = False

spec  = open(os.path.join(base, "templates/spec-addendum.md"),  encoding="utf-8").read()
plan  = open(os.path.join(base, "templates/plan-addendum.md"),  encoding="utf-8").read()
tasks = open(os.path.join(base, "templates/tasks-addendum.md"), encoding="utf-8").read()

# --- EARS: all five shapes, SHALL-only, fixed clause order (FR-001..FR-005) ---
need("Requirements Syntax (EARS)" in spec, "spec addendum carries EARS guidance")
for shape in ("THE <system> SHALL <response>", "WHEN <trigger>",
              "WHILE <state>", "WHERE <feature is included>", "IF <unwanted condition>"):
    need(shape in spec, f"EARS shape present: {shape}")
need("RFC 2119" in spec, "spec addendum states the RFC 2119 keyword rule")
need(re.search(r"never MUST", spec) is not None, "spec addendum bans MUST")
need("Clause order is fixed" in spec, "spec addendum states the clause-order rule")
need("used with\ncare and sparingly" in spec or "care and sparingly" in spec,
     "spec addendum carries the RFC 2119 'sparingly' rule (do not SHALL everything)")

# --- Normative vs informative (ISO/IEC Directives Pt 2 §3.2; W3C QA Framework) ---
need("## Normative Status" in spec, "spec addendum has a Normative Status section")
need("Normative** — binds conformance" in spec, "spec addendum defines normative")
need("Informative** — assists understanding" in spec, "spec addendum defines informative")
need("shall not contain requirements" in spec,
     "spec addendum bans requirements in notes/examples (ISO/IEC rule)")
need("Normative keywords do not appear in informative sections" in spec,
     "spec addendum bans normative keywords in informative sections")
need("ISO/IEC Directives" in spec, "spec addendum cites the normative/informative standard")
need("no automatic precedence" in spec,
     "spec addendum states there is no automatic precedence between documents")
need("dated reference" in spec, "spec addendum requires a dated reference for the companion")

# --- Document status metadata (MADR-informed) ---
need("## Document Status" in spec, "spec addendum has a Document Status section")
need("immediately after the core metadata block" in spec, "spec addendum fixes the status placement")
for field in ("**Status changed:**", "**Approved by:**", "**Authority:**", "**Workflow:**",
              "**Companion:**"):
    need(field in spec, f"status block carries {field}")
need("Do not add a second status field" in spec,
     "spec addendum forbids a duplicate status field (the core template owns one)")
need("open set" in spec, "status vocabulary is declared an open set, not a closed enum")
need("never reuse an id" in spec, "status section states ids are never reused")
need("three separate facts" in spec, "approval is recorded as who/when/authority, not one word")
# The lifecycle must use the CORE template's vocabulary (Draft), not a competing one (proposed).
need("`Draft`" in spec and "`Superseded by" in spec,
     "lifecycle uses the core template's Draft vocabulary")

# --- Correctness properties (FR-006, FR-009, FR-012) ---
need("## Correctness Properties" in plan, "plan addendum has Correctness Properties")
need("for any" in plan, "plan addendum states the `for any` requirement")
need("Property ID" in plan, "plan addendum carries the property table")
need("Non-mapped reason" in plan, "plan addendum carries the opt-out column")
need("Opt-out rule" in plan, "plan addendum states the opt-out rule")
need("Framework decision" in plan, "plan addendum records the framework decision")
need("Detect one; never assume one" in plan, "plan addendum says detect, never assume")
need("Check method" in plan, "plan addendum requires a check method per property")
for m in ("runtime-assert", "property-test", "model-check", "review-only"):
    need(m in plan, f"plan addendum lists check method: {m}")
need("Scope" in plan and "operation / type / system" in plan,
     "plan addendum requires a property scope")
need("Round-trip" in plan and "Invariant-preservation" in plan,
     "plan addendum lists canonical property shapes")
need("Hoare" in plan and "design-by-contract" in plan,
     "plan addendum cites the property lineage (Hoare / Liskov & Guttag / DbC)")
need("it is a wish" in plan, "plan addendum states a property with no check is not a property")

# --- Parking lot: capture discipline (scope control with a door) ---
need("## Future Work (parking lot)" in spec, "spec addendum has the parking lot")
need("Capture, do not act" in spec, "parking lot states the capture rule")
need("Noticed during" in spec and "Why deferred" in spec and "Revisit when" in spec,
     "parking lot records provenance (when/why/revisit)")
need("Parking lot vs Non-Goals" in spec,
     "parking lot distinguishes deferral from a Non-Goal decision")
need("Review the parking lot at close-out" in spec, "parking lot has a review step")

impl = open(os.path.join(base, "commands/speckit.implement.prepend.md"), encoding="utf-8").read()
conv = open(os.path.join(base, "commands/speckit.converge.prepend.md"), encoding="utf-8").read()
need("Park out-of-scope ideas" in impl, "implement command tells the agent to park, not act")
need("do not drop them" in impl, "implement command forbids silently dropping an idea")
need("Review the parking lot" in conv, "converge command reviews the parking lot")
for outcome in ("promote", "keep parked", "delete"):
    need(outcome in conv, f"converge names the parking outcome: {outcome}")

# --- Progress ledger: state on disk, not in conversation -------------------
impl2 = open(os.path.join(base, "commands/speckit.implement.prepend.md"), encoding="utf-8").read()
conv2 = open(os.path.join(base, "commands/speckit.converge.prepend.md"), encoding="utf-8").read()
need("progress ledger" in impl2, "implement command requires a progress ledger")
need("conversation memory does not survive compaction" in impl2,
     "ledger rule states the compaction rationale (the failure it prevents)")
need("Resume rule" in impl2, "ledger defines how a fresh session resumes")
need("Task <N>: complete" in impl2, "ledger completion marker carries evidence")
need("Ruling:" in impl2, "ledger records decisions with a Ruling: line")
need("archive it and start fresh" in impl2, "ledger forbids merging two plans' ledgers")
need("Close the progress ledger" in conv2, "converge closes the ledger")
need("Status: complete" in conv2, "closing tombstones the ledger, does not delete it")

# --- Property-test tasks (FR-007, FR-012) ---
need("Property-Based Test Tasks" in tasks, "tasks addendum has the property-test rules")
need("One task per P-ID" in tasks, "tasks addendum states one task per property")
need("P-xxx" in tasks and "FR-xxx" in tasks, "tasks addendum traces both IDs")
need("never one of your own choosing" in tasks, "tasks addendum defers the framework to the plan")
need("Co-locate" in tasks, "tasks addendum states the co-location rule")
need("| Property |" in tasks, "Requirement Coverage table carries a Property column")

# --- No-hardcode guard (FR-008, SC-003) ---
# A concrete PBT framework may appear ONLY in the plan's detection table (a table row), or on
# the spec addendum's "do not hardcode" line. Never in tasks-addendum, never elsewhere.
# Checked LINE-WISE: a character window around a match crosses line boundaries and produces
# false failures for mentions that are legitimately allowed.
FRAMEWORKS = ("Hypothesis", "hypothesis", "fast-check", "jqwik", "quickcheck", "QuickCheck",
              "proptest", "scalacheck", "ScalaCheck", "PropEr", "StreamData")
def hits(text):
    out = []
    for i, line in enumerate(text.splitlines(), 1):
        for name in FRAMEWORKS:
            if name in line:
                out.append((i, name, line))
    return out

bad = hits(tasks)
need(not bad, "tasks addendum names no concrete framework (FR-008)"
     + (f" - found {[f'{n} @ line {i}' for i, n, _ in bad]}" if bad else ""))

bad = [(i, n, l) for i, n, l in hits(spec) if "hardcode" not in l]
need(not bad, "spec addendum names a framework only on the 'do not hardcode' line"
     + (f" - found {[f'{n} @ line {i}' for i, n, _ in bad]}" if bad else ""))

# The detection table is the only place a framework belongs in the plan; its rows start with '|'.
bad = [(i, n, l) for i, n, l in hits(plan) if not l.lstrip().startswith("|")]
need(not bad, "plan addendum names frameworks only inside the detection table"
     + (f" - found {[f'{n} @ line {i}' for i, n, _ in bad]}" if bad else ""))
sys.exit(0 if ok else 1)
PY

hdr "4. eval data parses"
python3 - "$ROOT/evals" <<'PY' || fail=1
import json, os, sys
base = sys.argv[1]
ok = True
for name in ("skill-evals.json", "trigger-evals.json"):
    p = os.path.join(base, name)
    try:
        json.load(open(p, encoding="utf-8"))
        print(f"  ok    {name} parses")
    except Exception as e:
        print(f"  FAIL  {name}: {e}"); ok = False
tr = json.load(open(os.path.join(base, "trigger-evals.json"), encoding="utf-8"))
for group in ("should_trigger", "should_not_trigger"):
    n = len(tr.get(group, []))
    if n >= 8: print(f"  ok    {group}: {n} queries")
    else:      print(f"  FAIL  {group}: only {n} queries (want >=8)"); ok = False
sys.exit(0 if ok else 1)
PY

if [ "$E2E" = "1" ]; then
  hdr "5. end-to-end: init a scratch repo"
  if command -v specify >/dev/null 2>&1; then
    T="$(mktemp -d)"
    trap 'rm -rf "$T"' EXIT
    git init -q "$T"
    ( cd "$T" && printf '# scratch\n' > README.md \
      && printf '{\n  "name": "scratch",\n  "scripts": { "test": "node -e 0", "lint": "node -e 0" }\n}\n' > package.json \
      && git add -A \
      && git -c user.email=e@e -c user.name=e commit -qm init )
    if "$ROOT/bin/speckit-init" "$T" >/dev/null 2>&1; then
      ok "speckit-init completed"
    else
      bad "speckit-init failed"
    fi
    cd "$T"
    # The mechanical boundary, the commands block, the verify entry point, the
    # contract and the fast lane must all be present in a real install.
    if [ -f opencode.json ] && grep -qF '"git push*--force*": "deny"' opencode.json; then
      ok "install wrote the permission boundary (opencode.json)"
    else
      bad "install did not write the permission boundary"
    fi
    if grep -q "SPECKIT-COMMANDS START" AGENTS.md && grep -q '| test |' AGENTS.md; then
      ok "install wrote the Commands block with the detected test command"
    else
      bad "install did not write the Commands block"
    fi
    if [ -x scripts/verify ] && grep -q 'run "test" npm test' scripts/verify; then
      ok "install generated scripts/verify from detection"
    else
      bad "install did not generate scripts/verify"
    fi
    if [ -f .opencode/autonomy-contract.md ]; then ok "install placed the autonomy contract"; else bad "autonomy contract not installed"; fi
    if [ -f .opencode/commands/speckit.quick.md ]; then ok "install copied the fast lane"; else bad "fast lane not installed"; fi
    # Parallelize the 4 resolves: each runs in the background and records its
    # pass/fail in a status file, then `wait` joins them. The reporting loop
    # below stays in the original order so ok/bad output is unchanged.
    # Bash 3.2 safe (no assoc arrays, no mapfile, no wait -n).
    SGR="$(mktemp -d)"
    trap 'rm -rf "$T" "$SGR"' EXIT
    for t in constitution-template spec-template plan-template tasks-template; do
      ( specify preset resolve "$t" 2>&1 | grep -q '\[append\] spec-driven-development' \
        && echo ok > "$SGR/$t.status" || echo bad > "$SGR/$t.status" ) &
    done
    wait || true
    for t in constitution-template spec-template plan-template tasks-template; do
      st="$(cat "$SGR/$t.status" 2>/dev/null || echo bad)"
      if [ "$st" = "ok" ]; then
        ok "$t composes our append layer"
      else
        bad "$t is NOT composing our append layer"
      fi
    done
    rm -rf "$SGR"
    # The prepends are the mechanism that makes BOTH the template addenda and the step
    # rules apply, so assert they reached the MATERIALISED commands the agent reads —
    # not merely that the preset source declares them.
    check_cmd() {
      _c="$1"; _marker="$2"
      if grep -q "$_marker" ".opencode/commands/speckit.$_c.md" 2>/dev/null; then
        ok "speckit.$_c carries its contribution"
      else
        bad "speckit.$_c is missing its contribution (looked for: $_marker)"
      fi
      _first=$(head -1 ".opencode/commands/speckit.$_c.md" 2>/dev/null)
      if [ "$_first" = "---" ]; then ok "speckit.$_c frontmatter intact"; else bad "speckit.$_c frontmatter displaced (first line: $_first)"; fi
    }
    check_cmd specify   "Choose the workflow first"
    check_cmd plan      "Sweep before you list"
    check_cmd plan      "not to survey the topic"
    check_cmd tasks     "traces to a requirement"
    check_cmd implement "Evidence before"
    check_cmd converge  "Completion requires evidence"
    check_cmd converge  "Every finding carries evidence"
    check_cmd converge  "Send the negative case first"
    check_cmd converge  "Stop when no UNRESOLVED"
    # Reversibility: uninit must restore the repo to its pre-install state, and must
    # preserve the user's own AGENTS.md content. Asserted on a scratch repo with a
    # pre-existing AGENTS.md, because that is the case that can silently lose data.
    if [ -x "$ROOT/bin/speckit-uninit" ]; then
      U="$(mktemp -d)"
      git init -q "$U"
      printf '# scratch\n' > "$U/README.md"
      printf '{"name":"u","scripts":{"test":"node -e 0"}}\n' > "$U/package.json"
      printf '# My own notes\n\nKeep me.\n' > "$U/AGENTS.md"
      ( cd "$U" && git add -A && git -c user.email=e@e -c user.name=e commit -qm init )
      "$ROOT/bin/speckit-init" "$U" >/dev/null 2>&1 || true
      "$ROOT/bin/speckit-uninit" "$U" >/dev/null 2>&1 || true
      if [ -d "$U/.specify" ]; then bad "uninit left .specify/ behind"; else ok "uninit removed .specify/"; fi
      if [ -f "$U/opencode.json" ]; then bad "uninit left the permission boundary behind"; else ok "uninit removed the permission boundary"; fi
      if [ -f "$U/.opencode/autonomy-contract.md" ]; then bad "uninit left the autonomy contract"; else ok "uninit removed the autonomy contract"; fi
      if [ -f "$U/scripts/verify" ]; then bad "uninit left scripts/verify"; else ok "uninit removed scripts/verify"; fi
      if [ -f "$U/AGENTS.md" ] && grep -q "Keep me." "$U/AGENTS.md"; then
        ok "uninit preserved the user's own AGENTS.md content"
      else
        bad "uninit lost the user's own AGENTS.md content"
      fi
      if [ -z "$(git -C "$U" status --porcelain)" ]; then
        ok "uninit restored the repo to its pre-install state (git clean)"
      else
        bad "uninit left the repo dirty: $(git -C "$U" status --porcelain | head -3 | tr '\n' ' ')"
      fi
      rm -rf "$U"
    else
      bad "bin/speckit-uninit missing or not executable"
    fi
    # P-002: an existing opencode.json is never clobbered (FR-002).
    N="$(mktemp -d)"
    git init -q "$N"
    printf '{\n  "permission": "allow"\n}\n' > "$N/opencode.json"
    ( cd "$N" && git add -A && git -c user.email=e@e -c user.name=e commit -qm init )
    cp "$N/opencode.json" "$N/opencode.json.before"
    "$ROOT/bin/speckit-init" "$N" >/dev/null 2>&1 || true
    # No-clobber = no key the user had is removed or altered. An ADDITION is allowed:
    # the installer's CiteKit step runs `opencode mcp add`, which writes a `$schema`
    # line into the project config. Asserting byte-identity here was stricter than the
    # contract (P-002: "never removes or rewrites a user-owned region") and failed on a
    # benign addition.
    if python3 - "$N/opencode.json.before" "$N/opencode.json" <<'PY'
import json, re, sys
def load(p):
    s = open(p, encoding="utf-8").read()
    s = re.sub(r'(?m)^\s*//.*$', '', s)
    s = re.sub(r',(\s*[}\]])', r'\1', s)
    return json.loads(s)
before, after = load(sys.argv[1]), load(sys.argv[2])
sys.exit(0 if all(after.get(k) == v for k, v in before.items()) else 1)
PY
    then
      ok "installer never removes or alters a user key in opencode.json"
    else
      bad "installer removed or altered a user key in opencode.json"
      diff "$N/opencode.json.before" "$N/opencode.json" | sed 's/^/        /' | head -10
    fi
    rm -rf "$N"
    # FR-015: a managed block edited since install is reported on the next install.
    D="$(mktemp -d)"
    git init -q "$D"
    printf '# x\n' > "$D/README.md"
    printf '{"name":"d","scripts":{"test":"node -e 0"}}\n' > "$D/package.json"
    ( cd "$D" && git add -A && git -c user.email=e@e -c user.name=e commit -qm init )
    "$ROOT/bin/speckit-init" "$D" >/dev/null 2>&1 || true
    python3 - "$D/AGENTS.md" <<'PY'
import sys
p = sys.argv[1]; s = open(p).read()
open(p, "w").write(s.replace("## Commands", "## Commands (edited)", 1))
PY
    # Capture first: piping the installer straight into `grep -q` lets grep exit on
    # the match and SIGPIPE the producer, which under `set -o pipefail` reads as
    # "not found". (The installer documents this same trap at its §4.)
    D_OUT="$("$ROOT/bin/speckit-init" "$D" 2>&1 || true)"
    if printf '%s' "$D_OUT" | grep -q "differs from the installed copy"; then
      ok "installer reports drift in a managed block (FR-015)"
    else
      bad "installer did not report managed-block drift (FR-015)"
    fi
    rm -rf "$D"
    for m in "SPECKIT-BRIDGE START" "SPECKIT-BRIDGE END" "SPECKIT-COMMANDS START" "SPECKIT-COMMANDS END" "<!-- SPECKIT START -->" "<!-- SPECKIT END -->"; do
      c=$(grep -c "$m" AGENTS.md 2>/dev/null || true)
      if [ "$c" = "1" ]; then ok "marker once: $m"; else bad "marker $m appears $c times"; fi
    done
    # Idempotency.
    #
    # The assertion is deliberately NOT "run1 == run2". spec-kit's own
    # agent-context extension inserts a blank line before its managed block when
    # it first materializes, and our rewrite normalizes that on the next run.
    # The difference is whitespace-only, and it comes from an extension file we
    # must not patch: it is not ours, and an upstream update would overwrite it.
    #
    # What idempotency actually has to mean here:
    #   1. re-running loses or alters no content,
    #   2. no marker is ever duplicated, and
    #   3. it reaches a fixed point.
    cp scripts/verify /tmp/sg-verify1
    cp opencode.json /tmp/sg-oc1
    cp AGENTS.md /tmp/sg-run1.md
    "$ROOT/bin/speckit-init" "$T" >/dev/null 2>&1 || true
    cp AGENTS.md /tmp/sg-run2.md
    "$ROOT/bin/speckit-init" "$T" >/dev/null 2>&1 || true
    cp AGENTS.md /tmp/sg-run3.md

    if diff <(grep -v '^[[:space:]]*$' /tmp/sg-run1.md) \
            <(grep -v '^[[:space:]]*$' /tmp/sg-run2.md) >/dev/null 2>&1; then
      ok "re-run changes no content (whitespace-only difference)"
    else
      bad "re-run changed AGENTS.md content, not just whitespace"
      diff /tmp/sg-run1.md /tmp/sg-run2.md | head -5 || true
    fi
    if cmp -s /tmp/sg-run2.md /tmp/sg-run3.md; then
      ok "reaches a fixed point (run2 == run3)"
    else
      bad "does not reach a fixed point: run2 != run3"
    fi
    # P-001 (partial): the other installer-owned artifacts are idempotent too.
    if cmp -s scripts/verify /tmp/sg-verify1 && cmp -s opencode.json /tmp/sg-oc1; then
      ok "re-run leaves scripts/verify and opencode.json unchanged"
    else
      bad "re-run altered scripts/verify or opencode.json"
    fi
    rm -f /tmp/sg-run1.md /tmp/sg-run2.md /tmp/sg-run3.md /tmp/sg-verify1 /tmp/sg-oc1
  else
    printf '  skip  specify CLI not on PATH (install with: uv tool install specify-cli)\n'
  fi
fi

hdr "3d. section integrity — the conformance check for 3b"
SIC="$ROOT/scripts/check-section-integrity.sh"
if [ ! -f "$SIC" ]; then
  bad "scripts/check-section-integrity.sh is missing — the section-integrity rule is prose-only again"
else
  SICD="$(mktemp -d)"
  if bash "$ROOT/.specify/scripts/bash/resolve-template.sh" spec-template > "$SICD/ok.md" 2>"$SICD/err" \
     && [ -s "$SICD/ok.md" ]; then
    # A conformant artifact is the resolved template itself: every required heading is present.
    if bash "$SIC" "$ROOT" spec-template "$SICD/ok.md" >/dev/null 2>&1; then
      ok "accepts a conformant artifact"
    else
      bad "rejected a conformant artifact (false positive)"
    fi
    # Drop one required heading. It MUST fail, or the check is vacuous — the whole point of
    # adding it was that a real spec shipped with two sections missing and nothing noticed.
    grep -v '^## Success Criteria' "$SICD/ok.md" > "$SICD/bad.md" || true
    if bash "$SIC" "$ROOT" spec-template "$SICD/bad.md" >/dev/null 2>&1; then
      bad "accepted an artifact with a required section missing — the check is vacuous"
    else
      ok "catches a missing required section"
    fi
  else
    bad "could not resolve spec-template to build the conformance fixture"
    # Surface the resolver's own error: discarding stderr is why this failed on one
    # runner for a whole push with no way to tell why.
    sed 's/^/        /' "$SICD/err" 2>/dev/null | tail -10
  fi
  rm -rf "$SICD"
fi

hdr "1h. CiteKit MCP registration is optional, and skips cleanly"
MCPBIN="$ROOT/bin/speckit-mcp"
if [ ! -f "$MCPBIN" ]; then
  bad "bin/speckit-mcp is missing"
else
  if bash -n "$MCPBIN"; then ok "bin/speckit-mcp parses"; else bad "bin/speckit-mcp has a syntax error"; fi
  # THE CONTRACT THAT MATTERS: with no CiteKit present this must SKIP and still exit 0. An
  # optional integration that can fail an install is worse than the integration it adds.
  _noKit="$(mktemp -d)"
  _out="$(HOME="$_noKit" bash "$MCPBIN" 2>&1)"; _rc=$?
  if [ "$_rc" = "0" ] && printf '%s' "$_out" | grep -q 'skip'; then
    ok "skips cleanly when CiteKit is absent, and exits 0"
  else
    bad "did not skip cleanly without CiteKit (exit $_rc) — this could break an install"
  fi
  rm -rf "$_noKit"
  # And the installer must still wire it, or the script is dead code.
  if grep -q 'speckit-mcp' "$ROOT/bin/speckit-init"; then
    ok "speckit-init invokes the registration script"
  else
    bad "speckit-init does not invoke bin/speckit-mcp — it is dead code"
  fi
  if grep -q -- '--no-mcp' "$ROOT/bin/speckit-init"; then
    ok "speckit-init offers --no-mcp (opting out is possible)"
  else
    bad "speckit-init has no --no-mcp opt-out"
  fi
fi

printf '\n'
if [ "$fail" = "0" ]; then echo "SELF-GATE: PASS"; else echo "SELF-GATE: FAIL"; fi
exit "$fail"
