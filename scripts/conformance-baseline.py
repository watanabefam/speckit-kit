#!/usr/bin/env python3
"""Check every spec, plan and task list against its template, honouring a recorded baseline.

    conformance-baseline.py check      verify the corpus (exit 0 clean, 1 on any failure)
    conformance-baseline.py show       print what the baseline currently excuses
    conformance-baseline.py generate   rewrite the baseline from the corpus as it stands now

Why a baseline instead of migrating everything: a handful of these artifacts are the *work records* of
features that were accepted and implemented before the current template existed. Rust RFCs are not
rewritten when the RFC template changes (a new RFC does that), and Python treats non-Draft PEPs as
historical documents; reformatting them would damage blame and risk meaning. So the rule distinguishes
two things:

* a **living artifact** — its outline must conform, no exceptions;
* a **recorded exception** — an artifact whose gap is captured here with a count and a reason.

The baseline is not a place to park a violation. It records the exact counts, and `check` fails when
they change in either direction: an artifact that got worse fails, and an artifact that got better also
fails until its entry is removed. That is the same anti-rot rule ESLint's unused-suppression failure and
RuboCop's `--report-unused-todo-entries` apply, and it is why counts are stored rather than a bare path.
"""

import json
import os
import subprocess
import sys

# CONFORMANCE_ROOT lets the gate run this against a fixture corpus, which is how the 'a new
# non-conformant artifact fails' rule is pinned rather than asserted in prose.
ROOT = os.environ.get("CONFORMANCE_ROOT") or os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CHECKER = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                       "scripts", "check-section-integrity.sh")
BASELINE = os.path.join(ROOT, "specs", ".conformance-baseline.json")

# artifact glob -> template name
KINDS = (
    ("specs/*/spec.md", "spec-template"),
    ("specs/*/plan.md", "plan-template"),
    ("specs/*/tasks.md", "tasks-template"),
)


def artifacts():
    import glob
    for pattern, template in KINDS:
        for path in sorted(glob.glob(os.path.join(ROOT, pattern))):
            yield os.path.relpath(path, ROOT), template


def check(path, template):
    proc = subprocess.Popen(["bash", CHECKER, ROOT, template, os.path.join(ROOT, path), "--json"],
                            stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                            universal_newlines=True)
    out, err = proc.communicate()
    if proc.returncode not in (0, 1):
        raise SystemExit("%s: checker failed (exit %d): %s" % (path, proc.returncode, err.strip()))
    return json.loads(out)


def load_baseline():
    if not os.path.exists(BASELINE):
        return {"entries": []}
    with open(BASELINE) as fh:
        return json.load(fh)


def save_baseline(doc):
    with open(BASELINE, "w") as fh:
        json.dump(doc, fh, indent=2, sort_keys=True)
        fh.write("\n")


REASONS = {
    "specs/002-review-and-stress-gate/plan.md":
        "Work record of an accepted, implemented feature, written before the current plan template. "
        "40 of 44 headings predate the template; retro-fitting would reformat an accepted record.",
    "specs/004-reliability-hardening/plan.md":
        "Work record of an accepted, implemented feature, authored against the older opencode plan "
        "layout: none of the 44 current headings. A rewrite is a new document, not a migration.",
    "specs/002-review-and-stress-gate/tasks.md":
        "Work record of an accepted, implemented feature; 22 of 23 headings predate the template, "
        "including the property table, which that feature never had.",
    "specs/003-autonomous-throughput/tasks.md":
        "Work record of an accepted, implemented feature; 10 of 23 headings missing (parallel "
        "examples, task rules, property tasks, coverage table). Deferred as a reformat, not a gap.",
    "specs/004-reliability-hardening/tasks.md":
        "Work record of an accepted, implemented feature, authored against the older task layout: "
        "none of the 23 current headings.",
}


def cmd_check():
    baseline = load_baseline()
    entries = {e["artifact"]: e for e in baseline.get("entries", [])}
    failures, passed, excused, stale = 0, 0, 0, 0
    seen = set()
    for path, template in artifacts():
        result = check(path, template)
        seen.add(path)
        entry = entries.get(path)
        if result["ok"]:
            passed += 1
            if entry is not None:
                stale += 1
                print("  STALE    %s: conforms now, remove its baseline entry" % path)
            continue
        if entry is None:
            failures += 1
            print("  FAIL     %s: %d missing, %d out of order, %d stubbed"
                  % (path, result["counts"]["missing"], result["counts"]["disordered"],
                     result["counts"]["stubbed"]))
            continue
        if entry.get("counts") != result["counts"] or entry.get("template") != template:
            stale += 1
            print("  STALE    %s: baseline says %s, corpus says %s — regenerate it"
                  % (path, entry.get("counts"), result["counts"]))
            continue
        excused += 1
    for path in sorted(set(entries) - seen):
        stale += 1
        print("  STALE    %s: baselined artifact is gone, remove its entry" % path)

    if passed == 0 and excused == 0:
        print("  FAIL     no artifacts examined — a conformance run that checked nothing is not a pass")
        return 1
    print("conformance: %d conformant, %d excused by the baseline, %d failure(s), %d stale entr(ies)"
          % (passed, excused, failures, stale))
    return 1 if (failures or stale) else 0


def cmd_show():
    for entry in load_baseline().get("entries", []):
        counts = entry.get("counts", {})
        print("%-52s %2d missing, %d out of order, %d stubbed"
              % (entry["artifact"], counts.get("missing", 0), counts.get("disordered", 0),
                 counts.get("stubbed", 0)))
        print("    %s" % entry.get("reason", "(no reason recorded)"))
    return 0


def cmd_generate():
    baseline = load_baseline()
    existing = {e["artifact"]: e for e in baseline.get("entries", [])}
    entries = []
    for path, template in artifacts():
        result = check(path, template)
        if result["ok"]:
            continue
        reason = (existing.get(path) or {}).get("reason") or REASONS.get(path)
        if not reason:
            print("%s does not conform and has no recorded reason — refusing to baseline it" % path,
                  file=sys.stderr)
            return 1
        entries.append({"artifact": path, "template": template,
                        "counts": result["counts"], "reason": reason})
    doc = {
        "note": "Non-conformant artifacts that are work records of accepted, implemented features. "
                "Counts must match exactly; an artifact that conforms again is a stale entry and fails "
                "the gate.",
        "recorded": baseline.get("recorded", ""),
        "checker": "scripts/check-section-integrity.sh",
        "entries": entries,
    }
    save_baseline(doc)
    print("wrote %s with %d entr(ies)" % (os.path.relpath(BASELINE, ROOT), len(entries)))
    for entry in entries:
        print("  %-52s %s" % (entry["artifact"], entry["counts"]))
    return 0


def main(argv):
    command = argv[0] if argv else "check"
    if command == "check":
        return cmd_check()
    if command == "show":
        return cmd_show()
    if command == "generate":
        return cmd_generate()
    sys.stderr.write("usage: conformance-baseline.py [check|show|generate]\n")
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
