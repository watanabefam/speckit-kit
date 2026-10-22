#!/usr/bin/env python3
"""Fixture corpus and property checks for the verification engine.

    harness.py --make DIR        build the fixture projects under DIR (idempotent)
    harness.py --case NAME       build and run one named case in a temp dir
    harness.py --property P-00X  run one property check
    harness.py --all             run every case and property; exit 1 on the first failure

Every case builds a throwaway project, runs the real executables and asserts on their output.
A property is a small stdlib generator over a domain the plan named (record orders, exit codes,
changed sets, finding sets, success vectors) — the plan's fallback decision, not a framework.
"""

import json
import os
import random
import shutil
import subprocess
import sys
import tempfile

KIT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
BIN = os.path.join(KIT, "bin")
VERIFY = os.path.join(BIN, "speckit-verify")
LEDGER = os.path.join(BIN, "speckit-ledger")
SECURITY = os.path.join(BIN, "speckit-security")
PASSK = os.path.join(KIT, "evals", "run-passk.py")

FAILURES = []


class Failure(Exception):
    pass


def expect(condition, message):
    if not condition:
        raise Failure(message)


def run(cmd, cwd=None, env=None, timeout=180):
    proc = subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            universal_newlines=True, env=env)
    try:
        out, err = proc.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        proc.kill()
        out, err = proc.communicate()
        raise Failure("timed out: %s" % " ".join(cmd))
    return proc.returncode, out or "", err or ""


def write(path, text):
    parent = os.path.dirname(path)
    if parent and not os.path.isdir(parent):
        os.makedirs(parent)
    with open(path, "w") as fh:
        fh.write(text)


def project():
    return tempfile.mkdtemp(prefix="speckit-fixture-")


def manifest(root, checks, **extra):
    doc = {"version": 1, "checks": checks}
    doc.update(extra)
    write(os.path.join(root, ".specify", "verify.json"), json.dumps(doc, indent=2))


def check(cid, kind="test", runner="pytest", command='python3 -c "print(\'1 passed\')"',
          paths=None, oracle="spec", control='python3 -c "import sys; sys.exit(1)"', **extra):
    doc = {"id": cid, "kind": kind, "runner": runner, "command": command,
           "paths": paths or ["src/**"], "oracle": oracle}
    if control and kind in ("test", "property"):
        doc["control"] = control
    doc.update(extra)
    return doc


def spec(root, ids, evidenced=(), cite_unknown=False):
    body = "# Spec\n\n## Success Criteria\n\n"
    body += "".join("- **%s**: behaviour %s\n" % (i, i) for i in ids)
    write(os.path.join(root, "specs", "demo", "spec.md"), body)
    lines = ["# Progress\n"] + ["- Task %d: complete ([%s] evidence)" % (n + 1, cid)
                                for n, cid in enumerate(evidenced)]
    if cite_unknown:
        lines.append("- Task 99: complete ([SC-999] invented)")
    write(os.path.join(root, "specs", "demo", "progress.md"), "\n".join(lines) + "\n")


def git(root, *args):
    return run(["git"] + list(args), cwd=root)


def init_repo(root):
    git(root, "init", "-q", ".")
    git(root, "config", "user.email", "fixture@example.com")
    git(root, "config", "user.name", "fixture")
    git(root, "add", "-A")
    git(root, "commit", "-qm", "base")


def verify(root, args, env=None):
    return run([VERIFY] + args, cwd=root, env=env)


def verdict_of(root, args, env=None):
    code, out, err = verify(root, list(args) + ["--json"], env=env)
    try:
        doc = json.loads(out)
    except ValueError:
        raise Failure("verify did not print JSON: %s%s" % (out[-500:], err[-500:]))
    return code, doc["record"]["verdict"], doc, out


def records(n, prefix="e"):
    out = []
    for i in range(n):
        out.append({
            "id": "00000000-0000-4000-8000-%012d" % (i + 1),
            "at": "2026-10-22T%02d:%02d:00Z" % ((i * 7) % 24, (i * 13) % 60),
            "mode": "changed", "command": "./scripts/verify", "exit": 0,
            "fingerprint": "sha256:" + "a" * 64, "examined": 1 + i,
            "verdict": "PASS",
        })
    return out


def append(root, rec, ledger=None):
    args = [LEDGER, "append", "--stdin"]
    if ledger:
        args += ["--ledger", ledger]
    proc = subprocess.Popen(args, cwd=root, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, universal_newlines=True)
    out, err = proc.communicate(json.dumps(rec))
    return proc.returncode, out, err


# ---------------------------------------------------------------- cases

