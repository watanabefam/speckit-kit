# Research — Autonomous Throughput and a Mechanical Boundary

**Companion to:** `spec.md` (informative; the spec prevails where they disagree)
**Date:** 2026-10-17
**Provenance:** host web search (Exa) + CiteKit CLI (`tools/search.mjs`, 14 queries over OpenAlex,
Crossref, Europe PMC, PubMed, ERIC, DOAJ) + primary docs fetched directly. Two PubMed requests
returned HTTP 429; all substantive claims below come from metadata/abstracts or the primary document,
not full text.

This document records the evidence behind the requirements in `spec.md`. It is the reason each
requirement exists, and it is deliberately separate from the spec so the spec stays testable.

## Finding 1 — Speed comes from removing round-trips and rework, not from generation

- METR's 2025 RCT (16 experienced OSS developers, 246 real tasks) found AI tools made developers
  **19% slower**, while the developers believed they were **20% faster** [1]. Perception and
  measurement disagree.
- METR's 2026 follow-up is **not a clean estimate**: developers now refuse to work without AI, and
  tasks are self-selected, biasing the sample toward low-uplift work. Raw signal is weakly positive
  (roughly 6–18% for sub-groups, wide intervals) [2].
- DORA 2025 (n≈5,000) found AI adoption now correlates with **higher throughput but higher
  instability**; the gains appear where automated testing, version control, and feedback loops are
  already strong [3].
- Screen-recording analysis in [1] found AI reduced time spent coding/reading but the savings were
  overwhelmed by **reviewing output, prompting, and waiting**.
- A 2026 longitudinal study of agent PRs found **front-loaded velocity gains only when agents were the
  project's first AI tool**; repos already using AI IDEs saw minimal or short-lived gains [24].
- The workplace RCT "Dear Diary" found sustained use increased perceptions of usefulness and
  enjoyment while **trust in generated code did not change** [25].

**Design consequence:** the goal is fewer human interactions and less rework (SC-001, SC-003), not a
claim of raw speedup. US3 and US4 target the round-trips; US2 targets the rework.

## Finding 2 — The boundary belongs in tool permissions, not prose

- **Excessive agency** has three roots: excessive functionality, excessive permissions, excessive
  autonomy [30].
- Coding agents carry **ambient authority** — naming a resource is enough to act on it — which is what
  indirect prompt injection exploits [10].
- **Rule files are an attack surface.** Malicious prompts injected into `AGENTS.md` / `.cursorrules`
  can make coding agents swap legitimate dependencies for attacker-controlled packages, with high
  success and cross-model transfer [9]. `AGENTS.md` is executable context.
- Red-teaming six real coding agents found the **tool-invocation surface** is the main attack path,
  including prompt leakage [11].
- The strongest production implementation is **deny > ask > allow, fail-closed**, with a scoped deny
  blocking matching calls [6]. OpenCode evaluates ordered rules with **last match winning**, and
  `--auto` auto-approves asks while **deny rules still hold** [8].
- Unattended runs should sit inside an isolation boundary, because that boundary is what protects the
  system once prompts are removed [7]. But isolation has a usability cost — fewer than 40% of
  coding-agent users run sandboxed, mostly because setup is painful [12] — and can become security
  theatre if not matched to the threat [13].

**Design consequence:** FR-001–FR-004 and FR-015. The boundary is mechanical (permissions, hooks,
installer reporting), never prose. Rule-file drift is reported rather than silently overwritten.

## Finding 3 — Continuous execution needs explicit stopping conditions

- Anthropic: agents need environment feedback each step, human checkpoints, and **stopping
  conditions**; code is a good agent task precisely because tests give ground truth [4].
- OpenAI: intervene on **failure thresholds** and **high-risk actions**; approvals should be resumable
  state rather than a lost turn [5].
- HumanLayer: expose human contact as a tool and **break the loop between tool selection and
  invocation**; own the control flow; make pause/resume first-class [29].

**Design consequence:** FR-008–FR-010. Continuous execution is bounded by a failure budget, commits
per task, and a ledger that survives context loss.

