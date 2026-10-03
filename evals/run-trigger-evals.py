#!/usr/bin/env python3
"""Trigger-accuracy evals for the spec-driven-development skill.

Runs each query through the real agent and checks whether the skill was actually
loaded. Per Anthropic, a skill that fails to trigger does so *silently* - there is
no error, the agent just handles the task itself. So trigger rate is the primary
quality metric, and it can only be measured by running real queries.

METHOD (this matters - a single run per query is not a measurement):
  - Each query runs `--runs` times (default 3).
  - A query is judged to have "triggered" when it fires in >= `--threshold`
    (default 0.5) of its runs. This mirrors skill-creator's run_loop.py, which
    calls run_eval(runs_per_query=3, trigger_threshold=0.5).
  - A query PASSES when its triggered verdict matches should_trigger.
    So a should-trigger query passes at 2/3, and a should-not-trigger query
    passes unless it fires in half or more of its runs.

  With one run per query, a rate swings wildly between runs and individual
  queries flip in both directions - which is exactly what happened on the first
  two measurements of this skill (60% then 45%). Do not draw conclusions from
  --runs 1.

Detection uses the same signal verified during the build: the agent's skill tool
call, which surfaces in the transcript as  -> Skill "spec-driven-development"

Usage:
  run-trigger-evals.py [--spec-kit-repo PATH] [--plain-repo PATH]
                       [--runs N] [--threshold F] [--model M]
                       [--only st|snt] [--dry-run]

If --spec-kit-repo is omitted, a scratch repo is created and speckit-init is run
on it, so a run is self-contained (as CI needs).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import select
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
EVALS = HERE / "trigger-evals.json"
SKILL = "spec-driven-development"
ANSI = re.compile(r"\x1b\[[0-9;]*m")

# The skill tool call as it appears in the transcript. Verified during the build.
DETECT = re.compile(r'Skill\s+"' + re.escape(SKILL) + r'"')


def run(cmd, cwd, timeout, detect=DETECT):
    """Run the agent, streaming output. Returns (fired, seconds, timed_out).

    Two things matter here, both learned the hard way:

    1. KILL THE WHOLE PROCESS GROUP. opencode spawns children that inherit the
       stdout pipe. A plain subprocess timeout returns to us but the pipe stays
       open, so reading it blocks forever. One trigger run was observed sitting
       for over three hours because of exactly this - which would hang CI
       indefinitely. start_new_session puts the child in its own group so
       killpg takes the descendants with it.

    2. RETURN AS SOON AS THE SKILL IS DETECTED. The model decides whether to
       consult the skill early, so there is no reason to wait for it to finish
       the whole task just to learn that it loaded. Detected runs return in
       seconds; only "silent" runs wait for the timeout, because confirming a
       skill never loaded requires letting the run play out.

    Reads are guarded by select() so a run that produces no output still
    respects the deadline.
    """
    t0 = time.time()
    p = subprocess.Popen(
        cmd, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
        bufsize=0, start_new_session=True,
    )
    fired = False
    timed_out = False
    seen = ""
    deadline = t0 + timeout
    try:
        fd = p.stdout.fileno()
        while True:
            remaining = deadline - time.time()
            if remaining <= 0:
                timed_out = True
                break
            ready, _, _ = select.select([fd], [], [], remaining)
            if not ready:
                timed_out = True
                break
            try:
                chunk = os.read(fd, 65536)
            except OSError:
                break
            if not chunk:           # EOF: the agent finished on its own
                break
            # Raw bytes, never readline(): the agent streams output that is not
            # newline-delimited, and readline() blocks forever on a partial line.
            seen += ANSI.sub("", chunk.decode("utf-8", "replace"))
            if detect.search(seen):  # search the whole stream so the marker may span chunks
                fired = True
                break
    finally:
        if p.poll() is None:
            try:
                os.killpg(os.getpgid(p.pid), signal.SIGKILL)
            except Exception:
                try:
                    p.kill()
                except Exception:
                    pass
        try:
            p.wait(timeout=10)
        except Exception:
            pass
        try:
            if p.stdout is not None:
                p.stdout.close()
        except Exception:
            pass
    return fired, time.time() - t0, timed_out


def make_spec_kit_repo() -> str:
    d = tempfile.mkdtemp(prefix="speckit-eval-")
    subprocess.run(["git", "init", "-q", "."], cwd=d, check=True)
    Path(d, "README.md").write_text("# scratch\n")
    subprocess.run(["git", "add", "-A"], cwd=d, check=True)
    subprocess.run(
        ["git", "-c", "user.email=e@e", "-c", "user.name=e", "commit", "-qm", "init"],
        cwd=d, check=True,
    )
    r = subprocess.run(["speckit-init", d], capture_output=True, text=True)
    if r.returncode != 0 or not Path(d, ".specify").is_dir():
        sys.exit(f"could not prepare a spec-kit repo via speckit-init:\n{r.stdout}\n{r.stderr}")
    return d


def make_plain_repo() -> str:
    d = tempfile.mkdtemp(prefix="plain-eval-")
    subprocess.run(["git", "init", "-q", "."], cwd=d, check=True)
    Path(d, "README.md").write_text("# plain repo\n")
    return d


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--spec-kit-repo")
    ap.add_argument("--plain-repo")
    ap.add_argument("--runs", type=int, default=3, help="runs per query; 1 is NOT a measurement")
    ap.add_argument("--threshold", type=float, default=0.5, help="trigger verdict at this fire-rate (0.5 = 2/3)")
    ap.add_argument("--model")
    ap.add_argument("--only", choices=["st", "snt"])
    ap.add_argument("--timeout", type=int, default=150,
                    help="per-run cap; the trigger decision is early, so this only bounds silent runs")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    spec = json.loads(EVALS.read_text())
    groups = [("should_trigger", "st"), ("should_not_trigger", "snt")]

    if a.dry_run:
        for group, tag in groups:
            if a.only and a.only != tag:
                continue
            for q in spec[group]:
                print(f"{q['id']:8} [{q['context']:8}] {q['query']}")
        return 0

    if a.runs < 2:
        print("!! NOTE: --runs 1 is not a measurement. A single run cannot distinguish a\n"
              "!!       reliable trigger from a coin flip. Use --runs 3.\n", file=sys.stderr)

    temp = []
    try:
        spec_repo = a.spec_kit_repo or make_spec_kit_repo()
        plain_repo = a.plain_repo or make_plain_repo()
        if not a.spec_kit_repo:
            temp.append(spec_repo)
        if not a.plain_repo:
            temp.append(plain_repo)
        if not Path(spec_repo, ".specify").is_dir():
            sys.exit(f"--spec-kit-repo has no .specify/: {spec_repo}")

        dirs = {"spec-kit": spec_repo, "plain": plain_repo}
        print(f"spec-kit repo: {spec_repo}")
        print(f"plain repo:    {plain_repo}")
        print(f"runs/query: {a.runs}   threshold: {a.threshold} "
              f"(a query 'triggers' at >= {a.threshold:.0%} of runs)\n")

        cmd_base = ["opencode", "run"] + (["--model", a.model] if a.model else [])

        summary = {}
        for group, tag in groups:
            if a.only and a.only != tag:
                continue
            want = group == "should_trigger"
            print(f"== {'should trigger' if want else 'should NOT trigger'} ==")
            passed = 0
            for q in spec[group]:
                fired = runs = 0
                for i in range(a.runs):
                    runs += 1
                    hit, secs, timed_out = run(cmd_base + [q["query"]], dirs[q["context"]], a.timeout)
                    fired += hit
                    note = " (timed out -> counted as silent)" if timed_out else ""
                    print(f"     {q['id']} run {i+1}/{a.runs} "
                          f"{'fired ' if hit else 'silent'} ({secs:.0f}s){note}")
                triggered = (fired / runs) >= a.threshold
                ok = triggered == want
                passed += ok
                mark = "ok" if ok else "XX"
                print(f"  {mark} {q['id']} [{q['context']:8}] {fired}/{runs} fired -> "
                      f"{'triggers' if triggered else 'silent'}  {q['query'][:48]}")
                if not ok and want:
                    print(f"       MISSED: should have triggered")
                if not ok and not want:
                    print(f"       FALSE TRIGGER: {q.get('why','')}")
            summary[group] = (passed, len(spec[group]))
            print(f"  -> {passed}/{len(spec[group])} queries correct\n")

        print("=" * 60)
        for group, (p, t) in summary.items():
            label = "should trigger" if group == "should_trigger" else "should NOT trigger"
            print(f"  {label:20} {p}/{t}  ({p/t*100:.0f}%)")
        good = all(p == t for p, t in summary.values())
        if not good:
            print("\n  FAIL - see failures above.")
        else:
            print("\n  PASS")
        return 0 if good else 1
    finally:
        for d in temp:
            shutil.rmtree(d, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