def case_zero_tests(root):
    manifest(root, [check("unit", command='python3 -c "import sys; sys.exit(5)"')])
    spec(root, ["SC-001"])
    code, out, _ = verify(root, ["--all", "--spec", "specs/demo/spec.md"])
    expect(code == 3, "zero collected tests must exit 3, got %d" % code)
    expect("SELF-VERIFY: PASS" not in out, "zero tests printed a green verdict")
    expect("no tests collected" in out, "the zero-test reason was not named")
    expect("collected nothing" in out, "the run did not say a check collected nothing")


def case_self_oracle(root):
    manifest(root, [check("anchored", oracle="implementation")])
    spec(root, ["SC-001"])
    code, out, _ = verify(root, ["--all", "--spec", "specs/demo/spec.md"])
    expect(code == 3, "a self-referential oracle must exit 3, got %d" % code)
    expect("oracle=implementation" in out, "the exclusion was not named")
    expect("SELF-VERIFY: PASS" not in out, "an implementation-anchored check passed")


def case_control_passes(root):
    manifest(root, [check("vac", control='python3 -c "print(\'fine\')"')])
    spec(root, ["SC-001"])
    code, out, _ = verify(root, ["--all", "--spec", "specs/demo/spec.md"])
    expect(code == 3, "a passing control must exit 3, got %d" % code)
    expect("control did not fail" in out, "the vacuity reason was not named")
    expect("vacuous" in out, "the check was not marked vacuous")


def case_no_control(root):
    doc = check("nocontrol")
    del doc["control"]
    manifest(root, [doc])
    spec(root, ["SC-001"])
    code, out, _ = verify(root, ["--all", "--spec", "specs/demo/spec.md"])
    expect(code == 3, "a test check with no control must exit 3, got %d" % code)
    expect("no negative control declared" in out, "the missing control was not reported")


def case_clean_control(root):
    manifest(root, [check("unit", command='python3 -c "print(\'3 passed\')"')])
    spec(root, ["SC-001"], evidenced=["SC-001"])
    code, out, _ = verify(root, ["--all", "--spec", "specs/demo/spec.md"])
    expect(code == 0, "a clean run must exit 0, got %d\n%s" % (code, out))
    expect("SELF-VERIFY: PASS" in out, "the clean control did not pass")
    expect("examined=3" in out, "the examined count was not printed")


def case_unmatched(root):
    write(os.path.join(root, "src", "a.py"), "x = 1\n")
    manifest(root, [check("unit", command='python3 -c "print(\'1 passed\')"')])
    spec(root, ["SC-001"], evidenced=["SC-001"])
    init_repo(root)
    write(os.path.join(root, "README.md"), "docs\n")
    write(os.path.join(root, "src", "a.py"), "x = 2\n")
    code, out, _ = verify(root, ["--spec", "specs/demo/spec.md"])
    expect(code == 3, "an unmatched changed file must exit 3, got %d" % code)
    expect("README.md" in out, "the unmatched file was not named")
    os.unlink(os.path.join(root, "README.md"))
    code, out, _ = verify(root, ["--spec", "specs/demo/spec.md"])
    expect(code == 0, "a matched change must pass, got %d\n%s" % (code, out))
    expect("changed: 1 file(s) -> checks: unit" in out, "the selection was not named")


def case_flaky(root):
    write(os.path.join(root, "tests", "flaky.py"),
          'import os, sys\n'
          'flag = os.path.join(os.path.dirname(__file__), ".ran")\n'
          'if os.path.exists(flag):\n'
          '    print("1 passed"); sys.exit(0)\n'
          'open(flag, "w").write("x"); print("1 failed"); sys.exit(1)\n')
    manifest(root, [check("flaky", command="python3 tests/flaky.py", paths=["tests/**"])])
    spec(root, ["SC-001"], evidenced=["SC-001"])
    code, out, _ = verify(root, ["--all", "--spec", "specs/demo/spec.md"])
    expect("flaky-classified" in out, "the flaky result was not labelled")
    expect("attempt 1" in out and "attempt 2" in out, "both outcomes were not retained")
    expect(code == 3, "a flaky check must not be green, got %d" % code)


