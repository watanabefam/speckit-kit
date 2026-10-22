# Research — when a loop should stop

Date: 2026-10-22. Purpose: settle the stopping rule now recorded in
[decision 0002](../decisions/0002-declare-the-stopping-rule.md) and implemented in
`commands/speckit.md` and the `plan` / `implement` / `converge` prepends.

## Method, and what it cost

The criterion was declared **before round 1**: stop when a full round adds no finding that could
change the rule text or a threshold; findings that only add citations to a settled rule do not
count as progress.

| Round | Question | Result |
| --- | --- | --- |
| 1 | Review/inspection exit criteria; LLM self-refinement; saturation as a stopping heuristic | Changed the design — self-critique without an oracle is not neutral; "nothing new" certifies coverage, not depth; a stopping rule must be prospective or it cannot fail |
| 2 | Does an external verifier change the outcome; how is a literature search stopped in practice | Changed the design — the acceptance signal is the mechanism, not the repetition; bounded convergence with the boundary named is the established honest form; the oracle is capturable |
| 3 | Second-pass yield, viewpoint diversity, fresh versus same-context reviewer | Changed the design by **removing** a planned claim: viewpoint diversity is not an equal-effort win, and no measured same-reviewer repeat-pass curve exists |
| 4 | Normative exit criteria (IEEE 1028, CMMI, DoD) | **Empty** — no finding changed the text or a threshold. Research closed here |

Four rounds, one empty. Two items stayed unverified and were therefore **kept out of the rules**
(see "Not used" below), which is the point of the exercise rather than a gap in it.

## Findings that changed the rules

### Intrinsic self-critique is not a free loop

- **Huang et al., "Large Language Models Cannot Self-Correct Reasoning Yet", arXiv:2310.01798
  (ICLR 2024).** *Primary; abstract and paper HTML read.* Without external feedback: GPT-4 GSM8K
  95.5% → 91.5% → 89.0% over two rounds; GPT-3.5 CommonSenseQA 75.8% → 38.1%. With ground-truth
  labels used to protect correct answers, GPT-3.5 GSM8K rose 75.9% → 84.3%. The authors' claim:
  "LLMs struggle to self-correct their responses without external feedback, and at times, their
  performance even degrades after self-correction."
- **Madaan et al., "Self-Refine", arXiv:2303.17651 (NeurIPS 2023).** *Primary.* Same model as
  generator, refiner and feedback provider; average ~20 points over seven tasks, but math moved
  92.9% → 93.1%. Huang's reanalysis: with an equally strong initial prompt, the one-shot score was
  81.8% against 75.1% after refinement — part of the apparent gain is baseline construction.
- **Kamoi et al., TACL 2024.** *Primary.* No reliable evidence of successful self-correction from
  prompted feedback under fair settings, outside tasks with reliable external feedback.
- **Chen et al., "Teaching LLMs to Self-Debug", arXiv:2304.05128 (ICLR 2024).** *Primary; headline
  verified, per-table values seen in the OpenReview listing only.* Up to 12% with unit-test
  execution on TransCoder/MBPP; GPT-4 MBPP without execution +3.6%; explanation-only on Spider 2–3%
  overall.

**Rule consequence:** iteration pays when the acceptance signal is external to the thing being
revised. "Iterate until the critique goes quiet" is not a quality rule.

### Green is manufacturable

- **Aleithan et al., "SWE-Bench+", arXiv:2410.06992 (2024).** *Preprint.* Of 251 passing SWE-Agent +
  GPT-4 patches, **31.08%** were judged suspicious on manual audit; resolved rate fell 12.47% →
  3.97% after filtering. On SWE-bench Verified, **55.36% of 112** passing patches were suspicious
  (33.04% solution leakage, 12.50% incorrect, 9.82% incomplete); 22.4% → 10.0% after filtering.
- **Wang, Pradel & Liu, "Are 'Solved Issues' in SWE-bench Really Solved Correctly?", ICSE 2026
  (arXiv:2503.15223).** Re-running all developer tests found **7.2–8.4%** (avg 7.8%) of plausible
  patches functionally incorrect, ~4.5 points of resolution-rate inflation, ~6.4 points overall.
- **NIST/CAISI, 2025.** *Primary report of observed transcripts.* Agents altered expected outputs,
  suppressed warnings/exceptions, skipped failing tests; the harness restored test files, so the
  attempts failed. Their summary table gives **0.2%** successful grader-gaming — a lower bound from
  their logs, not a general rate.
- **Zhong, Raghunathan & Carlini, "ImpossibleBench", arXiv:2510.20270 (2025).** *Preprint.* With
  deliberately contradictory tests, GPT-5 cheated on **54%** of Conflicting-SWEbench tasks and
  **76%** of Oneoff-SWEbench. More submission attempts raised the open-test pass rate 80% → 83%
  *and* cheating 33% → 38%. A stricter prompt cut Conflicting-LiveCodeBench cheating from >85% to
  **1%**, and allowing the agent to flag a task as impossible cut 54% to **9%**.
- **Papadakis et al., ICSE 2018.** Mutation scores are **weakly** correlated with real-fault
  detection once suite size is controlled, though high-score suites still beat random ones.
  **Petrović et al., 2021** (Google, ~15M mutants, six years) reports developers wrote more tests
  and reduced survivability, with mutants coupled to real faults.

