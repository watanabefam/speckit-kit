# Research — Review and Stress-Test Gate

**Feature**: `002-review-and-stress-gate` · **Date**: 2026-10-16

Rung: 2 — OpenAlex + Crossref via shell `curl` (rung-1 host web search for the grey literature)

## Question

Should an SDD pipeline carry an independent review step before completion, and a stress test — and
what is the best implementation? This feature was motivated by a real escape: a small kit change
passed the mechanical gate and the author's own reading, and only an independent reviewer caught
four defects (a gate assertion that guarded the wrong thing, a stale descriptive table, an uncited
claim). The kit has no review step.

## Findings

1. **Generator ≠ evaluator.** Anthropic's *evaluator-optimizer* workflow: one call generates, a
   *separate* call evaluates against explicit criteria, looping until pass or budget. "A model
   grading its own output is too generous." Fit requires clear criteria and measurable refinement
   [S1].
2. **Self-critique can *lower* quality.** Snorkel's 2025 "self-critique paradox": on tasks the
   generator already solves well (~98%), adding a self-critique loop dropped accuracy to ~57%,
   because the critic hallucinates flaws to justify its existence [S2]. ⇒ **Bound the loop; do not
   chase "zero findings."** This is the empirical basis for severity-gated termination.
3. **LLM judges are systematically biased.** Position bias, verbosity bias, and **self-preference
   bias** are documented and reproducible; self-preference tracks lower perplexity on the model's own
   text [3][4][5]. Mitigations that work: separate context/model, order-swap, an explicit rubric.
   ⇒ A reviewer sharing the author's context shares its blind spots [S1][S2].
4. **Self-correction needs an external signal.** "LLMs cannot self-correct reasoning yet" — without
   external feedback, self-review degrades performance [6].
5. **Red-team practice.** OWASP LLM Top 10 / GenAI Red Teaming Guide, Microsoft, and AMTSO converge:
   "using the model under test as its own judge" is a named anti-pattern; define pass/fail **by
   risk, not average** (one severe failure is a failure even if 99% pass); prefer **observable
   evidence over asserted outcomes**; run on every behaviour-changing edit; keep a **regression
   corpus** — every confirmed bypass becomes a permanent case [S3][S4][S5][S6].
6. **Prefer deterministic verification.** Where a criterion reduces to a program, a deterministic
   check beats an LLM judge — cheaper and non-arguable. Where behaviour is non-deterministic, repeat
   and report the spread, not a single pass/fail [S2][S6].

## Implications for the design

- Review by a **fresh context** (a subagent or separate session; ideally a different model), not by
  re-reading one's own work.
- **Terminate on severity, not silence** — stop when no unresolved finding is HIGH or above; cap the
  passes (the kit already does this in `/speckit.specify`: max 3).
- Findings must carry **evidence** (`file:line` or a reproducing command); a finding without it is
  dismissed *with a recorded reason*, not counted.
- **Stress test** is triggered by *what the change asserts* (a hook, gate, validator, guard,
  invariant), not its size; the **negative case goes first**; a failing case becomes a **regression
  fixture**.
- A prose change with no oracle gets its reasoning probed for loopholes — do not fake a test.

## Sources

Grey literature (rung 1)

- [S1] Anthropic. *Building Effective Agents* (evaluator-optimizer). anthropic.com/engineering/building-effective-agents
- [S2] agentpatterns.ai. *Evaluator-Optimizer* (citing Snorkel AI 2025 "self-critique paradox").
- [S3] OWASP. *AI/LLM Application Security Testing and Red Teaming* (DevSecOps Guideline).
- [S4] OWASP. *GenAI Red Teaming Guide* (RC3c).
- [S5] Microsoft. *Planning red teaming for LLMs* (Azure AI Foundry).
- [S6] AMTSO. *Guidelines for Testing of Agentic Security Products* (v1.0, 2026).

Scholarly (rung 2)

- [3] Panickssery, A. et al. (2024). *Self-Preference Bias in LLM-as-a-Judge.* arXiv:2410.21819
- [4] Shi, L. et al. (2025). *Judging the Judges: A Systematic Study of Position Bias in LLM-as-a-Judge.* IJCNLP. doi:10.18653/v1/2025.ijcnlp-long.18
- [5] Ye, S. et al. (2024). *Benchmarking Cognitive Biases in Large Language Models as Evaluators.* Findings of ACL. doi:10.18653/v1/2024.findings-acl.29
- [6] Huang, J. et al. (2023). *Large Language Models Cannot Self-Correct Reasoning Yet.* arXiv:2310.01798

## Limitations

- Findings [S1]–[S6] are grey literature (vendor/consortium guidance), not peer-reviewed; treated as
  practice consensus, attributed as such.
- [3]–[6] study LLM evaluation generally, not source-quality rules inside coding agents; the transfer
  is inference, not measurement. Recorded so the spec does not overclaim.
