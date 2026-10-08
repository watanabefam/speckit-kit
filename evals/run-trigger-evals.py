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
    # `cwd=` alone is NOT enough. opencode resolves the project from the PWD
    # environment variable, not from the process's actual working directory, so a
    # subprocess started with cwd=<target> still runs in whatever directory the
    # PARENT was in. This silently ran every eval in the launching repo instead of
    # the intended context repo — which meant the "plain" (no .specify/) context was
    # never plain, because the launcher was a Spec Kit repo. Set PWD explicitly.
    env = dict(os.environ, PWD=cwd)
    p = subprocess.Popen(
        cmd, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
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
    ap.add_argument("--threshold", type=float, default=0.5, help="per-query trigger verdict at this fire-rate (0.5 = 2/3, the documented default)")
    ap.add_argument("--gate", type=float, default=None,
                    help="optional: exit non-zero if the should-trigger rate is below this. "
                         "Off by default — a miss is a probability, not a defect, and gating on it "
                         "invites tuning the description to the test set.")
    ap.add_argument("--model")
    ap.add_argument("--only", choices=["st", "snt"])
    ap.add_argument("--only-ids", help="comma-separated query ids, e.g. st-06,st-08. "
                    "Use when re-testing a description fix on just the queries that missed.")
    ap.add_argument("--timeout", type=int, default=300,
                    help="per-run cap. It only bounds runs that never emit the marker; "
                         "too low and slow models get wrongly scored as misses.")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    spec = json.loads(EVALS.read_text())
    groups = [("should_trigger", "st"), ("should_not_trigger", "snt")]
    keep = {s.strip() for s in a.only_ids.split(",")} if a.only_ids else None

    if a.dry_run:
            for group, tag in groups:
                if a.only and a.only != tag:
                    continue
                for q in spec[group]:
                    if keep and q["id"] not in keep:
                        continue
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
            n_timeouts = 0
            judged_queries = 0
            for q in spec[group]:
                if keep and q["id"] not in keep:
                    continue
                judged_queries += 1
                fired = counted = 0
                for i in range(a.runs):
                    hit, secs, timed_out = run(cmd_base + [q["query"]], dirs[q["context"]], a.timeout)
                    if timed_out:
                        # A timeout is NOT evidence the skill did not load. The model may
                        # simply be slow. Counting it as "silent" conflates slow with missed
                        # and silently understates the trigger rate -- it did exactly that
                        # before this was fixed. Excluded from the verdict, reported loudly.
                        n_timeouts += 1
                        print(f"     {q['id']} run {i+1}/{a.runs} "
                              f"{'fired ' if hit else 'timeout'} ({secs:.0f}s) (TIMED OUT - excluded)")
                        continue
                    fired += hit
                    counted += 1
                    print(f"     {q['id']} run {i+1}/{a.runs} "
                          f"{'fired ' if hit else 'silent'} ({secs:.0f}s)")
                if counted == 0:
                    print(f"  ?? {q['id']} [{q['context']:8}] all {a.runs} runs timed out "
                          f"- raise --timeout to judge this query")
                    continue
                rate = fired / counted
                triggered = rate >= a.threshold
                ok = triggered == want
                passed += ok
                mark = "ok" if ok else "XX"
                print(f"  {mark} {q['id']} [{q['context']:8}] {fired}/{counted} fired "
                      f"({rate:.0%}) -> {'triggers' if triggered else 'silent'}  {q['query'][:44]}")
                if not ok and want:
                    print("       MISSED: should have triggered")
                if not ok and not want:
                    print(f"       FALSE TRIGGER: {q.get('why','')}")
            total = judged_queries
            summary[group] = (passed, total)
            print(f"  -> {passed}/{total} queries correct\n")

        print("=" * 60)
        for group, (p, t) in summary.items():
            label = "should trigger" if group == "should_trigger" else "should NOT trigger"
            print(f"  {label:20} {p}/{t}  ({p/t*100:.0f}%)")

        st_p, st_t = summary.get("should_trigger", (0, 0))
        snt_p, snt_t = summary.get("should_not_trigger", (0, 0))
        st_rate = st_p / st_t if st_t else 1.0
        false_triggers = snt_t - snt_p

        # Exit semantics. These two sets are NOT the same kind of thing, and treating
        # them alike is what makes a probabilistic metric into a bad gate:
        #
        #   should-NOT-trigger firing is a DEFECT. The skill loaded where its stated
        #   precondition says it must not. That is a correctness failure and it fails
        #   the run.
        #
        #   should-trigger missing is a PROBABILITY. The model decided it could handle
        #   the task without the skill — often a legitimate call, and for a skill whose
        #   job is "decide how much process this needs", misses are partly by design.
        #   It is reported, not failed, because a hard gate on a probabilistic number
        #   invites teaching the description to the test set.
        #
        # The 90% is Anthropic's aspirational example benchmark, not a requirement.
        # Pass --gate <rate> to enforce a threshold anyway.
        if a.gate is not None:
            print(f"\n  should-trigger {st_rate:.0%} vs --gate {a.gate:.0%}")
        else:
            print(f"\n  should-trigger {st_rate:.0%} (aspirational benchmark ~90%; not a gate)")

        if n_timeouts:
            print(f"\n  WARNING: {n_timeouts} run(s) timed out at --timeout {a.timeout}s and were"
                  "\n           EXCLUDED from the scores above, not counted as misses."
                  "\n           Re-run with a higher --timeout before quoting a number.")

        problems = []
        if false_triggers:
            problems.append(f"{false_triggers} false trigger(s) — the skill fired where it must not")
        if n_timeouts:
            problems.append(f"{n_timeouts} timeout(s) — sample contaminated, re-run")
        if a.gate is not None and st_rate < a.gate:
            problems.append(f"should-trigger {st_rate:.0%} below --gate {a.gate:.0%}")

        if problems:
            print("\n  FAIL - " + "; ".join(problems))
            return 1
        print("\n  PASS - no false triggers" +
              ("" if n_timeouts else ", sample clean"))
        return 0
    finally:
        for d in temp:
            shutil.rmtree(d, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