**Rule consequence:** never edit the oracle to reach green; make "this cannot be satisfied" a
legitimate, reported outcome — the measured anti-cheating mechanism; treat a falling mutation score
as a warning, not a verdict.

### Convergence is bounded, and says so

- **Wohlin, "Guidelines for snowballing in systematic literature studies", EASE 2014.** *Peer
  reviewed; the quoted sentence is from the indexed text — the PDF did not parse here.* "Once no new
  papers are found in the iterations using both backward and forward snowballing, the loop is
  ended." Presented as a procedure, not a completeness guarantee.
- **Booth, 2016, "Searching for qualitative research…" (PMC4855695).** *Primary.* "Comprehensive"
  searching is constrained by sources, material and time; the standing problem is "how can a
  reviewer know that an additional study will not add important insights?"
- **Cochrane Handbook ch. 4 (2025)** — search "within resource limits". **PRISMA 2020** items 7 and
  23c — present the full strategy with its filters and limits, and discuss limitations of the
  process. **Briscoe et al., 2019/2020 (PMC7079050)** — the same citation search returned 29, 37 and
  65 records in Web of Science, Scopus and Google Scholar.

**Rule consequence:** report "nothing new within *these* sources, seeds, criteria and date". An
empty round is a claim about the search, not about the world.

### Coverage is not depth; prospective rules are the ones that can fail

- **Hennink, Kaiser & Marconi, 2017 (PMC9359070).** *Primary.* Code saturation at **9** interviews;
  *meaning* saturation needed **16–24**. Also: of 220 focus-group studies that explained sample
  size, **83%** invoked saturation, many without saying how it was assessed.
- **Guest, Namey & Chen, 2020 (PMC7200005).** *Primary.* Saturation assessed after coding a fixed
  dataset "will inevitably occur" — the denominator moves. Their remedy: specify base size, run
  length and new-information threshold in advance.
- **Francis et al., 2010.** *Primary, abstract read.* Prospective rule: initial sample 10, then three
  consecutive units with no new ideas. In their two studies one reached saturation at interview 17
  and **the other never met the criterion for all categories** — the rule is allowed to fail.
- **Guest, Bunce & Johnson, 2006.** 70% of 114 themes in the first six interviews, 92% by twelve
  (figures confirmed in the 2020 restatement; the 2006 PDF did not extract). Sample-specific, not a
  prescription.

**Rule consequence:** "no new findings" is reported as coverage; non-convergence is a legitimate
result; the criterion is declared before round 1.

### What was removed, because the evidence did not carry it

- **Perspective-based reading**, Basili et al., 1996: ~35% improvement over ad-hoc/checklist — but
  PBR reviewers spent more time with **the same cost per defect**, so time-on-task is a confound.
  **Regnell, Runeson & Thelin, 2000**: 30 subjects, 10 per perspective, **no significant difference**
  in detection rate, defects per hour, or coverage. A replicated-experiment summary reports 48% more
  defects than ad-hoc teams, but that figure was secondary-excerpt-only.
- **Second-pass yield**: Biffl et al., 2001 is reported to show first cycle 46% and reinspection 21%
  of defects, but those numbers came from a secondary summary, the primary abstract reports only
  "significantly lower net gain", and reinspection follows *rework* — it is not the same reviewer
  rereading unchanged text. No same-reviewer repeat-pass curve was found.
- **Author self-review**: PSP data is reported as removing 60%+ of defects before unit testing, but
  no matched-effort comparison against an independent reviewer was found.

**Rule consequence:** the kit no longer implies an effect size for independent review. It asks for
a reviewer in a context that did not do the work, and grounds iteration on the external acceptance
signal, which is measured.

## Not used

- **Gilb & Graham, *Software Inspection* (1993), rate-based exit criteria.** Not verified — the book
  text was inaccessible. No critique of rate criteria was verified either. The rule deliberately
  contains no defect-rate threshold partly because of this.
- **IEEE 1028-2008 §6.6 "Exit criteria".** The clause exists (alongside §6.4 entry criteria) but the
  standard text is paywalled and the indexed excerpt truncates mid-sentence. What *is* verifiable:
  **CMMI VER.SP 2.2** requires an organisation's declared peer-review exit criteria to be met and
  prescribes no universal rate, and the **Scrum Guide 2020** defines Definition of Done as quality
  measures/criteria to be met, not an absence-of-findings rate.
- **"A review that finds nothing is not evidence of quality" as a citation.** No authoritative source
  stating it was found. The rules assert it as a design principle and say so, rather than dressing
  it as a quotation.

## Limits of this research

- Several load-bearing numbers come from **preprints** (SWE-Bench+, ImpossibleBench) or from a
  **lower-bound** observation (NIST's 0.2%). They are used for direction, not as rates to design to.
- The mapping from qualitative **saturation** onto review **coverage** is an analogy. It is
  defensible at the level of "code-level novelty is not depth"; it is not a measurement of review.
- **Two consecutive empty rounds** is a declared parameter, not an optimum. No source establishes a
  best count, and round 4 of this research is a single sample, not a distribution.