def case_merge(root):
    ledger = os.path.join(root, "ledger.jsonl")
    rng = random.Random(7)
    for round_no in range(20):
        left = records(4, "l")
        right = records(4, "r")
        for idx, rec in enumerate(left):
            rec["id"] = "10000000-0000-4000-8000-%012d" % (round_no * 100 + idx)
        for idx, rec in enumerate(right):
            rec["id"] = "20000000-0000-4000-8000-%012d" % (round_no * 100 + idx)
        merged = left + right
        rng.shuffle(merged)
        write(ledger, "".join(json.dumps(r, sort_keys=True) + "\n" for r in merged))
        code, out, err = run([LEDGER, "read", "--json", "--ledger", ledger], cwd=root)
        expect(code == 0, "read failed after a shuffled merge: %s" % err)
        ordered = json.loads(out)
        keys = [(r["at"], r["id"]) for r in ordered]
        expect(keys == sorted(keys), "read order is not (at, id) after a merge")
        expect(len(ordered) == len(merged), "records were lost in the merge")
        expect(len(set(r["id"] for r in ordered)) == len(ordered), "ids duplicated in the merge")
        code, out, _ = run([LEDGER, "verify", "--ledger", ledger], cwd=root)
        expect(code == 0, "ledger verify rejected a clean merged trail")


def case_coverage(root):
    write(os.path.join(root, "src", "a.py"), "x = 1\ny = 2\n")
    manifest(root, [check("unit", command='python3 -c "print(\'2 passed\')"')])
    spec(root, ["SC-001"], evidenced=["SC-001"])
    init_repo(root)
    write(os.path.join(root, "src", "a.py"), "x = 1\ny = 2\nz = 3\n")
    write(os.path.join(root, "coverage.json"),
          json.dumps({"files": [{"file": "src/a.py", "executed_lines": [1, 2]}]}))
    code, out, _ = verify(root, ["--coverage", "coverage.json", "--profile", "full",
                                 "--spec", "specs/demo/spec.md"])
    expect("profile=full" in out, "the coverage provenance was not stated")
    expect("reached 0 of 1" in out, "the changed-line counts are wrong: %s" % out)
    code, out, _ = verify(root, ["--coverage", "coverage.json", "--profile", "selected",
                                 "--spec", "specs/demo/spec.md"])
    expect("does not support the claim" in out,
           "a selected profile did not refuse the stronger reading")
    code, _, _ = verify(root, ["--coverage", "coverage.json",
                               "--spec", "specs/demo/spec.md"])
    expect(code == 2, "--coverage without --profile must exit 2, got %d" % code)


def mutation_project(root):
    write(os.path.join(root, "calc.py"),
          "LIMIT = 10 + 0\n\n\n"
          "def add(a, b):\n"
          "    return a + b\n\n\n"
          "def flag(x):\n"
          "    return x and undefined_value\n\n\n"
          "def small(v):\n"
          "    return v < 10\n\n\n"
          "def spread(*args):\n"
          "    return len(args)\n")
    write(os.path.join(root, "tests", "run.py"),
          "import os, sys\n"
          "sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))\n"
          "import calc\n"
          "assert calc.add(2, 3) == 5\n"
          "assert calc.flag(False) is False\n"
          "assert calc.small(9) is True\n"
          "print('3 passed')\n")
    manifest(root, [check("unit", command="python3 tests/run.py", paths=["calc.py"]),
                    check("lint", kind="lint", runner="command",
                          command='python3 -c "print(\'examined=1\')"', paths=["calc.py"])],
             mutation={"limit": 12})
    spec(root, ["SC-001"], evidenced=["SC-001"])
    init_repo(root)
    write(os.path.join(root, "calc.py"),
          "LIMIT = 10 + 0\n\n\ndef add(a, b):\n    return a + b\n\n\ndef flag(x):\n"
          "    return x and undefined_value\n\n\ndef small(v):\n    return v < 10\n\n\n"
          "def spread(*args):\n    return len(args)\n# touch\n")


def case_mutation(root):
    mutation_project(root)
    code, out, _ = verify(root, ["--mutation", "--spec", "specs/demo/spec.md"])
    expect("== mutation ==" in out, "the mutation stage did not report")
    expect("survived-candidate" in out, "no surviving candidate was listed")
    expect("budget:" in out, "the budget line is missing")
    expect("not a threshold" in out, "the budget is not labelled as non-blocking")
    for line in out.splitlines():
        if "SELF-VERIFY" in line:
            expect("%" not in line, "a percentage appeared in the verdict line")


def case_extreme(root):
    mutation_project(root)
    code, out, _ = verify(root, ["--mutation", "--extreme", "--spec", "specs/demo/spec.md"])
    expect("whole-method" in out, "the extreme mode was not labelled less precise")
    expect("extreme" in out, "the extreme mode is not identified in the report")


def case_unmeasured(root):
    write(os.path.join(root, "calc.py"), "def add(a, b):\n    return a + b\n")
    manifest(root, [check("unit", command='python3 -c "import sys; sys.exit(5)"',
                          paths=["calc.py"])], mutation={"limit": 5})
    spec(root, ["SC-001"], evidenced=["SC-001"])
    init_git = init_repo(root)
    write(os.path.join(root, "calc.py"), "def add(a, b):\n    return a - b\n")
    code, out, _ = verify(root, ["--mutation", "--spec", "specs/demo/spec.md"])
    expect("unmeasured" in out, "a module with no tests was not reported unmeasured")