## Finding 4 — Verification and independent review are what catch defects

- **Self-review is biased.** Across six models, LLMs favour their own generations; self-refinement
  amplifies the bias, and external feedback with accurate assessment reduces it [18].
- Test-first prompting improves correctness [19]; a 2026 requirement-guided pipeline extracts
  functional requirements, generates tests before code, and uses bounded execution-driven refinement,
  naming hallucination and test–code divergence as the failure modes [20]. A failing-test → patch →
  re-test loop is the verifiable form [21].
- The kit's own converge step already implements fresh-context, severity-bounded review (spec 002).

**Design consequence:** FR-005–FR-007 (one verify command, named in the task) and FR-012 (failing test
first in the fast lane).

## Finding 5 — Process must be proportioned, and the instruction budget is finite

- A detailed Spec Kit trial reported the workflow was **about 10× slower** than the author's normal
  loop: 13m15s generation for ~700 lines, then 30 minutes of review, and an obvious runtime bug the
  spec did not catch. Code quality was "just fine," not better [27].
- A 2026 process-taxonomy study of six frameworks found **no framework covers all six dimensions**,
  with a structural trade-off between process depth and portability; recurring risks include
  spec–code drift, excessive trust in generated artifacts, and supply-chain fragility [23].
- A word-count analysis found Spec Kit carries **13,647 words of instruction before code vs 1,764
  after**. HumanLayer's RPI failed because models follow only ~150–200 instructions and the planning
  prompt alone held 85, so the alignment step was skipped [28][29].
- Models use information at the start and end of context far better than the middle [22].
- The defensible version of spec-driven development is "write the acceptance criteria before building,
  review the plan, verify against them, then update or delete the spec" — not "the spec is the source
  of truth forever" [31].

**Design consequence:** FR-011–FR-013 and FR-004. The fast lane exists because the full process has a
minimum useful size. The autonomy contract is one file, not prose added to every command — the kit's
per-command prompts are already 1.7k–3.0k words.

## Finding 6 — Approval gates can backfire

- People under **automation bias** over-rely on algorithmic output even when evidence contradicts it
  [16], and policies requiring human oversight can rest on the untested assumption that people can
  perform that oversight — legitimising faulty systems rather than catching them [15]. A human
  signature can become a legitimacy artifact [17].
- Governance frameworks converge on intervention authority, escalation, monitoring, and traceability
  as the dimensions that matter [14].

**Design consequence:** gates must require **evidence**, not a yes/no. The autonomy contract's
"Approval required" bucket names the exact command, target, impact, and rollback — the design avoids
adding gates and instead makes the few that remain load-bearing.

## Finding 7 — rule-evaluation semantics: read the source, and don't depend on it (T042)

T042 asked whether the permission block actually blocks in a live session, because it assumes
opencode takes the **last** matching rule. The question is answerable from the source, and the
dependency is removable.

- **What opencode does today.** The docs say rules are matched "with the last matching rule winning"
  [32], and the implementation agrees: `evaluate()` flattens the rulesets and calls `rules.findLast(…)`
  [33]; the project's own tests assert "later rules take precedence (last match wins)" [36]. The
  **installed binary (1.18.30)** shows the same `findLast` fold in the current permission code, so this
  is what is running, not merely documented.
- **What is about to change.** An open issue reports that `findLast` lets a broad deny silently
  override a more specific allow [34], and an open PR replaces it with **most-specific-pattern-wins**
  (specificity = literal characters before the first wildcard; ties broken by position, later wins)
  [35]. So "last match wins" is true today and may be false after an upgrade.
- **The field is contested, not just this tool.** Claude Code documents the opposite — evaluated
  **deny → ask → allow**, *first* match wins, specificity does not change the order [37][39] — while a
  filed issue reports observed behaviour that contradicts it, with specificity winning across scopes
  [38]. **The general lesson: for this class of tool the documentation is not the specification.**
