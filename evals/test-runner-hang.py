#!/usr/bin/env python3
"""Regression test for the eval runner's process handling.

This exists because the runner once hung for over three hours on a single query.
`subprocess.run(timeout=...)` did not help: opencode spawns children that inherit
the stdout pipe, so the parent blocks reading a pipe a grandchild still holds,
long after the timeout fired. That would hang CI indefinitely.

Three properties are asserted here, and all three are load-bearing:

  1. A run that never produces the marker returns within its timeout.
  2. A run that produces the marker returns promptly, without waiting for the
     process to finish its whole task.
  3. Neither case leaves an orphaned child process behind.

The test uses a fake `opencode` on PATH, so it needs no model, no network, and no
credentials — it can run in CI on every push.

Usage:  python3 evals/test-runner-hang.py
Exit:   0 = pass, 1 = fail
"""
from __future__ import annotations

import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
RUNNER = HERE / "run-trigger-evals.py"

# A fake `opencode` that streams output WITHOUT newlines (as the real one does),
# then either emits the skill marker or keeps running forever.
FAKE = r"""#!/usr/bin/env python3
import os, sys, time
mode = os.environ.get("FAKE_MODE", "silent")
# Stream a partial line with no newline, like a token stream.
sys.stdout.write('thinking')
sys.stdout.flush()
if mode == "fired":
    time.sleep(0.2)
    sys.stdout.write(' -> Skill "spec-driven-development"\n')
    sys.stdout.flush()
    # Keep running afterwards: the runner must NOT wait for this to finish.
    time.sleep(600)
else:
    # Never emit the marker, never exit.
    while True:
        time.sleep(1)
"""


def load_runner():
    spec = importlib.util.spec_from_file_location("rte", RUNNER)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def children_of(pid: int) -> list[int]:
    try:
        out = subprocess.run(["pgrep", "-P", str(pid)], capture_output=True, text=True).stdout
        return [int(x) for x in out.split()]
    except Exception:
        return []


def main() -> int:
    if not RUNNER.is_file():
        print(f"FAIL  runner not found at {RUNNER}")
        return 1

    tmp = tempfile.mkdtemp(prefix="runner-hang-")
    bindir = Path(tmp, "bin")
    bindir.mkdir()
    fake = bindir / "opencode"
    fake.write_text(FAKE)
    fake.chmod(0o755)

    old_path = os.environ.get("PATH", "")
    os.environ["PATH"] = f"{bindir}:{old_path}"
    mod = load_runner()
    failures = []

    try:
        # --- 1. silent run must respect the timeout ---------------------------
        os.environ["FAKE_MODE"] = "silent"
        t0 = time.time()
        fired, secs, timed_out = mod.run(["opencode", "run", "x"], tmp, 5)
        elapsed = time.time() - t0
        if fired:
            failures.append("silent run reported fired=True")
        if not timed_out:
            failures.append("silent run did not report timed_out")
        if elapsed > 20:
            failures.append(f"silent run took {elapsed:.0f}s for a 5s timeout — HANG")
        else:
            print(f"  ok    silent run returned in {elapsed:.1f}s (timeout 5s)")

        # --- 2. fired run must return promptly, not wait for completion -------
        os.environ["FAKE_MODE"] = "fired"
        t0 = time.time()
        fired, secs, timed_out = mod.run(["opencode", "run", "x"], tmp, 60)
        elapsed = time.time() - t0
        if not fired:
            failures.append("fired run did not detect the marker")
        if elapsed > 20:
            failures.append(f"fired run took {elapsed:.0f}s — it waited for the process to finish")
        else:
            print(f"  ok    fired run returned in {elapsed:.1f}s (did not wait for the 600s tail)")

        # --- 3. no orphaned children ------------------------------------------
        # The fake sleeps 600s after firing; if the process group was not killed it
        # is still alive now.
        time.sleep(1)
        leftover = subprocess.run(
            ["pgrep", "-f", "FAKE_MODE"], capture_output=True, text=True
        ).stdout.strip()
        if leftover:
            failures.append(f"orphaned child process(es) left behind: {leftover.split()}")
        else:
            print("  ok    no orphaned child processes")
    finally:
        os.environ["PATH"] = old_path
        os.environ.pop("FAKE_MODE", None)
        shutil.rmtree(tmp, ignore_errors=True)

    print()
    if failures:
        for f in failures:
            print(f"FAIL  {f}")
        print("RUNNER-HANG: FAIL")
        return 1
    print("RUNNER-HANG: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