STUB_SEMGREP = os.environ.get("STUB_SEMGREP") or """#!/bin/sh
if [ -n "${STUB_RULE:-}" ]; then
  printf '{"results":[{"check_id":"%s","path":"app.py","start":{"line":3}}]}' "$STUB_RULE"
else
  printf '{"results":[]}'
fi
"""
STUB_GITLEAKS = """#!/bin/sh
out=""
while [ $# -gt 0 ]; do
  if [ "$1" = "--report-path" ]; then out="$2"; fi
  shift
done
if [ -n "${STUB_RULE:-}" ]; then
  printf '[{"RuleID":"%s","File":"app.py","StartLine":5}]' "$STUB_RULE" > "$out"
else
  printf '[]' > "$out"
fi
"""
STUB_TRUFFLEHOG = """#!/bin/sh
if [ -n "${STUB_RULE:-}" ]; then
  printf '{"DetectorName":"%s","Verified":%s,"SourceMetadata":{"Data":{"Filesystem":{"File":"app.py","Line":10}}}}\\n' "$STUB_RULE" "${STUB_VERIFIED:-true}"
fi
"""


def security_project(root, rule=None, verified="true", fail_scan=False):
    stubs = os.path.join(root, "stubs")
    write(os.path.join(stubs, "semgrep"), STUB_SEMGREP)
    write(os.path.join(stubs, "gitleaks"), STUB_GITLEAKS)
    write(os.path.join(stubs, "trufflehog"), STUB_TRUFFLEHOG)
    for name in ("semgrep", "gitleaks", "trufflehog"):
        os.chmod(os.path.join(stubs, name), 0o755)
    if fail_scan:
        write(os.path.join(stubs, "semgrep"), "#!/bin/sh\necho 'internal error' >&2\nexit 2\n")
        os.chmod(os.path.join(stubs, "semgrep"), 0o755)
    write(os.path.join(root, "app.py"), "token = 'x'\n")
    write(os.path.join(root, ".specify", "security", "semgrep.yml"), "rules: []\n")
    manifest(root, [check("lint", kind="lint", runner="command",
                          command='python3 -c "print(\'examined=1\')"', paths=["app.py"])],
             security={"rules": ".specify/security/semgrep.yml",
                       "baseline": ".specify/security/baseline.json"})
    spec(root, ["SC-001"], evidenced=["SC-001"])
    env = dict(os.environ)
    env["PATH"] = stubs + os.pathsep + env.get("PATH", "")
    if rule:
        env["STUB_RULE"] = rule
    env["STUB_VERIFIED"] = verified
    return env


def case_security(root):
    env = security_project(root, rule="planted-rule", verified="false")
    code, out, _ = run([SECURITY, "observe", "--json"], cwd=root, env=env)
    expect(code == 0, "observe must not block on findings, got %d" % code)
    expect(os.path.exists(os.path.join(root, ".specify", "security", "baseline.json")),
           "observe did not record a baseline")
    baseline = json.load(open(os.path.join(root, ".specify", "security", "baseline.json")))
    expect(baseline["counts"].get("planted-rule") >= 1, "the baseline has no per-rule count")

    code, out, _ = run([SECURITY, "block", "--json"], cwd=root, env=env)
    expect(code == 3, "block without --confirm must exit 3, got %d" % code)
    code, out, _ = run([SECURITY, "block", "--json", "--confirm"], cwd=root, env=env)
    expect(code == 0, "a pattern-only match must not block, got %d\n%s" % (code, out))

    fresh = project()
    env2 = security_project(fresh, rule="planted-rule", verified="false")
    code, out, _ = run([SECURITY, "block", "--json", "--confirm"], cwd=fresh, env=env2)
    expect(code == 3, "block without a baseline must refuse, got %d" % code)

    fresh2 = project()
    env3 = security_project(fresh2, rule="AWS", verified="true")
    run([SECURITY, "observe", "--json", "--confirm"], cwd=fresh2, env=env3)
    code, out, _ = run([SECURITY, "block", "--json", "--confirm"], cwd=fresh2, env=env3)
    expect(code == 1, "a confirmed-live credential on a baselined class must block, got %d\n%s"
           % (code, out))
    code, out, _ = run([SECURITY, "block", "--json", "--confirm", "--offline"],
                       cwd=fresh2, env=env3)
    expect(code == 3, "offline block must be not-run, got %d" % code)

    pinned = project()
    write(os.path.join(pinned, ".specify", "verify.json"),
          json.dumps({"version": 1, "security": {"rules": ".specify/security/missing.yml"},
                      "checks": [check("l", kind="lint", runner="command",
                                       command="true", paths=["**"], oracle="declared")]}))
    code, out, _ = run([SECURITY, "observe", "--json"], cwd=pinned, env=env)
    expect(code == 3, "an unpinned rule set must be refused, got %d" % code)

    broken = project()
    env4 = security_project(broken, rule="planted-rule", fail_scan=True)
    code, out, _ = run([SECURITY, "observe", "--json"], cwd=broken, env=env4)
    expect(code == 3, "a tool internal error must be scan-failed, got %d" % code)
    expect("scan-failed" in out, "a tool error was not reported as scan-failed")