- **The hazard has a name.** Access-control research calls it **shadowing** (a rule that can never take
  effect because another subsumes it), with verified detection algorithms [40][41]; firewall research
  exists to optimise rule order and remove shadowing and redundancy [42][43]; **deny-overrides** and
  deny-monotone composition are the safe combining semantics [44].
- **opencode's wildcard match is anchored to the whole string** (`*`→`.*`, `?`→`.`, `^…$`) [33], so
  `npm publish*` does **not** match `cd app && npm publish`. The glob layer is genuinely partial — which
  is why the token hooks carry the wrapper forms.

**Resolution.** The dependency was removed rather than verified once. The gate (§1d3) now resolves the
ruleset under **both** folds and requires the same verdict for every irreversible action and for a
command derived from every deny pattern, plus the structural property that makes last-match safe
(every deny is later than every non-deny). This was confirmed before it was asserted: all 11
irreversible actions and all derived commands resolve to `deny` under **both** semantics, with no
shadowing. T042 is therefore closed deterministically — a live session is no longer the gate, and a
future change to the semantics fails the gate instead of silently disarming the boundary.

**Design consequence:** deny rules are last *and* at least as specific as the rules they override, so
both semantics agree. Prefer the layer whose semantics the kit owns (a hook) for anything a glob
cannot express.

## Finding 8 — a stop-behaviour has an observable oracle; a self-report is the weakest one

The question for S9 was whether "the run ended and the failing task is still unticked" is a sound
oracle for a halt, or whether it needs a marker file the agent writes about itself.

- The agent-evaluation literature is unanimous that the oracle is the **state, not the message**:
  "Production systems trust observable outcomes, not promises… The conversation tells you what the
  agent intended to do. The system tells you what actually happened" [54]. "The final sentence is
  evidence about what the agent claims. The environment state and retained action log are evidence
  about what it did" — and "outcome checks should normally be **independent of the agent's output
  channel**" [56].
- A self-report is not merely weaker; it is *weakest exactly where S9 lives*: the incentive to report
  progress that was not made is highest on "tasks where success is hard or impossible" [55] — and a
  halt scenario is precisely such a task.
- Termination is a property observed from outside, as a stable/terminal state [60]; "how the run
  ended" is a standard assertion target in agent evals [57]; stop conditions belong in the behaviour
  contract itself [58]; and every clause of a defined outcome becomes an evaluation point [59].
- Self-reports are systematically biased in measurement generally [61][62], so this is not an
  agent-specific quirk.

**Resolution:** S9 asserts the terminal state (the run ended) and the environment (the failing task is
unticked, the ledger has no `complete` line). No marker file is required — and adding one would make
the check depend on the agent's own word, which is the one thing a halt scenario must not do.

## What the evidence does not support

- **"More autonomy always means faster."** The 2025 result was a slowdown; the 2026 result is too
  biased to settle it [1][2].
- **"The spec is the source of truth forever."** Drift is a documented failure mode [23][27][31].
- **"Approval gates equal safety."** Automation bias and legitimacy artifacts [15][16][17].
- **"Add more rules to the prompt."** The instruction budget is the binding constraint [22][28][29].
- **"Sandboxing solves it."** Necessary for unattended runs, not sufficient, and can be theatre
  [7][13].

## Gaps and confidence

- No RCT compares spec-driven workflows to vibe coding; the SDD evidence is experience reports and
  framework analyses [23][27][31].
- Productivity studies cover AI-assisted coding broadly, not autonomous multi-step agents; the
  agent-adoption study is observational [24].
- Several security papers are 2026 preprints with low citation counts; the mechanism (ambient
  authority + rule-file injection) is well supported even if specific rates are provisional
  [9][10][11].
- CiteKit returned metadata/abstracts, not full text.

## Phase 0 decisions

Consolidated from the findings above. Each decision resolves a `NEEDS CLARIFICATION` or a design
fork in `plan.md`.

### D1 — The permission block is written to the project `opencode.json`

- **Decision:** create the project `opencode.json` if absent (with `permission` and `instructions`);
  if it exists, print the block and a merge instruction and leave the file untouched.
