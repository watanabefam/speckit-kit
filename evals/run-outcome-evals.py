#!/usr/bin/env python3
"""Outcome evals — does the skill change what the agent DOES?

The trigger eval answers "did the skill load?". This answers the question that
actually matters: "having loaded, did it change the outcome?" A skill can fire 100%
of the time and change nothing, and a trigger-only eval cannot tell you that.

Method (per the official authoring guidance): each scenario declares
`expected_behavior` and `failure_signals`; the agent runs the query in a prepared
fixture; the transcript is judged against the rubric. Guidance also warns these are
rubrics, not proofs — an LLM judge is a measurement, and it is stated as one.

Two things are checked without the judge, because they are cheap and unambiguous:
  - did a file that must survive still exist afterwards (fixture `must_survive`)?
  - did a directory that must not appear get created (fixture `must_not_exist`)?

Usage:
  run-outcome-evals.py                     # all scenarios
  run-outcome-evals.py --scenario NAME     # one
  run-outcome-evals.py --model M --judge-model M2
  run-outcome-evals.py --keep              # keep scratch repos for inspection
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
EVALS = HERE / "skill-evals.json"
KIT = HERE.parent
INIT = KIT / "bin" / "speckit-init"

DEFAULT_TIMEOUT = 420


def run_agent(prompt: str, cwd: str, model: str, timeout: int) -> tuple[str, bool]:
    """Run opencode, return (output, timed_out). Process-group kill, no orphans."""
    cmd = ["opencode", "run"]
    if model:
        cmd += ["--model", model]
    cmd.append(prompt)
    # opencode resolves the project from $PWD, not from the process working directory.
    # Without this, `cwd=` is ignored and the agent runs in whatever directory the
    # parent was in — silently evaluating the wrong repository. See the same note in
    # run-trigger-evals.py.
    env = dict(os.environ, PWD=cwd)
    try:
        p = subprocess.Popen(cmd, cwd=cwd, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             text=True, start_new_session=True)
    except FileNotFoundError:
        return ("opencode not found on PATH", True)
    try:
        out, _ = p.communicate(timeout=timeout)
        return (out or "", False)
    except subprocess.TimeoutExpired:
        try:
            os.killpg(os.getpgid(p.pid), 15)
        except Exception:
            pass
        try:
            out, _ = p.communicate(timeout=15)
        except Exception:
            p.kill()
            out = ""
        return (out or "", True)


JUDGE_PROMPT = """You are grading an agent transcript against a rubric. Be strict and literal.

EXPECTED BEHAVIOUR (each must be satisfied):
{expected}

FAILURE SIGNALS (any one means FAIL):
{failures}

TRANSCRIPT:
<transcript>
{transcript}
</transcript>

Return ONLY JSON, no prose, in exactly this shape:
{{"expected_met": [true/false, ...], "failure_hit": [true/false, ...], "reason": "<one sentence>"}}

"expected_met" must have exactly {n_expected} booleans, in order.
"failure_hit" must have exactly {n_fail} booleans, in order.
Judge only what the transcript shows. If the transcript is empty or the agent never
responded, mark everything false and the reason "no transcript"."""


def judge(transcript: str, scenario: dict, model: str, timeout: int) -> dict | None:
    prompt = JUDGE_PROMPT.format(
        expected="\n".join(f"  {i+1}. {e}" for i, e in enumerate(scenario["expected_behavior"])),
        failures="\n".join(f"  {i+1}. {f}" for i, f in enumerate(scenario["failure_signals"])),
        transcript=transcript[:20000],
        n_expected=len(scenario["expected_behavior"]),
        n_fail=len(scenario["failure_signals"]),
    )
    out, _ = run_agent(prompt, tempfile.gettempdir(), model, timeout)
    m = re.search(r"\{.*\}", out, re.S)
    if not m:
        return None
    try:
        return json.loads(m.group(0))
    except Exception:
        return None


def skill_loaded(transcript: str, skill: str = "spec-driven-development") -> bool:
    """Same signal the trigger eval uses: the transcript's `-> Skill "<name>"` line."""
    return re.search(rf'->\s*Skill\s+"{re.escape(skill)}"', transcript) is not None