def case_criteria(root):
    manifest(root, [check("lint", kind="lint", runner="command",
                          command='python3 -c "print(\'examined=1\')"', paths=["**"])])
    spec(root, ["SC-001", "SC-002", "SC-003"], evidenced=["SC-001"])
    code, out, _ = verify(root, ["--criteria", "--spec", "specs/demo/spec.md"])
    expect(code == 0 and "1/3 evidenced" in out, "the tally is wrong: %s" % out)
    expect("SC-002" in out and "SC-003" in out, "the gaps were not named")
    write(os.path.join(root, "empty.md"), "# Spec\n\nno criteria\n")
    code, out, _ = verify(root, ["--criteria", "--spec", "empty.md"])
    expect(code == 3, "a criteria-free spec must refuse with exit 3, got %d" % code)
    spec(root, ["SC-001"], evidenced=["SC-001"], cite_unknown=True)
    code, out, err = verify(root, ["--criteria", "--spec", "specs/demo/spec.md"])
    expect(code == 2, "an unknown criterion id must exit 2, got %d" % code)
    expect("SC-999" in err, "the unknown criterion id was not named")


def case_manifest_rejected(root):
    manifest(root, [check("dup"), check("dup")])
    spec(root, ["SC-001"])
    code, _, err = verify(root, ["--all", "--spec", "specs/demo/spec.md"])
    expect(code == 2 and "not unique" in err, "a duplicate id was not rejected")
    doc = check("x")
    del doc["oracle"]
    manifest(root, [doc])
    code, _, err = verify(root, ["--all", "--spec", "specs/demo/spec.md"])
    expect(code == 2 and "oracle" in err, "an absent oracle was not rejected")
    manifest(root, [check("p", kind="property", command="true", control="false",
                          falsify='python3 -c "import sys; sys.exit(1)"')])
    code, _, err = verify(root, ["--all", "--spec", "specs/demo/spec.md"])
    expect(code == 2 and "spec_rule" in err, "a property without spec_rule was not rejected")
    manifest(root, [check("prop", kind="property", runner="command",
                          command='python3 -c "print(\'examined=2\')"',
                          falsify='python3 -c "import sys; sys.exit(1)"',
                          spec_rule="total is conserved")])
    code, out, _ = verify(root, ["--all", "--spec", "specs/demo/spec.md"])
    expect("encodes: total is conserved" in out, "the spec rule was not printed with the outcome")


def case_shared_file(root):
    # A glob bounds a private module's effect; it does not bound conftest.py's. Selecting only the
    # checks that name the shared file would run part of a suite whose fixtures all just changed.
    write(os.path.join(root, "src", "a.py"), "x = 1\n")
    write(os.path.join(root, "other", "b.py"), "y = 1\n")
    write(os.path.join(root, "conftest.py"), "# shared fixtures\n")
    manifest(root, [check("unit", command='python3 -c "print(\'1 passed\')"', paths=["src/**"]),
                    check("other", command='python3 -c "print(\'2 passed\')"', paths=["other/**"])])
    spec(root, ["SC-001"], evidenced=["SC-001"])
    init_repo(root)
    write(os.path.join(root, "conftest.py"), "# shared fixtures\nFIXTURE = 2\n")
    code, out, _ = verify(root, ["--spec", "specs/demo/spec.md"])
    expect("fallback:" in out, "a shared-file change did not declare the select-all fallback")
    expect("conftest.py" in out, "the shared file was not named")
    expect("unit, other" in out or "other, unit" in out,
           "a shared-file change did not select every check\n%s" % out)
    expect(code == 0, "the fallback run must pass, got %d\n%s" % (code, out))
    expect("examined=3" in out, "examined was not the whole suite's count")
    # A private module still selects narrowly: the fallback is not a blanket widening.
    git(root, "add", "-A")
    git(root, "commit", "-qm", "shared fixture change")
    write(os.path.join(root, "src", "a.py"), "x = 3\n")
    code, out, _ = verify(root, ["--spec", "specs/demo/spec.md"])
    expect("fallback:" not in out, "a private-module change widened the selection")
    expect("examined=1" in out, "a private-module change did not select narrowly")


