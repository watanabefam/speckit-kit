# Spec vs research — independent check of 005 and 006

**Date:** 2026-10-22 · **Mode:** read-only audit. No spec, research file or `AGENTS.md` was edited.
**Subject:** `specs/005-verification-integrity/spec.md` · `specs/006-workflow-orchestration/spec.md`
**Evidence base checked against:** `docs/research/verification-tooling-2026-10.md` (§6, §10, §11 authoritative),
`docs/research/incorporation-decisions-2026-10.md`, `specs/004-reliability-hardening/spec.md`,
`.specify/templates/spec-template.md`, `AGENTS.md`.

## Verdict up front

**Neither spec is ready for `/speckit.plan`.** One CRITICAL finding and five HIGH findings are reported
below. The theses of both specs survive; the evidence attached to them does not, in five specific places.

---

## Method and what was actually run

Local measurements performed for this check (Linux, Python 3.12.3, git 2.43.0):

| # | Experiment | Result |
|---|---|---|
| E1 | `pytest` with no tests (`pytest 9.1.1`) | exit **5**; under a `\|\| true` wrapper the wrapper exits **0** — confirms research §6.3/§7 item 1 and 005 FR-006 |
| E2 | Trivial-compiler-equivalence probe on Python bytecode | `x*2` vs `x+x` **not** TCE-equal; `x/2` vs `x>>1` **not** TCE-equal; identical control and docstring-only change **are** equal — reproduces research §11 round 4: TCE is a *partial* filter in Python |
| E3 | `git merge=union` on a JSONL ledger, two branches | append-only merges clean, order preserved in **both** merge directions (not reversed); an in-place content edit merges cleanly and **silently replaces** the original record — no duplicate id, no conflict, no error |
| E4 | `./scripts/verify` (this repository) | **256 `ok`, 1 skipped section, `SELF-GATE: INCOMPLETE`, exit 0**; no examined-count summary line is printed anywhere; the verdict block (`scripts/self-gate.sh:1477-1491`) contains no `checked > 0` assertion |

E3 differs from the reproduction in research §10 ("order REVERSED", "TWO records for id 1"). The conclusion
that the ledger needs immutable lines, unique ids and a duplicate check still stands — git's own documented
warning about union ordering (`research:380`, which I re-read at source) plus E3's silent replacement are enough —
but the *specific* demonstration in §10 does not reproduce as written. See C-8.

Web research was run in five rounds; see "Research log and convergence" at the end.

---

## 1. Findings

Ordered by severity. Every row cites the spec claim and the evidence it rests on. A finding without both is
not listed.

### CRITICAL

| ID | Severity | Spec `file:line` | Claim as written | Evidence `file:line` | What is wrong | Minimal fix (one sentence) |
|---|---|---|---|---|---|---|
| **C-01** | CRITICAL | `specs/005-verification-integrity/spec.md:289` | Out of Scope: "**Blocking on secret scanning** — vendor-shaped tokens only; a design rule (secrets come from the environment) is the real control." | same file `:224` (FR-025): "A blocking stage MUST be limited to high-confidence classes and MUST NOT be enabled before a baseline exists"; `:223` FR-024 | The normative sections require a blocking security stage; the Out of Scope section rejects blocking on secret scanning. An implementer reading Out of Scope drops a MUST. This is the research's "blocking was **narrowed**, not dropped" correction (`research:401-404`) leaking back into a rejection. | Reword to "blocking on *pattern-only* secret matches" and state that high-confidence confirmed classes are staged in, per FR-025. |

### HIGH

