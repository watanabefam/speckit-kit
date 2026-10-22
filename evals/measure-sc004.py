#!/usr/bin/env python3
"""Measure SC-004: does default verification on a single-file change cost ≤25% of the full suite?

    measure-sc004.py                 run the measurement, print a table, write JSON
    measure-sc004.py --pairs 11      more interleaved pairs
    measure-sc004.py --out FILE      also write the JSON there
    measure-sc004.py --keep DIR      build the fixtures under DIR instead of a temp dir

The measurement is deliberately awkward in ways that make a flattering number harder:

* Both configurations run `bin/speckit-verify`, the same command SC-004 names, so the engine's own
  cost sits in both sides of the ratio. Nothing is subtracted for "startup" — a ratio computed after
  removing a fixed cost is a different claim, and at small suite sizes it is the only reason the
  ratio looks good.
* Pairs are interleaved (full, changed, full, changed, …) rather than run in two blocks, so slow
  drift on a shared machine moves both sides alike.
* One warmup pair is discarded before measuring, because the first run pays for `__pycache__` writes.
* The ratio is reported twice: median of the per-pair ratios (preserves pairing) and ratio of the
  medians (a ratio of marginal summaries). They are not interchangeable, so both are shown.
* Three suite sizes are measured. Selection's benefit is a function of suite size — a fixed
  per-session cost does not shrink with the selection — so one size cannot support a general claim.

Per-test work is real computation rather than a sleep, sized so that test execution dominates
interpreter startup. With negligible per-test cost the ratio measures process startup, not selection.
"""

import argparse
import json
import os
import platform
import shlex
import shutil
import statistics
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
VERIFY = os.path.join(ROOT, "bin", "speckit-verify")
SIZES = (3, 9, 24)
TESTS_PER_MODULE = 4
# ~20ms of real work per test on a current laptop: enough that execution dominates startup.
WORK = 60000


def write(path, text):
    parent = os.path.dirname(path)
    if parent and not os.path.isdir(parent):
        os.makedirs(parent)
    with open(path, "w") as fh:
        fh.write(text)


def run(cmd, cwd, env=None):
    return subprocess.Popen(cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            universal_newlines=True, env=env)


def timed(cmd, cwd, env=None):
    started = time.monotonic()
    proc = run(cmd, cwd, env)
    out, err = proc.communicate()
    return time.monotonic() - started, proc.returncode, (out or "") + (err or "")


def git(root, *args):
    proc = run(["git"] + list(args), root)
    proc.communicate()


def build(root, modules, python):
    """A project with `modules` independent modules, one check per module, one git commit."""
    py = shlex.quote(python)
    write(os.path.join(root, "pyproject.toml"), "[tool.pytest.ini_options]\naddopts = \"-q\"\n")
    # Without this, the first pytest run's `__pycache__`/.pytest_cache become untracked changed
    # files and every later run is INCOMPLETE ("matched by no check") — correctly so. A real
    # project ignores its build caches; the fixture has to as well.
    write(os.path.join(root, ".gitignore"), "__pycache__/\n.pytest_cache/\n*.pyc\n")
    checks = []
    for n in range(modules):
        name = "mod_%02d" % n
        write(os.path.join(root, "src", name + ".py"), "def value():\n    return %d\n" % n)
        body = ["import hashlib", "import sys", "", "sys.path.insert(0, 'src')",
                "from %s import value" % name, ""]
        for t in range(TESTS_PER_MODULE):
            body += [
                "",
                "def test_%s_%d():" % (name, t),
                "    digest = hashlib.pbkdf2_hmac('sha256', b'%s', b'%d', %d)" % (name, t, WORK),
                "    assert digest and value() == %d" % n,
            ]
        write(os.path.join(root, "tests", "test_%s.py" % name), "\n".join(body) + "\n")
        checks.append({
            "id": name.replace("_", "-"),
            "kind": "test",
            "runner": "pytest",
            "command": "%s -m pytest tests/test_%s.py" % (py, name),
            "paths": ["src/%s.py" % name],
            "oracle": "spec",
            "control": '%s -c "import sys; sys.exit(1)"' % py,
        })
    write(os.path.join(root, ".specify", "verify.json"),
          json.dumps({"version": 1, "checks": checks}, indent=2))
    # A real project has a spec, and a run with no located spec is INCOMPLETE by design, so the
    # fixture carries one criterion with its evidence rather than timing an incomplete run.
    write(os.path.join(root, "specs", "demo", "spec.md"),
          "# Spec\n\n## Success Criteria\n\n- **SC-001**: every module's value is stable\n")
    write(os.path.join(root, "specs", "demo", "progress.md"),
          "# Progress\n\n- Task 1: complete ([SC-001] fixture evidence)\n")
    git(root, "init", "-q", ".")
    git(root, "config", "user.email", "measure@example.com")
    git(root, "config", "user.name", "measure")
    git(root, "add", "-A")
    git(root, "commit", "-qm", "base")
    # The single changed file the criterion talks about. The edit is behaviour-preserving: a
    # timing taken over a failing run would measure short-circuiting, not selection.
    write(os.path.join(root, "src", "mod_00.py"),
          "TABLE = {}\n\n\ndef value():\n    return 0\n")
    return len(checks)