CASES = [
    ("shared-file", case_shared_file),
    ("zero-tests", case_zero_tests), ("self-oracle", case_self_oracle),
    ("control-passes", case_control_passes), ("no-control", case_no_control),
    ("clean-control", case_clean_control), ("unmatched", case_unmatched),
    ("flaky", case_flaky), ("merge", case_merge), ("coverage", case_coverage),
    ("mutation", case_mutation), ("extreme", case_extreme), ("unmeasured", case_unmeasured),
    ("security", case_security), ("criteria", case_criteria),
    ("manifest-rejected", case_manifest_rejected),
]


# ---------------------------------------------------------------- properties

def p001():
    rng = random.Random(11)
    cases = 0
    for _ in range(12):
        root = project()
        items = records(rng.randint(1, 8))
        rng.shuffle(items)
        write(os.path.join(root, "ledger.jsonl"),
              "".join(json.dumps(r, sort_keys=True) + "\n" for r in items))
        code, out, _ = run([LEDGER, "read", "--json", "--ledger",
                            os.path.join(root, "ledger.jsonl")], cwd=root)
        expect(code == 0, "read rejected a valid trail")
        keys = [(r["at"], r["id"]) for r in json.loads(out)]
        expect(keys == sorted(keys), "read order is not (at, id)")
        shutil.rmtree(root, ignore_errors=True)
        cases += 1
    return cases


def p002():
    root = project()
    ledger = os.path.join(root, "ledger.jsonl")
    prefix = ""
    for n, rec in enumerate(records(12), 1):
        code, _, err = append(root, rec, ledger=ledger)
        expect(code == 0, "append failed: %s" % err)
        with open(ledger) as fh:
            text = fh.read()
        expect(text.startswith(prefix), "an existing line was rewritten")
        expect(len(text.splitlines()) == n, "the file did not grow by exactly one line")
        prefix = text
    shutil.rmtree(root, ignore_errors=True)
    return 12


def p003():
    cases = [
        ("pytest", 'python3 -c "import sys; sys.exit(5)"', 5, ["SC-001"]),
        ("jest", 'python3 -c "print(\'No tests found\'); import sys; sys.exit(1)"', 1,
         ["SC-001"]),
        ("cargo", 'python3 -c "print(\'running 0 tests\'); print(\'test result: ok. 0 passed; 0 '
                  'failed\')"', 0, ["SC-001"]),
        ("go", 'python3 -c "print(\'?  example/pkg [no test files]\')"', 0, ["SC-001"]),
    ]
    for runner, command, rc, ids in cases:
        root = project()
        manifest(root, [check("c", runner=runner, command=command)])
        spec(root, ids)
        code, verdict, _, _ = verdict_of(root, ["--all", "--spec", "specs/demo/spec.md"])
        expect(verdict != "PASS", "%s: collected nothing but the verdict was PASS" % runner)
        expect(code != 0, "%s: collected nothing but the exit was 0" % runner)
        shutil.rmtree(root, ignore_errors=True)
    return len(cases)


def p004():
    good = 'python3 -c "print(\'1 passed\')"'
    bad = 'python3 -c "print(\'1 failed\'); import sys; sys.exit(1)"'
    skip = 'python3 -c "import sys; sys.exit(127)"'
    combos = [([good], "PASS"), ([good, bad], "FAIL"), ([good, skip], "INCOMPLETE"),
              ([bad, skip], "FAIL"), ([skip], "INCOMPLETE"), ([bad], "FAIL")]
    for commands, expected in combos:
        root = project()
        checks = [check("c%d" % i, command=c) for i, c in enumerate(commands)]
        manifest(root, checks)
        spec(root, ["SC-001"], evidenced=["SC-001"])
        _, verdict, _, _ = verdict_of(root, ["--all", "--spec", "specs/demo/spec.md"])
        expect(verdict == expected, "commands=%r gave %s, expected %s"
               % (commands, verdict, expected))
        if expected == "PASS":
            expect(all("127" not in c for c in commands), "PASS with a command that did not run")
        shutil.rmtree(root, ignore_errors=True)
    return len(combos)