| ID | Severity | Spec `file:line` | Claim as written | Evidence `file:line` | What is wrong | Minimal fix (one sentence) |
|---|---|---|---|---|---|---|
| **H-01** | HIGH | `005:27` | "A pinned security scanner suite missed a hand-written production password in **8 of 8** probe variants; the ones that fired only recognised **vendor token shapes**." | `research:181-189` (table: 7 rows), `research:191` and `research:484` ("0 of 6"), `research:296` ("seven synthetic variants"), `research:178` ("caught **both** the password and the token") | Three defects in one sentence. (a) "8 of 8" appears nowhere; every count in the research is 6 or 7. (b) The custom rule fired on a hand-written password (`research:178`), so "the ones that fired only recognised vendor token shapes" is false as written. (c) The table's first row (`:183`) shows all three tools catching module-level `ALL_CAPS` while the prose (`:175-176`) says gitleaks missed the password — the row's literal is never shown, so the 6-vs-7 denominator is uncheckable. | Restate as "missed 6 of 7 variants in the probe table, including every non-module-level shape", and say which tool caught which. |
| **H-02** | HIGH | `005:103`, `005:105`, `005:109`, `005:220` | US5: "gets a short list of specific, named **weaknesses**: 'this comparison could be inverted and no test would notice'"; Key Entity "Mutant Finding … status (survived / killed / equivalent-or-unknown)"; FR-020 "bounded list of named survivors" | `research:465` — "rule-based survivors carry only a **4.4%/5.7%** verified-fault rate → ~95% of survivors are candidates, not findings" | The story tells the owner the list *is* weaknesses; the spec's own evidence says ~95% of those line items are not faults. The no-threshold decision was justified by this number, then the narrative re-promises exactly what the number forbids. | Say the list is "candidates to check", and require the label `candidate` (not `weakness`) on every survivor. |
| **H-03** | HIGH | `005:98` (US4 scenario 5), `005:246` (FR-033), `005:277` (SC-008) | "reports how many changed lines the executed tests actually reached… new code exercised by no test is 'looked at nothing'"; SC-008 "a change whose new lines **no test** executes is reported as unexercised" | `005:15` FR-015 (default verification runs a *subset*); `research:54` and `research:252` (diff_cover gates the *changed lines*); diff-cover's documented input is a coverage report produced by a test run | The measurement is defined against "the executed tests", i.e. the selected subset, but the conclusion drawn is about *no test*. A selected run that omits covering tests reports a line as unexercised when it is exercised — a false alarm of exactly the kind the feature exists to prevent, and SC-008 cannot hold in default mode. | Require the changed-line profile to come from the full-suite run (or an accumulated profile), and scope the *selected-run* sentence to "not reached by the selected tests". |
| **H-04** | HIGH | `006:216-217` (FR-001, FR-002), `006:201` (edge case "both claim the same one at the same instant: one wins"), `006:287` (SC-001) | "the declaration MUST be visible to every other worker"; "A second worker MUST NOT be able to take a task already declared"; "one wins" | `006:229` (FR-011 resume "from a checkout on a different machine"), `006:305` ("Two workers may be two agents, or one agent and one human"); upstream model: claims are file state with a 2-hour lease and `--force` takeover (SpecWeave handoff docs) | Exclusivity is required but no coordination substrate is named, and the only substrate the source uses (a file plus a lease) is not atomic across checkouts — two machines cannot both observe a claim that has not been pushed. "One wins" is unimplementable as specified. | Name the substrate and require atomic acquisition (create-exclusive lock, or a ref update with an expected old value), or scope FR-001/FR-002 to a single working tree. |
| **H-05** | HIGH | `006:216-265` (all FRs) | No requirement covers worktree isolation | `incorporation-decisions:21` (superpowers "worktree isolation" → lands in **006**), `:82`; `specs/004-reliability-hardening/spec.md` Non-Goals defers "worktree isolation"; independent corroboration: Claude Code agent teams isolate each subagent in its own worktree | The audit explicitly assigned worktree isolation to 006 and 006 silently dropped it; it is the mechanism current practice relies on for the same problem (claim + worktree + dependency markers). | Add an FR for per-worker workspace isolation, or record the rejection with a reason. |

### MEDIUM

