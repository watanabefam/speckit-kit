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
    ( cd "$T" && printf '# scratch\n' > README.md && git add -A \
      && git -c user.email=e@e -c user.name=e commit -qm init )
    if "$ROOT/bin/speckit-init" "$T" >/dev/null 2>&1; then
      ok "speckit-init completed"
    else
      bad "speckit-init failed"
    fi
    cd "$T"
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
    for m in "SPECKIT-BRIDGE START" "SPECKIT-BRIDGE END" "<!-- SPECKIT START -->" "<!-- SPECKIT END -->"; do
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
    rm -f /tmp/sg-run1.md /tmp/sg-run2.md /tmp/sg-run3.md
  else
    printf '  skip  specify CLI not on PATH (install with: uv tool install specify-cli)\n'
  fi
fi

printf '\n'
if [ "$fail" = "0" ]; then echo "SELF-GATE: PASS"; else echo "SELF-GATE: FAIL"; fi
exit "$fail"