def p005():
    root = project()
    write(os.path.join(root, "src", "a.py"), "x = 1\n")
    write(os.path.join(root, "docs", "b.md"), "b\n")
    manifest(root, [check("unit", paths=["src/**"]),
                    check("docs", kind="lint", runner="command",
                          command='python3 -c "print(\'examined=1\')"', paths=["docs/**"])])
    spec(root, ["SC-001"], evidenced=["SC-001"])
    init_repo(root)
    rng = random.Random(3)
    files = ["src/a.py", "docs/b.md", "notes.txt"]
    seen = 0
    for _ in range(8):
        for name in files:
            path = os.path.join(root, name)
            if os.path.exists(path):
                os.unlink(path)
        chosen = rng.sample(files, rng.randint(1, 3))
        for name in chosen:
            write(os.path.join(root, name), "changed\n")
        git(root, "add", "-A")
        code, verdict, doc, _ = verdict_of(root, ["--spec", "specs/demo/spec.md"])
        changed = doc["report"]["changed"]
        unmatched = doc["report"]["unmatched"]
        expect(sorted(set(changed)) == sorted(set(chosen)),
               "the change set is not the set that changed: %r vs %r" % (changed, chosen))
        for name in chosen:
            matched = name.startswith("src/") or name.startswith("docs/")
            expect(matched or name in unmatched,
                   "%s was neither selected nor named unmatched" % name)
        if unmatched:
            expect(verdict != "PASS", "an unmatched file did not stop a green verdict")
        git(root, "reset", "-q", "--hard", "HEAD")
        seen += 1
    shutil.rmtree(root, ignore_errors=True)
    return seen


def p006():
    rng = random.Random(5)
    cases = 0
    for _ in range(6):
        total = rng.choice([1, 3, 5])
        ids = ["SC-%03d" % n for n in range(1, total + 1)]
        evidenced = sorted(rng.sample(ids, rng.randint(0, total)))
        root = project()
        manifest(root, [check("l", kind="lint", runner="command",
                              command='python3 -c "print(\'examined=1\')"', paths=["**"])])
        spec(root, ids, evidenced=evidenced)
        code, out, _ = verify(root, ["--criteria", "--spec", "specs/demo/spec.md"])
        if not evidenced:
            code, out, _ = verify(root, ["--criteria", "--spec", "specs/demo/spec.md"])
        expect("%d/%d evidenced" % (len(evidenced), total) in out,
               "tally %d/%d not reported: %s" % (len(evidenced), total, out))
        for cid in ids:
            if cid not in evidenced:
                expect(cid in out, "gap %s was not named" % cid)
        shutil.rmtree(root, ignore_errors=True)
        cases += 1
    return cases


def p008():
    for profile, must_refuse in (("full", False), ("selected", True)):
        root = project()
        write(os.path.join(root, "src", "a.py"), "x = 1\n")
        manifest(root, [check("unit", command='python3 -c "print(\'1 passed\')"')])
        spec(root, ["SC-001"], evidenced=["SC-001"])
        init_repo(root)
        write(os.path.join(root, "src", "a.py"), "x = 1\ny = 2\n")
        write(os.path.join(root, "coverage.json"),
              json.dumps({"files": [{"file": "src/a.py", "executed_lines": [1]}]}))
        code, out, _ = verify(root, ["--coverage", "coverage.json", "--profile", profile,
                                     "--spec", "specs/demo/spec.md"])
        expect("profile=%s" % profile in out, "provenance missing for %s" % profile)
        if must_refuse:
            expect("does not support the claim" in out,
                   "a selected profile did not refuse the strong reading")
            expect("no test executes" not in out.lower().replace(
                "does not support the claim that no test executes a line", ""),
                "a selected profile asserted that no test executes a line")
        shutil.rmtree(root, ignore_errors=True)
    return 2


def p009():
    cases = [(None, "true", 0), ("planted-rule", "false", 0), ("AWS", "true", 1),
             ("AWS", "false", 0)]
    for rule, verified, expected in cases:
        root = project()
        env = security_project(root, rule=rule, verified=verified)
        run([SECURITY, "observe", "--json", "--confirm"], cwd=root, env=env)
        code, out, _ = run([SECURITY, "block", "--json", "--confirm"], cwd=root, env=env)
        expect(code == expected, "rule=%r verified=%s blocked with %d, expected %d"
               % (rule, verified, code, expected))
        if expected == 0:
            expect("pattern-only" not in out or "confirmed-live" not in out,
                   "a pattern-only match was labelled confirmed")
        shutil.rmtree(root, ignore_errors=True)
    return len(cases)


