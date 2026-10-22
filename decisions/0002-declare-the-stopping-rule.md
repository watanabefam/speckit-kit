# 0002 — Declare the stopping rule before iterating

## Context

Every iterative step in the kit was silent about when to stop. `plan` told the agent to research
from primary sources and called that research "bounded" without defining the bound; `implement` ran
a task loop until green; `converge` stopped review on a severity floor but said nothing about what a
silent review establishes. Three loops, three missing termination conditions.

The gap was found by running it, not by reading for it. A repair of two specifications had been
reported as settled after a convergence run; a second audit pass over that same repair found five
defects, and the worst — a pair of mutually exclusive assumption bullets, one saying a measurement
had been taken and one saying it had not — passed every mechanical check the kit owns. What had
actually converged was the research, against a criterion declared mid-run rather than before it.

The obvious remedy, "iterate every step until it converges", does not survive contact with the
evidence. There is no detector behind a judgement loop: another round of self-critique samples what
a reader would notice, and the loop measurably damages output that was already correct when nothing
external gates the revision. It also cannot be falsified, which is the more serious objection — a
criterion that can always be declared met after the fact is not a check.

## Decision

Require a **declared stopping rule** wherever a step iterates, and let the kind of criterion decide
what "done" can mean. The policy lives in the `/speckit` entry point because it applies at every
step; the mechanism lives in the step prepends, because that is where each loop runs.

1. **Declare before round 1**: what counts as a round, what counts as a new finding, and how many
   consecutive empty rounds mean stop (two by default). A criterion fixed before the first round can
   fail; one fixed afterwards cannot.
2. **Stop on decision-relevance**, not exhaustiveness — a round that adds nothing which could change
   an artifact or a decision.
3. **Distinguish the three kinds of criterion.** Where it is a program (test, schema, gate, lint),
   iterate to zero findings, because that comparison is decidable. Where it is judgement, cap the
   loop and report **bounded convergence** — "nothing new within these sources, seeds, criteria and
   date" — never completeness. Where the step is a **ratification** (constitution, decision record,
   approval gate), do not iterate at all.
4. **Report the boundary with the result.** Convergence is always relative to a declared search
   space; the limit travels with the finding.
5. **Make non-convergence a reportable outcome**, not a failure to be rounded up.
6. **Protect the acceptance check** in `implement`: never edit, skip or loosen the oracle to reach
   green, and treat an unsatisfiable requirement as a finding to escalate.
7. **Say which saturation was reached** in `converge`: coverage (no new findings) is not depth.

## Status

Accepted

## Consequences

The kit can now be asked "did you converge?" and answer with something checkable, and the honest
answer "no, here is what is still open" is allowed.

Negative consequences, stated plainly:

- **A cap can stop a loop that would have found one more defect.** Accepted: the alternative was an
  unbounded loop whose stopping point was indifference, which is worse because it looks like
  judgement.
- **"No new findings within a boundary" is a weaker claim than it sounds.** It certifies the lenses
  and sources used, not the artifact. The rules say so rather than letting the weaker claim be read
  as the stronger one.
- **Two rounds is a default, not a measurement.** No source establishes an optimal count; the number
  is a declared parameter, and the rule's value is that it is declared, not that it is right.
- **Ceremony for small research.** A single-source lookup does not need a round log. The rule is
  scoped to multi-round research, and the `NEEDS CLARIFICATION` trigger in `plan` already bounds
  when research happens at all.
- **One claim had to be softened.** The kit previously implied independent review beats self-review.
  No measured head-to-head was found, perspective-based reading's advantage is confounded with
  time-on-task, and a replication found no difference between perspectives. The rule now says only
  what the evidence supports: a loop pays when the acceptance signal comes from outside.

## Evidence

Research: four rounds, criterion declared before round 1 ("stop when a full round adds no finding
that could change the rule text or a threshold"); round 4 was empty. Full source list, including
what could not be verified, in `docs/research/convergence-stopping-rules-2026-10-22.md`.

- **Huang et al., arXiv 2310.01798 (ICLR 2024)** — intrinsic self-correction without external
  feedback lowers accuracy: GPT-4 GSM8K 95.5 → 91.5 → 89.0 after two rounds; GPT-3.5 CommonSenseQA
  75.8 → 38.1. With an oracle to protect correct answers, accuracy rose instead (75.9 → 84.3).
  This is the finding that makes "critique until quiet" unsafe as a stopping rule.
- **Wohlin, EASE 2014** — citation snowballing iterates "once no new papers are found in the
  iterations using both backward and forward snowballing, the loop is ended", reported as
  convergence within a search boundary, not completeness. The established precedent for the form.
- **Cochrane Handbook ch. 4; PRISMA 2020 items 7 and 23c; Booth 2016** — searches are conducted
  "within resource limits", the strategy and its limits are reported, and "how can a reviewer know
  that an additional study will not add important insights?" is the standing objection to any
  completeness claim.
- **Hennink et al. 2017** — code saturation at 9 interviews, meaning saturation at 16–24. The basis
  for "coverage is not depth".
- **Guest, Namey & Chen 2020** — retrospective saturation over an already-analysed fixed set is
  circular ("will inevitably occur"); the rule must be prospective. **Francis et al. 2010** shows
  the prospective form (initial 10, then 3 consecutive with no new concepts) can fail, which is what
  makes it a test.
- **Chen et al., arXiv 2304.05128 (ICLR 2024); SWE-bench+ (arXiv 2410.06992); Wang, Pradel & Liu
  (ICSE 2026); NIST/CAISI 2025; ImpossibleBench (arXiv 2510.20270)** — execution feedback is the
  ingredient that helps; passing tests is not correctness (31.08% of 251 and 55.36% of 112 audited
  passing patches suspicious); agents alter expected values, suppress exceptions and skip
  assertions; under contradictory tests, cheating reached 54–76% and an explicit "cannot be
  satisfied" route cut it to 9%.
- **Papadakis et al., ICSE 2018** — mutation score is weakly correlated with real-fault detection
  once suite size is controlled, so it is a warning, not a verification.
- **CMMI VER.SP 2.2** — an organisation's declared peer-review exit criteria must be met; no
  universal rate is normative. **IEEE 1028-2008** structures inspection as entry (6.4) and exit
  (6.6) criteria.

**Confidence:** high that unguarded self-critique is unsafe to loop and that bounded convergence is
the right form to report — both are directly evidenced. Medium for the default of two empty rounds,
which is a judgement call; and medium for the mapping from qualitative saturation onto review
coverage, which is an analogy rather than a measurement.
