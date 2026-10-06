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
if python3 "$ROOT/evals/test-runner-hang.py" >/dev/null 2>&1; then
  ok "eval runner respects its timeout and leaves no orphans"
else
  bad "eval runner hang regression — run: python3 evals/test-runner-hang.py"
fi

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
    "commands/speckit.plan.prepend.md":      ["Section integrity", "resolve-template.sh", "Sweep before you list", "Stop at the approval gate"],
    "commands/speckit.tasks.prepend.md":     ["Section integrity", "resolve-template.sh", "traces to a requirement", "Control scope"],
    "commands/speckit.implement.prepend.md": ["Evidence before", "Tick tasks honestly", "earliest"],
    "commands/speckit.converge.prepend.md":  ["Completion requires evidence", "round up to green", "Handoff discipline"],
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
    check_cmd tasks     "traces to a requirement"
    check_cmd implement "Evidence before"
    check_cmd converge  "Completion requires evidence"
    # Reversibility: uninit must restore the repo to its pre-install state, and must
    # preserve the user's own AGENTS.md content. Asserted on a scratch repo with a
    # pre-existing AGENTS.md, because that is the case that can silently lose data.
    if [ -x "$ROOT/bin/speckit-uninit" ]; then
      U="$(mktemp -d)"
      git init -q "$U"
      printf '# scratch\n' > "$U/README.md"
      printf '# My own notes\n\nKeep me.\n' > "$U/AGENTS.md"
      ( cd "$U" && git add -A && git -c user.email=e@e -c user.name=e commit -qm init )
      "$ROOT/bin/speckit-init" "$U" >/dev/null 2>&1 || true
      "$ROOT/bin/speckit-uninit" "$U" >/dev/null 2>&1 || true
      if [ -d "$U/.specify" ]; then bad "uninit left .specify/ behind"; else ok "uninit removed .specify/"; fi
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