def build_fixture(scenario: dict, root: str) -> None:
    fx = scenario.get("fixture", {})
    subprocess.run(["git", "init", "-q", "."], cwd=root, check=False)
    for rel, content in fx.get("files", {}).items():
        p = Path(root, rel)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(content)
    if fx.get("speckit_init") and INIT.is_file():
        subprocess.run([str(INIT), "."], cwd=root, capture_output=True, text=True, check=False)
    subprocess.run(["git", "add", "-A"], cwd=root, check=False)
    subprocess.run(["git", "-c", "user.email=e@e", "-c", "user.name=e", "commit", "-qm", "init"],
                   cwd=root, capture_output=True, check=False)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenario")
    ap.add_argument("--model", default="opencode/space-bunny-free")
    ap.add_argument("--judge-model", default=None, help="defaults to --model")
    ap.add_argument("--timeout", type=int, default=DEFAULT_TIMEOUT)
    ap.add_argument("--keep", action="store_true")
    ap.add_argument("--bare", action="store_true",
                    help="run the query WITHOUT invoking /speckit. Measures triggering, "
                         "not guidance — only use to reproduce a trigger failure.")
    a = ap.parse_args()

    judge_model = a.judge_model or a.model
    scenarios = json.loads(EVALS.read_text())
    if a.scenario:
        scenarios = [s for s in scenarios if s["name"] == a.scenario]
        if not scenarios:
            sys.exit(f"no scenario named {a.scenario!r}")

    print(f"outcome evals · {len(scenarios)} scenario(s) · model={a.model}\n")
    results = []
    temp = []
    try:
        for sc in scenarios:
            root = tempfile.mkdtemp(prefix=f"outcome-{sc['name'][:20]}-")
            temp.append(root)
            print(f"== {sc['name']}")
            print(f"   targets: {sc['targets']}")
            build_fixture(sc, root)
            # Run the query THROUGH the workflow, not bare.
            #
            # This is the whole point of separating the two evals. A bare query
            # re-measures triggering: on a small fix the skill often does not load
            # (by design — the trigger set says trivial queries are not valid
            # should-trigger cases), and then a rubric that asks for skill-dependent
            # behaviour like "states the chosen workflow" is unanswerable. Forcing the
            # workflow in via the deterministic entry point means this eval measures
            # GUIDANCE: given the workflow is in play, does behaviour match the rubric?
            #
            # Triggering is measured by run-trigger-evals.py. Do not conflate them.
            prompt = sc["query"]
            if not a.bare:
                prompt = ("Invoke the /speckit command (read .opencode/commands/speckit.md and "
                          "follow it) for this request:\n\n" + sc["query"])
            t0 = time.time()
            out, timed_out = run_agent(prompt, root, a.model, a.timeout)
            secs = time.time() - t0
            loaded = skill_loaded(out) or not a.bare
            print(f"   ran {secs:.0f}s{' (TIMED OUT)' if timed_out else ''}"
                  f" · workflow {'IN PLAY' if not a.bare else ('skill loaded' if loaded else 'not loaded')}")

            # Save the transcript so a failure can be investigated rather than guessed at.
            if a.keep:
                Path(root, "_transcript.txt").write_text(out)

            # Distinguish the two ways this can fail. They need different fixes:
            #   skill did not load  -> a TRIGGER problem (description / harness)
            #   skill loaded, rubric failed -> a GUIDANCE problem (the skill's content)
            # Without this split, an outcome failure is uninterpretable.
            if a.bare and not loaded and not timed_out:
                print("   NOTE: skill did not load — a rubric failure here is a TRIGGER"
                      " problem, not a guidance problem.")

            fx = sc.get("fixture", {})
            det_fail = []
            for rel in fx.get("must_survive", []):
                if not Path(root, rel).exists():
                    det_fail.append(f"{rel} was deleted (must survive)")
            for rel in fx.get("must_not_exist", []):
                if Path(root, rel).exists():
                    det_fail.append(f"{rel} was created (must not exist)")

            verdict = judge(out, sc, judge_model, a.timeout)
            if verdict is None:
                print("   JUDGE: no parseable verdict — INCONCLUSIVE")
                results.append((sc["name"], None, loaded))
                continue

            met = verdict.get("expected_met", [])
            hit = verdict.get("failure_hit", [])
            passed = bool(met) and all(met) and not any(hit) and not det_fail and not timed_out

            for i, e in enumerate(sc["expected_behavior"]):
                mark = "ok " if i < len(met) and met[i] else "XX "
                print(f"   {mark} {e}")
            for i, f in enumerate(sc["failure_signals"]):
                if i < len(hit) and hit[i]:
                    print(f"   XX  (failure signal) {f}")
            for d in det_fail:
                print(f"   XX  (deterministic) {d}")
            if verdict.get("reason"):
                print(f"   judge: {verdict['reason']}")
            kind = "TRIGGER" if (a.bare and not loaded) else "GUIDANCE"
            print(f"   -> {'PASS' if passed else 'FAIL'}"
                  + (f" ({kind} problem)" if not passed and not timed_out else "") + "\n")
            results.append((sc["name"], passed, loaded))
    finally:
        if not a.keep:
            for d in temp:
                shutil.rmtree(d, ignore_errors=True)
        else:
            print("kept:", "\n      ".join(temp))

    n_pass = sum(1 for _, p, _ in results if p)
    n_inc = sum(1 for _, p, _ in results if p is None)
    print("=" * 60)
    for name, p, loaded in results:
        state = "PASS" if p else ("INCONCLUSIVE" if p is None else "FAIL")
        print(f"  {name:42} {state:12} skill {'loaded' if loaded else 'DID NOT load'}")
    print(f"\n  {n_pass}/{len(results)} passed"
          + (f", {n_inc} inconclusive" if n_inc else ""))
    print("\n  NOTE: rubric judging is a measurement, not a proof — it is an LLM reading a"
          "\n  transcript. Treat a failure as a question to investigate, and a pass as"
          "\n  evidence, not a guarantee. The load column says which layer to look at:"
          "\n  'DID NOT load' points at the description/harness, 'loaded' at the skill text.")
    return 0 if (n_pass == len(results)) else 1


if __name__ == "__main__":
    sys.exit(main())