- **Rationale:** the boundary is project-scoped and reviewable; the kit must not edit a user-owned
  global config; print-if-present is the safe middle between "no protection" and "clobber".
- **Alternatives considered:** a hook instead of a permission (rejected — permission is the documented,
  user-configurable layer; the hook layer stays tiny); the global config (rejected — outside the
  project); print-only (rejected — silent absence of protection).

### D2 — Write `permission` (object syntax), not `permissions` (ruleset array)

- **Decision:** use the documented `permission` object with a catch-all first and specific `deny` rules
  last.
- **Rationale:** it is what the current docs show; order is load-bearing because the last match wins.
- **Alternatives considered:** the newer `permissions` ruleset — deferred as the forward path (schema
  marks `permission` deprecated).
- **Risk carried:** project-over-global precedence and `permission` support are validation steps, not
  assumptions (plan R1, R2).

### D3 — The autonomy contract is one file plus one pointer

- **Decision:** install `.opencode/autonomy-contract.md` and add a single pointer line to the bridge
  block.
- **Rationale:** the instruction budget is the binding constraint (finding 5); five command copies
  would drift.
- **Alternatives considered:** per-command prose (rejected — budget); a global instruction file
  (rejected for install-time scope; it remains a fine personal default).

### D4 — `/speckit.quick` is installer-copied, not a preset command

- **Decision:** ship `commands/speckit.quick.md` and copy it like `commands/speckit.md`.
- **Rationale:** a preset cannot create a new command (`bin/speckit-init:83`–`:85`); a `type: "command"`
  entry naming it is silently ignored.
- **Alternatives considered:** a preset command entry (rejected — silently ignored).

### D5 — Verification is a generated `scripts/verify` plus a managed `## Commands` block

- **Decision:** detect the stack, record the commands in a third AGENTS.md block, generate a `verify`
  entry point; unresolved if undetectable.
- **Rationale:** one known command converts the largest variable cost into a fixed one (finding 1, 4).
- **Alternatives considered:** name a command per task without a block (rejected — no single entry
  point); add a task-runner dependency (rejected — zero-dependency kit).

### D6 — Property testing: fallback, no framework

- **Decision:** `fallback` to example-based tests plus loop-generated fixture corpora in bash; introduce
  no property-based framework.
- **Rationale:** no framework is present and adding one to a zero-dependency bash kit is not justified;
  the properties in `plan.md` are checkable with generated fixture loops.
- **Alternatives considered:** adopt `hypothesis`/`fast-check` (rejected — new dependency for a shell
  kit).

### D7 — Version 1.12.0

- **Decision:** bump the preset to `1.12.0` with a new CHANGELOG entry.
- **Rationale:** a new command, a new installer step, and a new rule are additive; the gate requires the
  version to be the newest CHANGELOG release.

## Sources