| ID | Severity | Spec `file:line` | Claim as written | Evidence `file:line` | What is wrong | Minimal fix (one sentence) |
|---|---|---|---|---|---|---|
| **M-01** | MEDIUM | `005:284` | "Verdicts flip on harmless **reordering** (~13.6%)" | `research:275` (same wording); the cited study, arXiv:2606.13685 (fetched): "repeated identical evaluations… pairwise preferences flip on average 13.6% of the time" | The number is real; the mechanism is not. 13.6% is **run-to-run self-inconsistency on identical input** in *pairwise preference* judging of model outputs — reordering/position bias is a separate finding (72% A-majority) in the same paper. The rejection of judge verdicts survives (arguably stronger), but it is justified by evidence about a different task. | Cite it as "flips on repeated identical runs (13.6%)", and note that the transfer from output-preference judging to code gates is an extrapolation. |
| **M-02** | MEDIUM | `005:27`, `005:122`, `005:281` | "False-positive rates for secret scanners in the literature run **25–99%**" | `research:401-405` attributes the range to Basak et al. ICSE 2025 (`doi:10.1109/icse55347.2025.00067`) | That DOI resolves to **AssetHarvester**, whose headline is "detects secret-asset pairs with **0% false positives**". The 25–99% range may be quoted *inside* that paper, but the pairing reads as the paper's own result. Could not fetch the PDF (ACM 403). Corroborating direction exists (Rahman 2022: 50% of warnings false positive; GitHub, Jun 2026: 75.76% FP reduction needed). | Re-cite to the paper that reports the range, or downgrade to "reported false-positive rates are high (25–99% by one cited account)". |
| **M-03** | MEDIUM | `005:188` (FR-004) | "The system MUST **detect** a check whose expected value is produced by the code under test" | `research:446`, arXiv:2608.17214 (fetched) — the paper *names and measures the cost* of oracle anchoring (3 mutants of 12 recovered by model-free property suites), and detects it by a **hand-performed anchoring analysis plus interventions**, not by an automated detector | The spec turns a diagnosed defect class into a MUST-detect with no evidence that detection is tractable; the only cited work found instances by manual reasoning over 4 modules. | Add "detectable by a declared oracle-source annotation, checked mechanically" — i.e. require the *declaration*, not a semantic detector. |
| **M-04** | MEDIUM | `005:189` (FR-005) | "Each mandatory check MUST declare a negative control… and the control's rejection MUST be reported" | No citation in `research` or `incorporation-decisions`; the only prior art is the kit's own gate (`scripts/self-gate.sh:707-727`) | An untraced requirement — it is a good idea, and it is already implemented in this repository, but it has no research trace despite §A's rule that every FR trace to one. | Point FR-005 at `scripts/self-gate.sh:707-727` as the precedent, as FR-003 already does for the verdict. |
| **M-05** | MEDIUM | `005:215-219` (FR-019…023) | Mutation analysis "scoped to changed files", survivors reported, no percentage threshold | `research:392-396` (§10 corrections): survivors as goals; **extreme mutation** (whole-method, faster/less precise, Betka & Wagner 2022); separate semantic/functional/incidental/**crash** kills (SecMutBench 2026); "keep any percentage as a soft budget, never a pass/fail" | Three mechanisms the research adopted are absent from the spec, with no stated rejection: extreme mutation, kill-quality classification, soft budget. The kill-quality one matters — a mutant "killed" by a crash is not evidence, and FR-022's `equivalent-or-unknown` does not cover it. | Add kill-quality classes to FR-022, and state whether extreme mutation and a soft budget are adopted or rejected. |
| **M-06** | MEDIUM | `005:218` (FR-022) | "Behaviourally equivalent or unclassified mutants MUST be labelled as such" | `research:465` (TCE is the named standard filter and is **partial** in Python), reproduced by E2 | The spec quietly drops the only named equivalence *filter*: no requirement asks for any automated pre-filter, so "equivalent-or-unknown" becomes a human judgement over ~95% noise. The research's round-4 correction ("must not be ported as a complete one") is respected; the mechanism is not adopted at all. | Add "TCE (bytecode equality) MUST be applied as a partial pre-filter, and its misses MUST NOT be reported as equivalent". |
| **M-07** | MEDIUM | `005:223-228` (FR-024…028) | Observe-only stage → blocking on high-confidence classes | `research:401-403`: the ladder is "(1) **scheduled broad full scan on the main branch**, (2) **diff-aware scan on pull requests** with a fine-tuned high-confidence ruleset, (3) only then enable blocking" | Stages 1 and 2 are missing: nothing requires a scheduled broad scan, and nothing requires scanning only the diff on PRs. The spec keeps stage 3 and a baseline, which is the shape but not the sequence. | Add the scheduled broad scan and the diff-aware PR scan as ordered stages. |
| **M-08** | MEDIUM | `005:289` | "a design rule (secrets come from the environment) is the real control" | `research:194-198`: "The floor has to be a human rule enforced by review ('secrets come from the environment, never from a literal') plus a scanner for the token shapes. **Do not let a green secret scan stand in for that rule.**" | The research's stated *real control* is named in Out of Scope and then never required anywhere; the spec requires the scanner and not the rule that the scanner cannot replace. | Add a requirement that the env-only rule is enforced by review, or state explicitly that it is out of this feature's mechanical scope. |
| **M-09** | MEDIUM | `006:18`, `006:307` | "The two are independent… Neither depends on the other shipping first"; "this spec does not depend on it beyond FR-007's reference" | `006:222` FR-007: "A task MUST NOT be recorded complete without evidence of a check having run (**005 FR-001…FR-006 govern what counts**)" | FR-007 is a normative dependency on 005's vacuity rules, and 005 has not shipped. The word "beyond" concedes the dependency while the paragraph above denies it. Also: FR-007 is the only 006 requirement with **no** success criterion. | Either drop the FR-007 parenthetical and define "evidence" locally, or state that 006 depends on 005 for FR-007 and add an SC for it. |
| **M-10** | MEDIUM | `006` (absent) | — | `incorporation-decisions:22` ("dependency-wave batching; cross-spec contradiction review"), `:84` ("task-start prints a BASE SHA that task-done records"), `:90-91`, `:108` ("glossary check --strict") | Four audit adoptions assigned to 006 are not requirements: dependency-wave batching (FR-005 gives dependencies but no waves), cross-spec contradiction review (FR-026 is limited to *amendments*), the BASE..HEAD change-range binding, and the glossary check. | Land them or reject each with a reason, as 006 does for agent-os/BMAD/task-master. |
| **M-11** | MEDIUM | `006:227` (FR-009), `006:229` (FR-011) | Stopping "MUST preserve uncommitted work in a form another session can recover"; resume from another machine | Upstream source the audit used (SpecWeave handoff docs, fetched): handoff "pushes… a snapshot of your uncommitted edits to a well-known handoff ref… **Scrubs secrets from the free-text fields and the diff** before writing anything" | The mechanic the spec adopts pushes uncommitted work to a remote and the spec has no requirement that it be scrubbed — the one safety step in the upstream design that this spec's own 005 evidence (hand-written secrets are not detected) makes load-bearing. | Add "the handoff snapshot MUST be scrubbed for credential-shaped content before it is written or pushed". |
| **M-12** | MEDIUM | `006:120-143` (US4), `006:243-246`, `006:284` SC-005 | "An owner gets a review they can act on"; findings separated into two stages; outcome states distinguishable | `incorporation-decisions:151` — the "reviewer that files findings was NOT rejected" rests on cc-sdd/SpecWeave being `[read]`; `006` cites no accuracy evidence; independent: Jin 2026, "Are LLMs reliable code reviewers?", reports LLMs "frequently issue false negative judgments, incorrectly concluding that correct implementations fail to meet stated requirements" | US4 is the only story in either spec whose quality signal is a model's prose output, and it is the only one with no evidence about that model's error rate. The 13.6% instability that 005 uses to reject verdicts is declared "a different failure mode" without evidence. SC-005 measures state distinguishability, never finding precision. | Add a requirement that findings carry a confidence/evidence label and that a review's precision is measured on a labelled sample before it is trusted. |
| **M-13** | MEDIUM | `005:215-219` | Mutation source is rule-based (mutmut), survivors as review prompts | `research:465` cites Kiele et al. ESEM 2026 (`doi:10.4230/LIPIcs.ESEM.2026.49`), fetched: **test-aware LLM mutant generation yields 87.7% (HumanEval) / 79.1% (MBPP) verified-fault rates vs mutmut's 4.4% / 5.7%**, i.e. ~16× fewer candidates per finding | The spec adopts the technique whose own cited paper reports it is the weakest of the compared sources, and neither adopts nor rejects the stronger one. This is a best-implementation gap, not an error. | Record test-aware generation as a considered alternative with the 4.4% vs 87.7% numbers, even if rejected for cost. |

### LOW

| ID | Severity | Spec `file:line` | Claim as written | Evidence `file:line` | What is wrong | Minimal fix (one sentence) |
|---|---|---|---|---|---|---|
| **L-01** | LOW | `005:13` | Companion is "informative; **452 lines**" | `docs/research/verification-tooling-2026-10.md` is **496 lines** (`wc -l`) | Stale count; the document grew after the pointer was written. | Drop the line count, or update it. |
| **L-02** | LOW | `005:273` (SC-004) | "≤**25%** of the full-suite time (baseline: full gate ≈3.5 minutes)" | `research:221` — ≈3.5 min is a `[measured]` figure on the research machine for `--no-e2e`; my E4 run on this VM produced 256 items (research: 213) and one skipped section | SC-004 is machine- and dependency-bound, and the 25% is an invented threshold with no source. | State the baseline command and machine, or make the SC relative to a same-machine full run. |
| **L-03** | LOW | `005:301` | "`scripts/verify` … has **not yet** been measured against FR-001/FR-002" | E4: `./scripts/verify` → 256 ok, 1 skip, `INCOMPLETE`, **exit 0**; `scripts/self-gate.sh:1477-1491` has no examined-count guard | No longer unmeasured, and the measurement answers the question in the negative for FR-001/FR-002 at the verdict site: the gate counts per-assertion `ok` lines but never reports a total or refuses on zero. | Replace the assumption with the measurement and its result. |
| **L-04** | LOW | `005:287` vs `005:194-196` | Out of Scope: "**Test-to-criterion traceability matrices** — no empirical support"; FR-007…009 require a per-criterion evidenced tally | `research:462` (round 3: "Traceability rejected… AC tally re-justified on *mechanism* grounds only") | The two are defensible but the distinction is never stated, so the Out of Scope bullet reads as rejecting FR-007's mechanism. | Add one clause: matrices are rejected as evidence *of detection quality*; the tally is kept as an anti-`0/0` mechanism. |
| **L-05** | LOW | `005:280` | "Deliberately excluded, with reasons recorded in the research companion **§10**" | Traceability rejection is in `research:462` (**§11 round 3**); the second-framework rejection is in `research:277` (§7) | Wrong anchor for at least two bullets. | Point at §7/§11 as well as §10. |
| **L-06** | LOW | `006:202`, `006:208` | Edge cases: stale claim "visible as stale **and reclaimable**"; "Boundary declared but empty: … an error, not a free pass" | `006:221` FR-006 requires only identifiability "with its age"; no FR covers reclaim-in-place or the empty boundary | Two edge-case obligations have no requirement behind them, so a plan built from the FRs will miss them. | Add the reclaim step to FR-006 and an FR for the empty boundary. |
| **L-07** | LOW | `006:25` | "This kit is currently the strongest on *verification* and the weakest of the four on *orchestration*" | `incorporation-decisions` records no comparative ranking; the audit's own scoring is per-mechanic | An unsourced comparative claim in a section introduced as "Measured and read evidence". | Delete the ranking or cite what it is based on. |
| **L-08** | LOW | `006:100-116` (US3), `006:235-238` | Test-first "is a mechanic, not a request"; pre-test implementation "MUST be discarded" | `incorporation-decisions:79-81` `[read]` (superpowers README); no measurement in either research doc; TDD's defect-reduction evidence is contested in the literature | US3 rests on a `[read]` README line and a plausible mechanism, and the spec states no evidence grade for it while grading everything else implicitly. | Mark US3 as mechanism-justified, not evidence-justified. |
| **L-09** | LOW | `005:208-212` (US3/FR-010…014) vs `006:216-218` (claims) | Ledger immutability + unique-id duplicate check live in 005 | `research:357` — item 3's requirements (immutable lines, unique ids, duplicate check, timestamp ordering) are the same mechanism a claim store needs | The same append-only-with-unique-ids substrate is specified in 005 for evidence and required in 006 for claims, with no cross-reference; 006's H-04 substrate fix would reuse it. | Have 006 cite 005's ledger requirements as the claim store's substrate, or say why claims need a different one. |
| **L-10** | LOW | `005:27` (root cause) | "0 of 6" / "seven variants" / "8 of 8" | `research:183-189` (7 table rows), `:191` ("0 of 6"), `:296` ("seven synthetic variants") | The research's own denominator is ambiguous because row 1's literal is never shown; this ambiguity is the origin of H-01. | Show the literal in row 1 and state the denominator explicitly. |

---

## 2. Per-spec verdict

**005-verification-integrity — `overstated`.** The thesis (a green result must be earned) is sound and the
requirements mostly trace, but the headline evidence paragraph misstates the security measurement in three
ways (H-01), one story sells a 95%-noise list as "named weaknesses" (H-02), the changed-line measurement draws a
full-suite conclusion from a subset run (H-03), and the Out of Scope section contradicts a MUST (C-01).

**006-workflow-orchestration — `sound with fixes`.** Its two P1 stories rest on verified upstream mechanics
(claims with leases, handoff with an uncommitted snapshot and a cross-machine pickup — I re-read the SpecWeave
docs), but the collision requirement has no coordination substrate (H-04), the isolation mechanism its own audit
assigned to it is missing (H-05), and the stated independence from 005 is contradicted by FR-007 (M-09).

**Stop condition is met:** 1 CRITICAL + 5 HIGH ⇒ **not ready** for `/speckit.plan` until C-01, H-01…H-05 are resolved.

---

## 3. Dropped recommendations

Every research/audit item marked *adopt*, *steal*, *incorporate*, or *revised mechanism* and whether a
requirement covers it.

### 3.1 Research §7 plan items → 005

| Item | Landed? | Where |
|---|---|---|
| 1 Empty-check invariant | **yes**, broadened | FR-001…003, FR-006 |
| 2 AC tally | **yes** | FR-007…009 |
| 3 Append-only ledger | **yes** | FR-010…014 |
| 4 Changed-lines gating | **yes** | FR-015…017, FR-033/034 (but see H-03) |
| 5 Mutation as opt-in review | **partial** | FR-019…023 landed; extreme mutation, kill-quality classes, soft budget dropped silently (M-05) |
| 6 Pinned security CI | **partial** | FR-024…028 + FR-035/036 landed; ladder stages 1–2 and the env-only design rule dropped (M-07, M-08) |
| 7 Property prompt grounded in spec rules | **yes** | FR-029, FR-030, FR-037 |
| 8 `pass^k` reporting | **yes** | FR-031, FR-032 (both figures required — the 0.59/0.65 correction is honoured) |

### 3.2 Audit adoptions → 005/006

| Adopted mechanic | Lands in | Landed? | Note |
|---|---|---|---|
| superpowers: TDD delete-work-before-tests | 006 | **yes** | FR-015 |
| superpowers: two-stage review | 006 | **yes** | FR-018, FR-019 |
| superpowers: worktree isolation | 006 | **DROPPED** | H-05 — no stated reason |
| superpowers: task-start BASE SHA ↔ task-done | 006 | **partial** | declare/complete pair exists; no change-range binding (M-10) |
| cc-sdd: boundary-first tasks (`_Boundary:_`, `_Depends:_`) | 006 | **yes** | FR-003…005 |
| cc-sdd: dependency-wave batching | 006 | **DROPPED** | M-10 |
| cc-sdd: cross-spec contradiction review | 006 | **partial** | FR-026 covers amendments only (M-10) |
| specweave: claims | 006 | **yes** | FR-001, FR-002, FR-006 |
| specweave: handoff / pickup with uncommitted snapshot | 006 | **yes** | FR-008…011 |
| specweave: `review` exit-3 third state | 006 | **yes** | FR-020 |
| specweave: `note` | 006 | **yes** | FR-031 |
| specweave: committed memory | 006 | **yes** | FR-030 |
| specweave: `glossary check --strict` | 006 | **DROPPED** | M-10 |
| specweave (upstream, not in audit): scrub secrets from the handoff snapshot | 006 | **DROPPED** | M-11 |
| OpenSpec: delta specs | 006 | **yes** | FR-023 |
| OpenSpec: dated archive | 006 | **yes** | FR-024 |
| OpenSpec: in-flight `changes/` | 006 | **yes** | FR-025 |
| diff_cover: coverage on changed lines | 005 | **yes** | FR-033/034 (see H-03) |
| trufflehog: verified-credential tier | 005 | **yes** | FR-035/036 |
| schemathesis: schema-driven property instance | 005 | **yes** (optional) | FR-037 |
| reviewdog: findings on the PR diff | 006 | **yes** | FR-027, FR-028 |
| pre-commit: local runner for cheap gates | 006 | **yes** | FR-029 |

**Dropped without a stated reason: 3 audit adoptions** (worktree isolation, dependency-wave batching, glossary
check) **plus 1 upstream mechanic never listed** (handoff secret scrubbing), **5 mechanism-level items** (extreme
mutation, kill-quality classification, soft budget, TCE pre-filter, test-aware mutant generation) and **1
research-stated control** (secrets-from-the-environment).
Everything in the specs' Out of Scope sections *does* carry a reason, except the ones C-01 and L-04 show to be
worded against their own requirements.

---

## 4. Cannot verify

| Item | Why not | What would settle it |
|---|---|---|
| The **25–99%** false-positive range | The DOI cited for it resolves to AssetHarvester, whose own abstract claims **0%** FP for secret-asset pairs; ACM returned 403 for the full text, and targeted searches for the range returned nothing | The paper PDF, or the specific sentence in Basak et al. that states the range |
| SpecWeave 3.1.5's **measured** holes (`--evidence "reviewed it myself"` → rc=0; `ACs 0/0` → PASS) | `specweave` is not installed here and the audit already ran it; I did not install it to avoid polluting this workspace | `npx specweave …` in a scratch project, or the audit's original transcript |
| Research §6's tool numbers (gitleaks 0.45 s, semgrep 3.65 s, osv 60 findings, mutmut 11/18, hypothesis counterexample) | Those tools are not installed here | Re-running §6's fixture with the pinned versions |
| The **0.65** empirical `pass^5` | The research states the harness used a synthetic per-task difficulty distribution (`research:288`); my arithmetic confirms only `0.9^5 = 0.590` | The harness plus its 40 task probabilities |
| TCE behaviour under **Python 3.14.6** | This VM has 3.12.3; my E2 reproduces the *conclusion* (partial filter) but not the bit-identical bytecode | Re-run E2 on 3.14 |
| Whether 13.6% carries from **pairwise preference judging** to **code-gate reviewing** | No study measures the latter; the cited paper is about comparing model outputs | A study of reviewer-model verdict stability on code diffs |
| The size of the reviewer error rate (M-12) | Only the abstract of Jin 2026 was readable (Springer page); the magnitude is not quoted in either research doc | The full paper, or a local measurement on a labelled diff sample |
| Research §10's exact `merge=union` reproduction ("order REVERSED"; "TWO records for id 1") | E3 on git 2.43 did not reproduce either symptom: order was stable in both directions and the in-place edit merged to a single replaced record with no duplicate | The §10 script, or a stated git version; the *requirement* (immutability + unique ids + duplicate check) is still justified by git's documented warning and E3's silent replacement |
| The `pass^k` script (research §7 item 8) landing in `evals/` | 005 requires the *reporting*, not the location; not a defect, just an unimplemented detail | `/speckit.tasks` |

**Where the handover prompt is wrong** (checked against the files, as instructed):

- It says "Python 3.14.6 and `git` are available; `gh` is authenticated". Here: Python **3.12.3**, git **2.43.0**, `gh` **not** logged in. No experiment depended on `gh`.
- It says there is no `timeout` command; not exercised — no command needed one.
- Its stated counts are otherwise **correct**: 005 = 301 lines / 8 stories / 37 FRs / 9 SCs; 006 = 307 / 7 / 32 / 7; research = 496 lines. FR/SC ids are unique and sequential in both specs (`grep … | sort | uniq -d` → empty).
- Its "0 of 6" matches the research's own wording but not its table (7 rows), which is finding L-10.
- Its claim that the specs are "not yet built" is correct: `specs/005-verification-integrity/` and `specs/006-workflow-orchestration/` contain only `spec.md`.

---

## 5. Counts

*(Counts as audited, before any repair. §7 records the counts after the fixes were applied.)*

| | 005 | 006 |
|---|---|---|
| Functional requirements | 37 | 32 |
| Traced to a citation or measurement | **36** | **32** (FR-007 traces to 005, not to a source; FR-026 traces loosely) |
| **Untraced** | **1** (FR-005, M-04) | 0 |
| Traced but resting on a `[read]` source only | 7 (FR-019…023 on `[read]` practice literature; FR-035/036 on audit `[read]` rows) | 13 (every landed audit mechanic is `[read]` except specweave's measured holes) |
| Drafts where a `[read]` claim is presented as measured | 1 (H-01's "pinned scanner suite… 8 of 8" reads as measured; the measured result is 0 of 6) | 0 (the spec is silent rather than wrong — M-12) |
| Requirements added "by the audit" mismatching what the audit said | 2 (H-01 misstates the measured secret result; FR-033 draws a wider conclusion than diff_cover's diff-scoped metric supports) | 3 (three audit adoptions dropped, FR-026 narrowed to amendments only) |
| FRs with no success criterion | 5 (FR-001 only implicitly via SC-002, FR-005, FR-014, FR-034, FR-036) | 1 (FR-007) |
| User stories / SCs | 8 / 9 | 7 / 7 |
| Stories with ≥2 Given/When/Then | 8/8 | 7/7 |
| Adoptions landed / partial / dropped | 8/8 research items landed (2 partial on sub-mechanics) + 3/3 audit adoptions landed; 0 dropped | of 18 audit mechanics: **13 landed, 2 partial, 3 dropped** |

Numbers cross-checked against the research and all consistent except where H-01/L-10 say otherwise: gate ≈3.5 min
and 213 ok/0 bad/0 skip ✓ (§6.6, machine-specific); 11 of 18 mutants at 100% line coverage ✓; 25–99% FP
(unverified, M-02); 4.4%/5.7% survivor fault rate ✓ (verified at source); `pass^5` 0.59 constant vs 0.65
empirical — **both** appear in the spec, correctly paired ✓; 0/6 secret variants ✓ (spec says 8/8 ✗); 13.6%
judge instability ✓ number / ✗ mechanism (M-01); 84% transitions and 16% tests flaky at Google ✓ (verified at
source).

### Sections checked and found sound (no findings)

- Both specs comply with `.specify/templates/spec-template.md` shape (Document Status and Key Entities are
  additive, not omissions).
- 005 US4's flaky classification (FR-018) matches the Google evidence and is the right mechanism.
- 005's `pass^5` handling is exactly right: FR-032 requires the pessimistic bound beside the empirical figure.
- 005 correctly refuses to claim TCE is complete — it claims nothing about TCE at all (the defect is the
  silence, M-06, not an overclaim).
- 006 US5 maps cleanly onto OpenSpec's documented delta/archive mechanics, including the "in-flight vs settled"
  distinction (verified at source).
- 004/005 overlap is **not** duplication: 004's US1 governs `scripts/self-gate.sh`, 005 governs `scripts/verify`
  and downstream reports, and 005:15 says so.
- Requirement ids are unique and sequential in both specs; every FR sits under a story; every story has ≥2
  acceptance scenarios.

---

## 6. Research log and convergence

Criterion fixed before round 3: **stop when a full round adds no finding that could change a plan or a
verdict.** Rounds are web research plus a local experiment where one could settle the question.

| Round | Targeted | Outcome |
|---|---|---|
| 1 | Load-bearing citations: Kaufman ICSE 2022 (thresholds), Google flaky 84/16, Facebook PTS >99.9% | All three **confirmed at source**. No finding. |
| 2 | 13.6% judge instability; trufflehog verification; 25–99% FP; TCE limits | 13.6% **confirmed but misattributed** (M-01); trufflehog mechanism **confirmed**; 25–99% **not locatable** and mis-paired (M-02); TCE limitation **confirmed** |
| 3 | SpecWeave handoff/claims/lease; superpowers TDD claim | Upstream docs read: claims use a **lease + `--force`**, handoff **scrubs secrets** (new finding, M-11); "deletes code written before tests" **confirmed verbatim** |
| 4 | diff-cover's input contract; jest empty-suite default; OpenSpec deltas; `pass^k` definition | diff-cover consumes a coverage report from a run → **new finding H-03**; jest exits 1 by default but `--passWithNoTests` flips it (supports FR-006); OpenSpec and `pass^k` **confirmed** |
| 5 | spec-kitty #569 dedupe driver; LLM reviewer accuracy; incremental mutation; TDD evidence | #569 **confirmed**; Jin 2026 reviewer overcorrection → **new finding M-12**; incremental mutation is established practice (supports FR-019); TDD evidence contested → **L-08** |

**Converged — stop declared at round 5.** Rounds 4 and 5 each produced one substantive finding (H-03, M-12) and
one LOW (L-08); every remaining open question is blocked on a source that is not obtainable here (paywalled PDFs,
the research machine's tool versions) rather than on more searching. Further rounds would add citations, not
change a verdict. Note that the audit's own convergence claim (`research:472`) covers the *research*; it did not
cover the specs, and the specs' three largest defects (H-01, H-02, H-03) arose in the translation from research
to requirement, not in the research itself.

### Sources read in this session (beyond the repository)

Kaufman et al., ICSE 2022 (`doi:10.1145/3510003.3510187`, quoting "no known industrial application of mutation
testing uses or even computes mutation adequacy") · Leong et al., ICSE-SEIP 2019 (84%/16%) · Facebook Predictive
Test Selection (`arXiv:1810.05286`) · Yagubyan, *The Coin Flip Judge?* (`arXiv:2606.13685`) · Hill, *Four Ways to
Forge a Bundle* (`arXiv:2608.26183`) · Canedo, *Oracles That Cannot Fail* (`arXiv:2608.17214`) · Kiele et al.,
ESEM 2026 (`doi:10.4230/LIPIcs.ESEM.2026.49`) · AssetHarvester, ICSE 2025 (`doi:10.1109/ICSE55347.2025.00067`) ·
Soltaniani & Ghafari, EMSE (`doi:10.1007/s10664-026-10929-w`) · Rahman et al. 2022 (50% of secret warnings false
positive) · GitHub Security blog, *Reducing false positives at scale* (2026-06-11) · TruffleHog verification docs ·
git `gitattributes` manual · OpenSpec concepts (`changes/archive`, ADDED/MODIFIED/REMOVED/RENAMED) · SpecWeave
*cross-tool handoff* docs · `obra/superpowers` README · `spec-kitty` issue #569 · Jin 2026, *Are LLMs reliable
code reviewers?* (`doi:10.1007/s10515-026-00638-5`) · Mull/Stryker incremental mutation docs · Claude Code agent
teams shared-task-list write-up (worktree + claim + dependency triad).

---

## 7. Resolution (same session, 2026-10-22)

Everything below was applied to the specs and to the earliest affected artifact in the research docs (their
own correction sections — earlier text left intact, per their convention). The stop condition is lifted:
**no CRITICAL and no unresolved HIGH remain**, so both specs may move to `/speckit.plan`.

| Finding | Status | What changed |
|---|---|---|
| C-01 | **fixed** | 005 Out of Scope rejects **pattern-only** blocking only; FR-025 requires blocking to be limited to confirmed-live findings and recorded rule classes |
| H-01 | **fixed** | 005's headline now reads "6 of the 7 shapes"; the denominator contradiction is recorded in `verification-tooling-2026-10.md` §12 item 1 |
| H-02 | **fixed** | US5, FR-020, FR-038, SC-010 — survivors are *candidates*, kill status is recorded, ~95% noise stated in the story |
| H-03 | **fixed** | FR-033/FR-034 and SC-008 require the coverage profile to be named; only a full-suite profile supports "no test executes this" |
| H-04 | **fixed** | FR-001 names atomic acquisition (exclusive create, or a conditional ref update with an expected old value); FR-006 adds lease + recorded takeover; 006 SC-008 and a new US1 scenario test it |
| H-05 | **fixed** | 006 FR-033: one `git worktree` per worker; Key Entities gained **Checkout** |
| M-01 | **fixed** | 005 Out of Scope and research §12 item 2 state run-to-run self-inconsistency, not reordering |
| M-02 | **partially fixed** | wording now "25–99% by one cited account, not measured here"; research §12 item 3 records that the cited DOI is AssetHarvester (0% FP for its own tool). The range itself is still unverified — see "Cannot verify" above |
| M-03 | **fixed** | FR-004 now requires a declared oracle source and excludes undeclared checks; US1 scenario 2 rewritten |
| M-04 | **fixed** | FR-005 cites `scripts/self-gate.sh:707-727` as its precedent |
| M-05 | **fixed** | FR-038 (kill status), FR-039 (extreme mutation, labelled and never the default), FR-021 (soft budget only), US5 scenario 4 |
| M-06 | **fixed** | FR-022 requires a TCE pre-filter and forbids treating its misses as equivalent |
| M-07 | **fixed** | FR-024 (baseline from a scheduled broad scan), FR-040 (broad scan exists), FR-041 (diff-aware scan shares the pinned rule set) |
| M-08 | **fixed** | FR-042: the environment-only rule is reported as the control; SC-009 forbids a green scan standing in for it |
| M-09 | **fixed** | 006's relationship paragraph now states the one definition dependency; FR-007 carries a fallback definition; SC-009 measures it |
| M-10 | **fixed** | FR-035 (base commit + range), FR-036 (waves), FR-040 (terminology), FR-026 widened to batch contradictions |
| M-11 | **fixed** | FR-037 + SC-010: redact or do not push; US2 scenario 5 |
| M-12 | **fixed** | FR-019 (stage + confidence), FR-038 (how established), FR-039 (precision on ≥20 labelled findings), SC-011, US4 scenario 5 |
| M-13 | **fixed** | Rejected-with-reason bullet in 005 Out of Scope carrying 87.7%/79.1% vs 4.4%/5.7%; research §12 item 7 |
| L-01…L-05 | **fixed** | No line count; SC-004 is same-machine; the `scripts/verify` measurement replaces the assumption; the traceability distinction and the §7/§10/§11 anchors are stated |
| L-06 | **fixed** | FR-006 adds reclaim; FR-034 rejects an empty boundary at plan-read time |
| L-07 | **fixed** | The unsourced ranking is replaced by a checkable statement (the kit ships none of these mechanics) |
| L-08 | **fixed** | 006 US3 states its justification is mechanistic and that the TDD literature is contested |
| L-09 | **fixed** | 005 FR-012 names the record shape as a reusable claim substrate |
| L-10 | **fixed to the limit of the record** | The table's row-1 literal was never recorded, so §12 item 1 states the ambiguity and fixes the denominator (7 probed / 6 missed / 1 caught) rather than inventing the literal |

**Counts after repair:** 005 — 42 FRs, 10 SCs, 8 stories; 006 — 40 FRs, 11 SCs, 7 stories. Ids unique and
sequential in file order, every FR under a story, every story with ≥3 acceptance scenarios, no stale figures
(`8 of 8`, `452 lines`, `harmless reordering`, `weakest of the four` all absent).

**Still open, deliberately:** the 25–99% range's primary source (M-02) is blocked on a paywalled PDF. It no
longer supports any requirement, so it does not block the plan.

### Verification run

`./scripts/verify` (which is `make test` → `scripts/self-gate.sh`) was run twice: once before the repair and
once after.

| Run | Result |
|---|---|
| before (11:11) | **256 ok, 1 skipped section, `SELF-GATE: INCOMPLETE`, exit 0** — the skip was "specify CLI not on PATH" |
| after | **263 ok, 0 FAIL, 0 skip, `SELF-GATE: PASS`, exit 0** |

The two runs are not directly comparable, and the difference is *not* caused by these edits (the gate does
not read these specs): the first run's own installer assertion deposited a `specify` CLI into
`~/.local/bin`, so the second run executed seven additional drift assertions instead of skipping them. The
state change is a side effect of the gate testing the installer. Both results are recorded here because
the first is what L-03 relies on and the second is the post-repair state; neither is a regression.