def p010():
    root = project()
    mutation_project(root)
    code, out, _ = verify(root, ["--mutation", "--json", "--spec", "specs/demo/spec.md"])
    doc = json.loads(out)
    budget = doc["report"]["mutation"]["budget"]
    expect(budget["equivalent"] >= 1, "the equivalent mutant was not detected")
    expect(budget["unknown"] >= 1, "an unclassified mutant was not labelled unknown")
    for cand in doc["report"]["mutation"]["candidates"]:
        expect(cand["status"] != "equivalent", "an equivalent mutant was listed as a candidate")
    shutil.rmtree(root, ignore_errors=True)
    return 1


def p011():
    root = project()
    mutation_project(root)
    code, out, _ = verify(root, ["--mutation", "--json", "--spec", "specs/demo/spec.md"])
    doc = json.loads(out)
    budget = doc["report"]["mutation"]["budget"]
    expect(budget["killed_assertion"] >= 1, "no assertion kill was classified")
    expect(budget["killed_crash"] >= 1, "no crash kill was classified")
    shutil.rmtree(root, ignore_errors=True)
    return 2


def p012():
    import math
    vectors = [([(5, 5), (5, 5)], 3), ([(5, 5), (4, 5), (3, 5)], 2)]
    for vector, k in vectors:
        arg = ",".join("%d/%d" % pair for pair in vector)
        code, out, _ = run([sys.executable, PASSK, "--vector", arg, "--k", str(k), "--json"])
        expect(code == 0, "passk refused a valid vector")
        doc = json.loads(out)
        mean = sum(c / float(n) for c, n in vector) / len(vector)
        expect(abs(doc["pass@1"] - mean) < 1e-12, "pass@1 is not the mean success rate")
        expect(abs(doc["constant_p_bound"] - mean ** k) < 1e-12,
               "the bound is not (mean pass@1)^k")
        if all(c == n for c, n in vector):
            expect(abs(doc["pass^k"] - doc["constant_p_bound"]) < 1e-12,
                   "a deterministic vector did not produce equal figures")
        expect("difference" in json.dumps(doc) or doc["note"], "the gap was not explained")
    return len(vectors)


PROPERTIES = [("P-001", p001), ("P-002", p002), ("P-003", p003), ("P-004", p004),
              ("P-005", p005), ("P-006", p006), ("P-008", p008), ("P-009", p009),
              ("P-010", p010), ("P-011", p011), ("P-012", p012)]


# ---------------------------------------------------------------- cli

def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        sys.stdout.write(__doc__)
        return 0 if argv else 2
    action = argv[0]
    if action == "--make":
        target = argv[1] if len(argv) > 1 else os.path.join(KIT, "evals", "fixtures", "verify",
                                                            "corpus")
        for name, builder in CASES:
            root = os.path.join(target, name)
            if os.path.isdir(root):
                shutil.rmtree(root)
            os.makedirs(root)
            try:
                if name in ("mutation", "extreme", "unmeasured"):
                    mutation_project(root) if name != "unmeasured" else None
                else:
                    builder(root)
            except Failure:
                pass
            sys.stdout.write("built %s\n" % root)
        return 0
    if action == "--case":
        name = argv[1]
        builders = dict(CASES)
        if name not in builders:
            sys.stderr.write("unknown case '%s'\n" % name)
            return 2
        root = project()
        try:
            builders[name](root)
        except Failure as exc:
            sys.stdout.write("FAIL %s: %s\n" % (name, exc))
            return 1
        finally:
            shutil.rmtree(root, ignore_errors=True)
        sys.stdout.write("ok   case %s\n" % name)
        return 0
    if action == "--property":
        wanted = argv[1]
        found = dict(PROPERTIES).get(wanted)
        if not found:
            sys.stderr.write("unknown property '%s'\n" % wanted)
            return 2
        cases = found()
        sys.stdout.write("ok   %s (%d case(s))\n" % (wanted, cases))
        return 0
    if action == "--all":
        failures = 0
        for name, builder in CASES:
            root = project()
            try:
                builder(root)
                sys.stdout.write("ok   case %s\n" % name)
            except Failure as exc:
                failures += 1
                sys.stdout.write("FAIL case %s: %s\n" % (name, exc))
            finally:
                shutil.rmtree(root, ignore_errors=True)
        for name, found in PROPERTIES:
            try:
                cases = found()
                sys.stdout.write("ok   %s (%d case(s))\n" % (name, cases))
            except Failure as exc:
                failures += 1
                sys.stdout.write("FAIL %s: %s\n" % (name, exc))
        if failures:
            sys.stdout.write("FIXTURES: FAIL (%d)\n" % failures)
            return 1
        sys.stdout.write("FIXTURES: PASS (%d case(s), %d propert(ies))\n"
                         % (len(CASES), len(PROPERTIES)))
        return 0
    sys.stderr.write("unknown action '%s'\n%s" % (action, __doc__))
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
