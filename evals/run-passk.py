#!/usr/bin/env python3
"""pass^k measurement — single-attempt and repeated-attempt success, with a pessimistic bound.

A check that passes once is not a check that passes every time. This reports both numbers and
the constant-difficulty bound, and says which assumption the bound depends on.

    run-passk.py --vector "5/5,4/5,3/5" [--k 5] [--json]
    run-passk.py --trials 5 --successes 5,4,3 [--k 5]

`--vector` takes per-task `successes/trials`; `--trials` + `--successes` is the same thing with
one n for every task. Stdlib only, no task runner.

pass@1  = mean over tasks of c_i / n_i
pass^k  = mean over tasks of C(c_i, k) / C(n_i, k)      (unbiased: all k of k attempts succeed)
bound   = (mean pass@1)^k                                (constant difficulty across tasks)

Jensen's inequality gives E[p^k] >= (E[p])^k, so the bound is a *population* lower bound when
tasks differ in difficulty; with few trials the finite-sample estimates can reverse the
comparison, and this script says so rather than pretending the inequality holds on the numbers.
"""

import json
import math
import sys

USAGE = __doc__.strip()


def comb(n, k):
    """Binomial coefficient, python3.6-safe (math.comb is 3.8+)."""
    if k < 0 or n < 0 or k > n:
        return 0
    k = min(k, n - k)
    result = 1
    for i in range(k):
        result = result * (n - i) // (i + 1)
    return result


def wilson(successes, trials, z=1.96):
    if trials == 0:
        return (0.0, 0.0)
    phat = float(successes) / trials
    denominator = 1 + z * z / trials
    centre = (phat + z * z / (2.0 * trials)) / denominator
    margin = z * math.sqrt(phat * (1 - phat) / trials + z * z / (4.0 * trials * trials)) / denominator
    return (max(0.0, centre - margin), min(1.0, centre + margin))


def parse(argv):
    opts = {"vector": None, "trials": None, "successes": None, "k": None, "json": False}
    i = 0
    while i < len(argv):
        arg = argv[i]
        if arg in ("-h", "--help"):
            sys.stdout.write(USAGE + "\n")
            sys.exit(0)
        if arg == "--json":
            opts["json"] = True
        elif arg in ("--vector", "--trials", "--successes", "--k"):
            i += 1
            if i >= len(argv):
                sys.stderr.write("%s needs a value\n" % arg)
                sys.exit(2)
            opts[arg[2:]] = argv[i]
        else:
            sys.stderr.write("unknown argument '%s'\n\n%s\n" % (arg, USAGE))
            sys.exit(2)
        i += 1
    if not opts["vector"] and not opts["successes"]:
        sys.stderr.write("refusing: no success vector given\n\n%s\n" % USAGE)
        sys.exit(2)
    return opts


def main(argv):
    opts = parse(argv)
    tasks = []
    if opts["vector"]:
        for item in opts["vector"].split(","):
            item = item.strip()
            if not item:
                continue
            if "/" not in item:
                sys.stderr.write("refusing: '%s' is not successes/trials\n" % item)
                return 2
            c, n = item.split("/", 1)
            tasks.append((int(c), int(n)))
    else:
        trials = int(opts["trials"] or 0)
        if trials < 1:
            sys.stderr.write("refusing: --trials must be >= 1 with --successes\n")
            return 2
        for item in opts["successes"].split(","):
            item = item.strip()
            if item:
                tasks.append((int(item), trials))
    if not tasks:
        sys.stderr.write("refusing: the vector is empty\n")
        return 2
    for c, n in tasks:
        if n < 1 or c < 0 or c > n:
            sys.stderr.write("refusing: %d/%d is not a valid success count\n" % (c, n))
            return 2
    smallest = min(n for _, n in tasks)
    k = int(opts["k"] or smallest)
    if k < 1 or k > smallest:
        sys.stderr.write("refusing: k=%d needs at least k trials per task (min n=%d)\n"
                         % (k, smallest))
        return 2

    per_task = [float(c) / n for c, n in tasks]
    single = sum(per_task) / len(per_task)
    empirical = sum(comb(c, k) / float(comb(n, k)) for c, n in tasks) / len(tasks)
    bound = single ** k
    total_c = sum(c for c, n in tasks)
    total_n = sum(n for c, n in tasks)
    low, high = wilson(total_c, total_n)

    if abs(empirical - bound) < 1e-12:
        gap = ("the two figures agree exactly: on this vector the constant-difficulty "
               "assumption costs nothing (identical per-task success rates, or k=1)")
    elif bound < empirical:
        gap = ("the bound is below the empirical figure because tasks differ in difficulty: "
               "a heterogeneous task set loses less than a uniform one at the same mean")
    else:
        gap = ("the bound is above the empirical figure here because the estimates are "
               "finite-sample: Jensen holds for the population figures, not for C(c,k)/C(n,k) "
               "at small n")

    doc = {
        "tasks": len(tasks),
        "k": k,
        "pass@1": single,
        "pass^k": empirical,
        "constant_p_bound": bound,
        "wilson95_pass@1": [low, high],
        "pooled": {"successes": total_c, "trials": total_n},
        "note": gap,
    }
    if opts["json"]:
        sys.stdout.write(json.dumps(doc, indent=2, sort_keys=True) + "\n")
        return 0
    sys.stdout.write("single-attempt  pass@1       %.4f   (%d/%d pooled runs, Wilson 95%% "
                     "%.3f..%.3f)\n" % (single, total_c, total_n, low, high))
    sys.stdout.write("repeated        pass^k (k=%d) %.4f   (mean of C(c,k)/C(n,k) over %d task(s))\n"
                     % (k, empirical, len(tasks)))
    sys.stdout.write("pessimistic     (pass@1)^%d  %.4f   (constant difficulty; every task equally "
                     "hard)\n" % (k, bound))
    sys.stdout.write("difference: %s\n" % gap)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