[1] Becker, Rush, Barnes, Rein (2025). *Measuring the Impact of Early-2025 AI on Experienced Open-Source Developer Productivity.* arXiv:2507.09089. doi:10.48550/arXiv.2507.09089
[2] METR (2026-02-24). *We are Changing our Developer Productivity Experiment Design.* https://metr.org/blog/2026-02-24-uplift-update/
[3] DORA / Google Cloud (2025). *State of AI-assisted Software Development.* https://dora.dev/research/2025/dora-report/
[4] Anthropic (2024). *Building Effective Agents.* https://www.anthropic.com/engineering/building-effective-agents
[5] OpenAI (2026). *A Practical Guide to Building Agents.* https://openai.com/business/guides-and-resources/a-practical-guide-to-building-ai-agents/
[6] Anthropic. *Claude Code — Configure permissions.* https://code.claude.com/docs/en/permissions
[7] Anthropic. *Claude Code — Choose a sandbox environment.* https://code.claude.com/docs/en/sandbox-environments
[8] OpenCode. *Permissions.* https://opencode.ai/docs/permissions/
[9] (2026). *Package Hallucination Attacks on Coding Agents through Prompt Injection in Rule Files.* doi:10.48550/arXiv.2610.09264
[10] (2026). *Authority Is Not a String: A Capability-Scoped Harness for Prompt-Injection-Resistant Coding Agents.* doi:10.1145/3843750.3843843
[11] (2026). *Red-Teaming Coding Agents from a Tool-Invocation Perspective.* doi:10.1145/3832267
[12] (2026). *SideKernel: A Usable microVM Sandbox for AI Coding Agents on macOS.* doi:10.48550/arXiv.2610.02456
[13] (2026). *The Containment Paradox: When AI Sandboxing Backfires.* doi:10.5281/zenodo.19542047
[14] (2025). *Human Oversight for Autonomous AI Agents: A Governance Framework.* doi:10.54660/.ijeca.2025.1.1.18-32
[15] (2022). *The flaws of policies requiring human oversight of government algorithms.* doi:10.1016/j.clsr.2022.105681
[16] (2022). *Human–AI Interactions in Public Sector Decision Making: "Automation Bias" and "Selective Adherence."* doi:10.1093/jopart/muac007
[17] (2026). *Endorsed Automation Bias: When the Human Signature Becomes a Legitimacy Artifact.* doi:10.2139/ssrn.6593178
[18] (2024). *Pride and Prejudice: LLM Amplifies Self-Bias in Self-Refinement.* doi:10.18653/v1/2024.acl-long.826
[19] (2024). *LLM4TDD: Best Practices for Test Driven Development Using Large Language Models.* doi:10.1145/3643795.3648382
[20] (2026). *Requirement-Guided Test-Driven Development for Modular Code Generation with LLM.* doi:10.1145/3803437.3807385
[21] (2024). *Test-in-the-loop LLM Repair: Verifiable Automated Program Repair.* doi:10.69987/jacs.2024.40206
[22] (2024). *Lost in the Middle: How Language Models Use Long Contexts.* doi:10.1162/tacl_a_00638
[23] (2026). *From Prompt to Process: A Process Taxonomy and Comparative Assessment of Frameworks Supporting AI Software Development Agents.* arXiv:2606.04967
[24] (2026). *AI IDEs or Autonomous Agents? Measuring the Impact of Coding Agents on Software Development.* doi:10.1145/3793302.3793589
[25] (2025). *Dear Diary: A Randomized Controlled Trial of Generative AI Coding Tools in the Workplace.* doi:10.1109/icse-seip66354.2025.00034
[26] (2025). *Vibe Coding as a Reconfiguration of Intent Mediation in Software Development.* doi:10.1109/access.2025.3645466
[27] Eberhardt (2025). *Putting Spec Kit Through Its Paces: Radical Idea or Reinvented Waterfall?* https://blog.scottlogic.com/2025/11/26/putting-spec-kit-through-its-paces-radical-idea-or-reinvented-waterfall.html
[28] Code Plain (2026). *Spec driven development: who checks at the end?* https://www.codeplain.dev/en/article/spec-driven-development-who-checks
[29] HumanLayer. *12-Factor Agents* (factors 7–8). https://github.com/humanlayer/12-factor-agents
[30] OWASP. *LLM06:2025 Excessive Agency.* https://genai.owasp.org/llmrisk/llm062025-excessive-agency/
[31] Pant (2026). *Spec-Driven Development, Without the Hype.* https://utsabpant.com/blog/spec-driven-development-without-the-hype
[32] OpenCode. *Permissions* ("last matching rule winning"). https://opencode.ai/docs/permissions/
[33] OpenCode source walkthrough: *Permission* (`evaluate()` uses `findLast`; Wildcard is anchored). https://www.opencode.asia/source-code/permission/
[34] opencode issue #37935 — *permission: broad deny overrides specific allow via findLast() semantics.* https://github.com/anomalyco/opencode/issues/37935
[35] opencode PR #37936 — *fix(opencode): use most-specific-pattern-wins instead of last-match-wins.* https://github.com/anomalyco/opencode/pull/37936
[36] opencode — *packages/opencode/test/permission-task.test.ts.* https://github.com/anomalyco/opencode/blob/02b7eb59/packages/opencode/test/permission-task.test.ts
[37] Anthropic. *Claude Code — Configure permissions* (deny → ask → allow; first match wins). https://code.claude.com/docs/en/permissions
[38] anthropics/claude-code issue #25345 — *Permission rule evaluation docs don't match observed behavior.* https://github.com/anthropics/claude-code/issues/25345
[39] Anthropic. *Claude Code — Agent SDK: Configure permissions.* https://code.claude.com/docs/en/agent-sdk/permissions
[40] (2016). *A verified algorithm for detecting conflicts in XACML access control rules.* doi:10.1145/2854065.2854079
[41] (2011). *Anomaly discovery and resolution in web access control policies.* doi:10.1145/1998441.1998472
[42] (2023). *An innovative two-stage algorithm to optimize Firewall rule ordering.* doi:10.1016/j.cose.2023.103423
[43] (2011). *Network-Level Access Control Policy Analysis and Transformation.* doi:10.1109/tnet.2011.2178431
[44] (2025). *Deny-monotone composition of hierarchical access control policies in distributed systems.* doi:10.21203/rs.3.rs-8290081/v1
[45] (2014). *The Oracle Problem in Software Testing: A Survey.* doi:10.1109/tse.2014.2372785
[46] (2010). *Metamorphic Testing: A Simple Approach to Alleviate the Oracle Problem.* doi:10.1109/sose.2010.31
[47] (2010). *Metamorphic Testing Techniques to Detect Defects in Applications without Test Oracles.* doi:10.7916/d81261jw
[48] (2021). *FIRestarter: Practical Software Crash Recovery with Targeted Library-level Fault Injection.* doi:10.1109/dsn48987.2021.00048
[49] (2025). *A Survey on Failure Analysis and Fault Injection in AI Systems.* doi:10.1145/3732777
[50] (2023). *Exhaustive property oriented model-based testing with symbolic finite state machines.* doi:10.1016/j.scico.2023.005
[51] Temporal. *Long-Running Activity — Heartbeats* ("Test resumption"). https://docs.temporal.io/design-patterns/long-running-activity
[52] Flowproof. *Agent testing* ("the model's decisions are RECORDED, not mocked"). https://automators.ai/flowproof/docs/agent-testing
[53] duskel/cassette — *Deterministic record/replay for LLM and tool calls.* https://github.com/duskel/cassette
[54] Salesforce Engineering (2026). *How to Evaluate AI Agents: Measure Outcomes, Not Responses.* https://engineering.salesforce.com/how-to-evaluate-production-ai-agents-measure-system-outcomes-not-conversations/
[55] Qlarify Labs (2026). *Claimed-vs-actual action testing (agent self-report fidelity).* https://labs.qlarify.fi/evals/claimed-vs-actual-action-testing
[56] Ou (2026). *Evaluating Agents and Capabilities* — AI as an Infrastructure. https://aaai.latere.ai/en/evaluation/evaluating-agents
[57] Conductor (2026). *Agent Evals* ("asserts on what the agent actually did… how the run ended"). https://conductor-oss.github.io/conductor/devguide/ai/agent-evals.html
[58] Microsoft (2026). *Agentic Behavior Engineering* — Azure Architecture Center (stop conditions in the behaviour contract). https://learn.microsoft.com/en-us/azure/architecture/ai-ml/guide/agentic-behavior-engineering
[59] Google Developers Blog (2026). *Evaluating AI agents: moving past the vibe check.* https://developers.googleblog.com/en/evaluating-ai-agents-moving-past-the-vibe-check/
[60] (2020). *Scalable Termination Detection for Distributed Actor Systems.* doi:10.4230/lipics.concur.2020.11
[61] (2022). *Identifying Bias in Self-Reported Pro-Environmental Behavior.* doi:10.1016/j.cresp.2022.100087
[62] (2022). *Bias in Self-Reports: An Initial Elevation Phenomenon.* doi:10.1177/19485506221129160