def examined_of(out):
    for token in out.split():
        if token.startswith("examined="):
            return int(token.split("=", 1)[1])
    return None


def measure(root, pairs, env):
    full, changed = [], []
    verdicts = set()
    examined = {"full": None, "changed": None}
    for index in range(pairs + 1):          # the first pair is the discarded warmup
        t_full, code_full, out_full = timed([VERIFY, "--all"], root, env)
        t_changed, code_changed, out_changed = timed([VERIFY], root, env)
        if index == 0:
            continue
        for code, out in ((code_full, out_full), (code_changed, out_changed)):
            verdicts.add("PASS" if "SELF-VERIFY: PASS" in out else "code=%d" % code)
        examined["full"] = examined_of(out_full)
        examined["changed"] = examined_of(out_changed)
        full.append(t_full)
        changed.append(t_changed)
    pair_ratios = [c / f for f, c in zip(full, changed)]
    return {
        "pairs": pairs,
        "full": {"median": statistics.median(full), "min": min(full), "max": max(full)},
        "changed": {"median": statistics.median(changed), "min": min(changed), "max": max(changed)},
        "ratio_median_pairs": statistics.median(pair_ratios),
        "ratio_of_medians": statistics.median(changed) / statistics.median(full),
        "ratio_min": min(pair_ratios),
        "ratio_max": max(pair_ratios),
        "examined_full": examined["full"],
        "examined_changed": examined["changed"],
        "verdicts": sorted(verdicts),
    }


def main(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--pairs", type=int, default=7)
    ap.add_argument("--sizes", default=",".join(str(s) for s in SIZES),
                    help="comma-separated check counts to measure")
    ap.add_argument("--out")
    ap.add_argument("--keep")
    ap.add_argument("--python", default=sys.executable,
                    help="interpreter that has pytest; also put first on the engine's PATH")
    args = ap.parse_args(argv)
    env = dict(os.environ)
    env["PATH"] = os.path.dirname(args.python) + os.pathsep + env.get("PATH", "")

    sizes = [int(s) for s in args.sizes.split(",") if s.strip()]
    base = args.keep or tempfile.mkdtemp(prefix="sc004-")
    report = {
        "criterion": "SC-004: default verification on a single-file change ≤25% of full-suite time",
        "command": "bin/speckit-verify --all  vs  bin/speckit-verify (changed)",
        "host": {
            "python": platform.python_version(),
            "runner": subprocess.run([args.python, "-m", "pytest", "--version"],
                                     stdout=subprocess.PIPE, universal_newlines=True
                                     ).stdout.strip(),
            "platform": platform.platform(),
            "cpus": os.cpu_count(),
            "loadavg": [round(x, 2) for x in os.getloadavg()],
        },
        "work_per_test": WORK,
        "tests_per_module": TESTS_PER_MODULE,
        "sizes_measured": sizes,
        "sizes": {},
    }
    for size in sizes:
        root = os.path.join(base, "suite-%02d" % size)
        shutil.rmtree(root, ignore_errors=True)
        checks = build(root, size, args.python)
        result = measure(root, args.pairs, env)
        result["checks"] = checks
        report["sizes"][str(size)] = result
        report["host"].setdefault("loadavg_after", [round(x, 2) for x in os.getloadavg()])

    print("SC-004 measurement — bin/speckit-verify, %d interleaved pairs, 1 warmup discarded"
          % args.pairs)
    print("%-6s %-8s %-9s %-9s %-9s %-9s %s"
          % ("checks", "full", "changed", "ratio", "ratio", "selected", "verdicts"))
    print("%-6s %-8s %-9s %-9s %-9s %-9s %s"
          % ("", "median s", "median s", "pairs", "medians", "tests", ""))
    for size in sizes:
        r = report["sizes"][str(size)]
        selected = ("%s/%s" % (r["examined_changed"], r["examined_full"])
                    if r["examined_changed"] is not None else "?")
        print("%-6d %-8.3f %-9.3f %-9.3f %-9.3f %-9s %s"
              % (r["checks"], r["full"]["median"], r["changed"]["median"],
                 r["ratio_median_pairs"], r["ratio_of_medians"], selected,
                 ",".join(r["verdicts"])))
    print("\nread: the ratio is ~1/checks plus a fixed cost, so it is a function of suite size —")
    print("the criterion is met above the size where that fixed cost stops dominating.")

    data = json.dumps(report, indent=2, sort_keys=True)
    if args.out:
        write(args.out, data + "\n")
    sys.stdout.write(data + "\n")
    if not args.keep:
        shutil.rmtree(base, ignore_errors=True)
    bad = [v for size in sizes for v in report["sizes"][str(size)]["verdicts"] if v != "PASS"]
    if bad:
        sys.stderr.write("a measured run was not PASS (%s): the timings describe a failing run\n"
                         % ", ".join(sorted(set(bad))))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
