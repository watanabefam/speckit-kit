#!/usr/bin/env python3
"""Trigger-accuracy evals for the spec-driven-development skill.

Runs each query through the real agent and checks whether the skill was actually
loaded. Per Anthropic, a skill that fails to trigger does so *silently* - there is
no error, the agent just handles the task itself. So trigger rate is the primary
quality metric, and it can only be measured by running real queries.

Detection uses the same signal verified during the build: the agent's skill tool
call, which surfaces in the transcript as  -> Skill "spec-driven-development"

Usage:
  run-trigger-evals.py [--spec-kit-repo PATH] [--plain-repo PATH]
                       [--runs N] [--model M] [--only st|snt] [--dry-run]

If --spec-kit-repo is omitted, a scratch repo is created and speckit-init is run
on it, so a run is self-contained (as CI needs).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import shutil
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


def run(cmd, cwd, timeout):
    p = subprocess.run(
        cmd, cwd=cwd, capture_output=True, text=True, timeout=timeout,
    )
    return p.returncode, ANSI.sub("", p.stdout + p.stderr)


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
    ap.add_argument("--runs", type=int, default=1, help="runs per query (3 gives a reliable rate)")
    ap.add_argument("--model")
    ap.add_argument("--only", choices=["st", "snt"], help="run only should-trigger / should-not-trigger")
    ap.add_argument("--timeout", type=int, default=300)
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    spec = json.loads(EVALS.read_text())
    targets = {"should_trigger": "st", "should_not_trigger": "snt"}

    if a.dry_run:
        for group, tag in targets.items():
            if a.only and a.only != tag:
                continue
            for q in spec[group]:
                print(f"{q['id']:8} [{q['context']:8}] {q['query']}")
        return 0

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
        print(f"runs/query:    {a.runs}{'  model: ' + a.model if a.model else ''}\n")

        cmd_base = ["opencode", "run"]
        if a.model:
            cmd_base += ["--model", a.model]

        summary = {}
        for group, tag in targets.items():
            if a.only and a.only != tag:
                continue
            want = group == "should_trigger"
            hits = 0
            total = 0
            print(f"== {'should trigger' if want else 'should NOT trigger'} ==")
            for q in spec[group]:
                got = 0
                for i in range(a.runs):
                    total += 1
                    t0 = time.time()
                    try:
                        _, out = run(cmd_base + [q["query"]], dirs[q["context"]], a.timeout)
                        fired = bool(DETECT.search(out))
                    except subprocess.TimeoutExpired:
                        fired = False
                        print(f"   !! {q['id']} timed out after {a.timeout}s")
                    got += fired
                    hits += fired
                    mark = "ok" if fired == want else "XX"
                    print(f"  {mark} {q['id']} [{q['context']:8}] run {i+1}/{a.runs} "
                          f"{'fired' if fired else 'silent'} ({time.time()-t0:.0f}s)  {q['query'][:54]}")
                    if not fired and not want:
                        pass
                    elif not fired and want:
                        print(f"       why it matters: this query should have loaded the skill")
                if got == 0 and want:
                    print(f"       MISS: {q.get('query','')[:70]}")
                if got > 0 and not want:
                    print(f"       FALSE TRIGGER: {q.get('why','')}")
            rate = (hits / total * 100) if total else 0.0
            summary[group] = (hits, total, rate)
            print(f"  -> {hits}/{total} = {rate:.0f}%\n")

        print("=" * 58)
        for group, (h, t, r) in summary.items():
            label = "should trigger" if group == "should_trigger" else "should NOT trigger"
            print(f"  {label:20} {h}/{t}  {r:.0f}%")
        good = True
        if "should_trigger" in summary:
            h, t, r = summary["should_trigger"]
            if r < 90:
                print("\n  FAIL: should-trigger rate is below the 90% target")
                good = False
        if "should_not_trigger" in summary:
            h, t, r = summary["should_not_trigger"]
            if h > 0:
                print(f"\n  FAIL: {h} false trigger(s) - the description is too broad")
                good = False
        print("\n  PASS" if good else "\n  See failures above.")
        return 0 if good else 1
    finally:
        for d in temp:
            shutil.rmtree(d, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
