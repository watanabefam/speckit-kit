# Verification tooling & spec frameworks: adopt, incorporate, or reject

**Date:** 2026-10-22
**Scope:** Does anything existing take software work to production quality *unattended*?
If not, what should this kit take from the field?
**Method:** live install-and-run on a purpose-built fixture, plus GitHub API facts, plus
cited literature. Every number marked **[measured]** was produced on this machine today;
anything marked **[read]** comes from the project's own docs and was not executed here.

---

## 0. The answer in one paragraph

No surveyed tool takes a change from idea to trustworthy production state without a human
in the loop. The best measured result on realistic engineering tasks is 64–75% for
deployment-style work, and a human directing the agent is worth roughly 20 points. What the
field *has* solved is narrower and more useful: **machine-checkable evidence**. Every
framework that resembles this kit (`Spec Kit`, `SpecWeave`, `cc-sdd`) puts its trust in the
agent *reporting* that it verified something; only this kit and `SpecWeave` make verification
an executable step, and `SpecWeave`'s executable step has two holes we reproduced. So the
recommendation is **reject as a replacement, incorporate selectively** — and the single
highest-value incorporation is not a new tool at all, it is the trap we already fixed here
(skip-as-pass), because the most popular competitor still ships it.

---

## 1. What "production quality" would have to mean

Five properties, each independently checkable. A tool that only does #1 is a linter wearing a
badge.

| # | Property | The question it answers |
|---|---|---|
| 1 | **Detection** | Do the tests fail when the code is wrong? |
| 2 | **Behavioural coverage** | Are the *inputs* covered, or only the statements? |
| 3 | **Security floor** | Are secrets, injections and known-vulnerable dependencies blocked? |
| 4 | **Repeatability** | Does it pass the same way 5 times in a row? |
| 5 | **Enforcement** | Does a failure *stop* the work, with nobody's cooperation required? |

Property 5 is the one that separates the frameworks from each other, and it is the axis the
market is weakest on.

---

## 2. Verdict table

| Option | Verdict | Why (evidence) |
|---|---|---|
| **gitleaks** | **Adopt** | [measured] 0.45 s, exit 1 on leak, SARIF out, 1 true finding on the fixture. Free, offline, no account. |
| **Semgrep CE (pinned configs)** | **Adopt, pinned** | [measured] 3.65 s, 3 findings on `p/default`, exit 1 with `--error`. **Must** pin the ruleset — `--config auto` refuses to run with `--metrics=off`. |
| **osv-scanner** | **Adopt (CI only)** | [measured] 10.5 s, 60 findings across 4 pinned packages. Needs network, so not a local pre-commit gate. |
| **mutmut 3.x** | **Adopt, opt-in** | [measured] 100%-covered file, **11 of 18 mutants survived**. This is the only thing in the survey that measures property #1 rather than assuming it. Slow → opt-in per change, not every commit. |
| **hypothesis** | **Adopt, narrow** | [measured] example tests passed; property test found `total_cents=1, people=2 → sum([0,0]) == 0 ≠ 1` and shrank it automatically. |
| **diff_cover** | **Incorporate idea** | Gate only the *changed* lines. Turns slow checks into affordable per-change checks. Not run here. [read] |
| **trufflehog** | **Consider, later** | [read] Verifies credentials against providers, which is strictly better than pattern matching — but only for vendor token formats, which is not where our measured gap was. |
| **Spec Kit** (`github/spec-kit`, 142k★, MIT) | **Already the base** | Workflow scaffolding, no execution gate. Our kit sits on it. |
| **BMAD-METHOD** (54k★) | **Reject** | Persona/role ceremony. Nothing executable to inherit. [read] |
| **OpenSpec** (72k★, MIT) | **Reject as base, steal delta-specs** | Closest alternative structure; adds delta specs and archive. No verification gate. [read, not run] |
| **Agent OS / Task Master / cc-sdd / superpowers** | **Reject as base** | See §4. `cc-sdd` is the only serious one. |
| **SpecWeave 3.1.5** (MIT, 166★) | **Reject as replacement; incorporate 3 ideas** | [measured] Full loop works, but ships two skip-as-pass-class holes (§5). Footprint collides with this kit's `AGENTS.md` — cannot run both. |
| **promptfoo / Inspect / DeepEval** | **Reject** | Build a 30-line harness instead [measured, §6.4]. These solve prompt-regression, not code correctness. |
| **Kiro (IDE), Tessl** | **Reject** | Proprietary, IDE-coupled. [read] |

---

## 3. The finding that reorders everything: enforcement layer

Three frameworks, same intent, three different trust models.

| | `Spec Kit` + this kit | `SpecWeave` | `cc-sdd` |
|---|---|---|---|
| Spec format | `spec.md` / `plan.md` / `tasks.md` | `spec.md` + `tasks.md` + AC ids | `requirements.md` / `design.md` / `tasks.md` |
| "Is the task done?" decided by | **an executable command** | an executable command **or a string** | **the agent, following a skill** |
| Can an agent mark work done with no command run? | No — the ledger needs evidence, and completion is a command | **Yes** [measured: `--evidence "reviewed it myself"` → rc=0] | Yes, if it ignores the skill [read] |
| Passes when there is nothing to check? | **No** (defect fixed in 1.14.0) | **Yes** [measured: 0 ACs → `ACs 0/0` → PASS] | Unverified |
| Fresh-output requirement written down | Yes | No | Yes, and unusually well written |

**Read the middle column of that table as the thesis of this document.** `cc-sdd` is the most
thoughtful design in the survey and it *knows* the right rule — its `kiro-verify-completion`
skill says to demand fresh command output and exit codes, to reject claims broader than the
evidence, and explicitly not to trust another subagent's success report. That is the correct
doctrine, written as prose. Prose is a request. A command is a guarantee. A skill can be
ignored by a model under context pressure; `exit 1` cannot.

That gives this kit a defensible position that is not "we have more commands": **we are the
only one where the doctrine is executable.** The risk is that this advantage is easy to lose
— the moment a check can silently skip, the guarantee is gone. Which is why §5 matters.

---

## 4. What the evidence says about autonomy

- **No repo in the studies commits actual spec-tool output**, and no defect reduction is
  attributable to spec-driven development as a method (88,052 PRs, 119 repos, 25,209 artefacts
  scored; Hill, ESEM 2026, `doi:10.4230/lipics.esem.2026.84`).
- **Agent choice explains under 3% of outcome variance**; the agent×task interaction explains
  7–23% (Srinivasan 2026, `arXiv:2608.11323`). Translation: switching framework is not the
  lever. Task granularity is.
- **Most AI-written PRs get no review at all**, and where review happens it is increasingly
  agent review (Duma 2026, `arXiv:2605.02273`; Agarwal 2026, `arXiv:2607.07980`). So "a human
  will catch it" is not a control you can count on.
- **Vibe-coded applications have measurably worse security properties** than the same apps
  built with review (Deng, Fan & Meng 2026, `arXiv:2606.23130`). This is the argument for
  property #3 being non-optional rather than nice-to-have.
- **A benchmark's 5th-percentile score agrees with its full score on only 19.5% of tasks**
  (DeltaSelect, `arXiv:2609.19607`). Cherry-picked "it works" demonstrations are close to
  uninformative.

Net: the field supports *gates*, not *hope*. Nothing supports "point it at the repo and go
away".

---

## 5. The competitor's two holes (reproduced today)

Both are the same failure class this kit fixed in 1.14.0: **a check with nothing to check
returns success.**

**Hole 1 — evidence is a string, not a command.**

```
$ specweave task done T-01 --evidence "reviewed it myself, looks fine"
rc=0    # accepted. No command ran.
```

**Hole 2 — an empty acceptance set passes.**

A spec with no `## Acceptance Criteria` section, and a task citing a non-existent `AC-99`,
yields:

```
verify →  ACs 0/0 · tasks 0/1  →  PASS
```

Zero criteria checked, and the verdict is green. This is exactly the defect that let this
kit's own gate report success over an empty scan, and it is the defect most likely to
regress anywhere, because it is invisible: the output looks like a pass and read literally
*is* one.

**What SpecWeave does better than us, and we should take:**

1. **Append-only `ledger.jsonl`** with git `merge=union` — two agents on two branches never
   conflict over task state. Our markdown ledger conflicts.
2. **Claims/leases with file-overlap detection** (exit 3/4/6) — prevents two workers editing
   the same file.
3. **AC counting at verify** — per-criterion tally rather than a single verdict.

Adopting (1) and (3) is cheap and closes real holes. (2) only matters once parallel dispatch
works, which it currently does not here.

---

## 6. Measured results (fixture, this machine)

Fixture: three-module Python service (`pricing`, `billing`, `db`) with deliberately planted
defects, plus example tests and one property test.

### 6.1 Coverage is not detection
`app/pricing.py` at **100% line coverage**, 31 mutants generated in seconds, **11 of 18
considered mutants survived**. A green bar over broken logic.

### 6.2 Security scanning works, within its shape
| Tool | Time | Findings | Gate behaviour |
|---|---|---|---|
| gitleaks 8.30.1 | 0.45 s | 1 (`github-pat`, `app/db.py:9`) | exit 1 on leak; `--exit-code 0` overrides |
| semgrep 1.182.1 `p/default` | 3.65 s | 3 (shell=True, formatted SQL, raw-execute) | exit 1 with `--error` |
| osv-scanner 2.7.0 | 10.5 s | 60 across 4 pinned packages | exit 1; needs network |

Operational trap found: `semgrep --config auto` **refuses** to run with `--metrics=off`
("Cannot create auto config when metrics are off"). Rule packs must be pinned, which is
better practice anyway — `auto` resolves to whatever the registry serves that day, and a gate
that changes its own rules silently is not a gate.

### 6.3 Secrets: the uncomfortable result
`DB_PASSWORD = "hunter2-prod-do-not-ship"` — a real leak pattern — was **missed by both**
gitleaks and semgrep's default ruleset. gitleaks caught only the GitHub-token-shaped string.

So I wrote a 20-line custom rule. It **caught both** the password and the token, exit 1,
offline, ~5 s. Then I tested what it actually covers:

| Realistic variant | custom rule | `p/secrets` (37 rules) | gitleaks |
|---|---|---|---|
| Module-level `ALL_CAPS = "..."` | **caught** | caught | caught |
| `os.getenv("DB_PASSWORD", "fallback")` | missed | missed | missed |
| `{"password": "..."}` dict literal | missed | missed | missed |
| `class S: db_password = "..."` | missed | missed | missed |
| `def f(password: str = "...")` | missed | missed | missed |
| `postgres://user:pw@host/db` DSN | missed | missed | missed |
| lowercase `local_pw = "..."` | missed | missed | missed |

**0 of 6 realistic variants caught by any of the three tools**, including Semgrep's curated
37-rule secrets pack.

Conclusion, and it is not the one I expected to write: **secret scanning detects vendor token
formats, not developer-invented credentials.** The tools are worth adopting for what they do
cover, but they are not a security floor. The floor has to be a human rule enforced by review
("secrets come from the environment, never from a literal") plus a scanner for the token
shapes. Do not let a green secret scan stand in for that rule.

### 6.4 Repeatability: the number that justifies gates over retries
A 30-line harness over 40 tasks, true per-trial success p = 0.90, k = 5 trials:

```
pass@1 = 0.92      (any one trial succeeds)
pass^5 = 0.65      (all five trials succeed)
```

8 of 40 tasks failed only in trial 3 or later. A workflow that "worked when I ran it" at 92%
is a workflow that fails a third of the time across five runs. Wilson intervals are included
in the harness because at 40 samples the point estimate alone overstates precision.

Implication for this kit: **any check that depends on the agent behaving is a coin-flip
compounded five times.** Only executable checks escape this.

### 6.5 Property testing catches what examples miss
`split_bill` passed its two example tests. The property test (`sum(shares) == total`, no share
negative) failed and shrank to `total_cents=1, people=2 → [0, 0]`, i.e. a penny vanished. One
test, no maintenance, found a real bug.

### 6.6 The kit's own gate
`./scripts/self-gate.sh --no-e2e` → **213 ok, 0 bad, 0 skip, PASS**, exit 0, no orphans.
Wall time ≈ 3.5 min (section 1j scenario evals dominate). Note for future runs: it legitimately
exceeds a 5-minute budget on a warm machine; timeouts must be set above 6 minutes or it looks
like a hang.

---

## 7. Incorporation plan, ranked

> **PARTLY SUPERSEDED — read §10 before implementing.** A second validation pass against
> literature and upstream docs confirmed five items and **corrected two** (item 3's mechanism,
> item 5's gate design) plus **narrowed one** (item 6). The text below is the original plan,
> kept so the change is visible; §10 is authoritative.

Each item states its **acceptance test** — the executable proof it worked. Ranked by
(value ÷ effort).

**1. Empty-check invariant (highest value, lowest effort).**
Any gate that reports PASS must have checked ≥1 thing. Assert `checked > 0` at every verdict
site; a zero is a FAIL with the reason "nothing was checked".
*Acceptance:* a fixture whose AC list is empty → non-zero exit and the words "nothing was
checked".

**2. AC tally in the resume report.**
Report `ACs n/m` and refuse completion when `m == 0`. Steals SpecWeave's good half.
*Acceptance:* `speckit-resume` on a spec with no ACs exits non-zero.

**3. Append-only ledger (`ledger.jsonl`, `merge=union`).**
Replaces conflicting markdown state; makes parallel work safe later.
*Acceptance:* two branches appending to the ledger merge without conflict; `git merge` clean.

**4. Changed-lines gating (`diff_cover` pattern).**
Run expensive checks (mutmut, osv) only on touched files. Makes item 5 affordable.
*Acceptance:* an unrelated-file change triggers no mutation run; a touched file does.

**5. Mutation check as an opt-in gate.**
`--mutation` flag; fail when survival rate on changed files exceeds a threshold.
*Acceptance:* the fixture's `pricing.py` (11/18 survivors) fails the gate; a strong test file
passes it. Calibrate threshold from Papadakis 2018 (correlation is real but confounded by
suite size — pair it with coverage, never instead of it).

**6. Pinned security job in CI.**
gitleaks + semgrep with a *committed* rule file + osv-scanner nightly.
*Acceptance:* a planted `ghp_` token fails the job; removing it passes; `--metrics=off` runs
without the auto-config error.

**7. Property-test prompt in the plan template.**
Ask for one invariant per module, not "add tests".
*Acceptance:* a generated plan names a property and its generator.

**8. `pass^k` script in `evals/`.**
Standalone; answers "is this workflow reliable" rather than "did it work once".
*Acceptance:* reproduces 0.92 vs 0.65 at the stated parameters.

**Explicitly not adopted:** model-judge scoring as a gate (judge verdicts flip 13.6% on
reordering, `arXiv:2606.13685` — useful for triage, unfit for a pass/fail); persona ceremony;
a second framework's file layout (the `AGENTS.md` collision makes coexistence impossible);
proprietary/IDE-coupled tooling.

---

## 8. Limitations — what this document is not

- **Single fixture, single machine, macOS/arm64, one Python version.** Scanner timings are
  not portable benchmarks.
- **Not run here:** OpenSpec, Trivy, promptfoo, Kiro, cc-sdd, trufflehog, diff_cover. Their
  verdicts rest on docs and reputation, not execution, and are marked **[read]**.
- **Sample sizes are small by design.** The `pass^k` result uses a synthetic p=0.90; it
  demonstrates the arithmetic, not a measured property of this kit.
- **Literature is recent and partly unreviewed.** Several 2026 arXiv items are preprints. They
  are cited to show the direction of evidence, not as settled fact.
- **Saturation was asserted, not proven.** Three search rounds each surfaced new material; the
  fourth (framework sweep) returned only 0-star personal repositories, which is weak evidence
  of exhaustion rather than proof. A future round could still surprise.
- **The security conclusion is the least certain and most consequential item here.** It rests
  on one fixture and seven synthetic variants; a broader corpus could raise the recall of
  `p/secrets` above zero.

---

## 9. Citations

**Spec-driven development & agents**
- Hill, ESEM 2026 — `doi:10.4230/lipics.esem.2026.84`
- Diaz et al. 2026 — `arXiv:2609.00252` (SDD productivity paradox)
- Consort 2026 — `arXiv:2609.09671` (comparative study incl. Spec Kit, superpowers, BMAD)
- Srinivasan 2026 — `arXiv:2608.11323` (variance decomposition)
- Rabanser 2026 — `arXiv:2602.16666` (reliability profiles); `arXiv:2610.01618`; `arXiv:2609.13582`; `arXiv:2605.10516`
- DeltaSelect 2026 — `arXiv:2609.19607` (subset vs full benchmark agreement)
- Huang et al. 2023 — `arXiv:2310.01798` (agents cannot reliably self-correct)

**Review & oversight**
- Duma 2026 — `arXiv:2605.02273`; Agarwal 2026 — `arXiv:2607.07980`
- Zhong 2026 — `arXiv:2603.15911`; Monperrus 2026 — `arXiv:2606.13175` (opposing view)
- Ye 2026 — `arXiv:2606.05647` (human detection of agent sabotage)

**Testing & mutation**
- Papadakis et al. 2018 — `doi:10.1145/3180155.3180183`; survey `doi:10.1016/bs.adcom.2018.03.015`
- Chen 2020 ASE; Titcheu Chekam 2019 (FaRM); Cerebro, TSE 2022 (mutant selection)
- Moradi Dakhel 2024 — `doi:10.1016/j.infsof.2024.107468` (mutation-guided LLM tests)
- Kiele et al., ESEM 2026 — `doi:10.4230/lipics.esem.2026.49` (LLM mutant generation)
- Ouédraogo 2026 — `doi:10.1145/3838597` (test smells in LLM tests); Panichella 2020 — `doi:10.1109/icsme46990.2020.00056`
- Ravi & Coblenz 2025 — `doi:10.1145/3764068` (Hypothesis corpus study); Chin & Pearce 2021 — `doi:10.22152/programming-journal.org/2021/5/13`
- Liu et al. 2023 — `arXiv:2305.01210` (EvalPlus)

**Security**
- Deng, Fan & Meng 2026 — `arXiv:2606.23130` (vibe-coded app insecurity)
- Marri 2026 — `arXiv:2602.02584` (security by construction in the spec layer)
- SecureVibeBench, ACL 2026

**Benchmarks & reliability**
- Liu et al., MSR 2026 — `doi:10.1145/3793302.3793587`
- FDE-Bench — `arXiv:2609.27571`; Incident-Arena — `arXiv:2610.00648`; DevAgentBench — `doi:10.5281/zenodo.18961157`
- RELY-SE — `doi:10.1145/3832783.3834654`
- Agentless — `arXiv:2407.01489`; `arXiv:2604.18334` (CI reliability)

**Repository facts** verified via GitHub API, 2026-10-22 (stars / last push / licence):
`github/spec-kit` 142,329★ MIT · `Fission-AI/OpenSpec` 72,672★ MIT · `obra/superpowers` 303,205★ MIT ·
`bmad-code-org/BMAD-METHOD` 54,422★ · `gotalab/cc-sdd` 3,731★ MIT · `anton-abyzov/specweave` 166★ MIT ·
`gitleaks/gitleaks` 30,200★ MIT · `semgrep/semgrep` 17,174★ LGPL-2.1 · `opengrep/opengrep` 3,213★ ·
`google/osv-scanner` 11,227★ Apache-2.0 · `boxed/mutmut` 1,498★ BSD-3 · `hypothesisWorks/hypothesis` 9,101★ ·
`trufflesecurity/trufflehog` 28,631★ · `Bachmann1234/diff_cover` 849★

---

## 10. Second-pass validation (same day)

Purpose: check the plan's items against upstream best practice rather than plausibility.
Method: five literature searches, three web searches, two local experiments.

### Outcome

| Item | Verdict | What changed |
|---|---|---|
| 1. Empty-check invariant | **Confirmed, broadened** | Two distinct vacuity types, not one. Plus a concrete implementation detail (`pytest` exit 5). |
| 2. AC tally | **Confirmed** | No change. |
| 3. Append-only ledger | **Revised — mechanism** | `merge=union` is necessary but not sufficient; needs immutable lines + unique ids + duplicate check. |
| 4. Changed-lines gating | **Confirmed, safety caveat** | File-level selection is defensible, but it can miss tests → keep periodic full runs. |
| 5. Mutation gate | **Revised — gate design** | A percentage threshold is *not* what industry does. Report surviving mutants as goals instead. |
| 6. Security CI | **Narrowed** | Staged rollout; and my hand-rolled regex rule was the weak version of the state of the art. |
| 7. Property prompt | **Refined — and it validates the kit's premise** | The prompt must carry the spec rules, not just "write a property". |

### The two corrections

**Item 3, reproduced in three lines.** I proposed `git merge=union` for the ledger because
`SpecWeave` uses it. Both cases tested locally:

```
# append-only: correct
{"id":"2","ev":"done","at":"10:01"}
{"id":"1","ev":"done","at":"10:00"}      <- note: order REVERSED, 0 conflicts

# line edited in place: silent corruption
{"id":"1","ev":"pending"}
{"id":"2","ev":"pending"}
{"id":"1","ev":"answered"}               <- TWO records for id 1, no conflict, no error
```

Git's own documentation warns that union "tends to leave the added lines in the resulting
file in random order and the user should verify the result". So the mechanism is safe only
if every line is an immutable, uniquely-identified event and status changes are *new events*,
never edits. Requirements that follow: readers sort by timestamp (never trust file order);
a CI check rejects duplicate ids; a test proves the file is still append-only (ratio of
deletions to additions). A project in the wild hit exactly this and upgraded to a custom merge
driver that deduplicates by id (`spec-kitty` issue #569) — that is the escape hatch if union
proves insufficient.

**Item 5, wrong design.** I proposed failing the gate when the mutation survival rate exceeds
a threshold. Kaufman et al. (ICSE 2022) report that **no known industrial application of
mutation testing even computes mutation adequacy**; they instead present a small number of
surviving mutants as concrete test goals for a developer to kill. The threshold gate is the
research view, not the practice view. Revised: report surviving mutants as goals; use *extreme*
mutation (mutating whole methods — much faster, less precise, per Betka & Wagner 2022) on
changed files; keep any percentage as a soft budget, never a pass/fail. One more refinement:
a raw survival rate conflates a real assertion failure with an incidental crash, which
SecMutBench (2026) separates into semantic / functional / incidental / crash kills.

### The narrowing and the refinement

**Item 6.** The security-hardening guide's recommended sequence is a ladder, not a switch:
(1) scheduled broad full scan on the main branch, (2) diff-aware scan on pull requests with a
fine-tuned high-confidence ruleset, (3) only then enable blocking. That is the same 1→2 shape
as our items 4→6, which is reassuring. Two operational facts worth encoding: `semgrep scan`
does **not** fail on findings by default (only `semgrep ci` does, and `--error` is what makes
`scan` gate), and `semgrep ci` deliberately **passes the build on internal errors** unless
`--no-suppress-errors` is set — a vacuous pass built into the tool we are adopting to prevent
vacuous passes.

And the uncomfortable part again: secret detection is not a solved problem we can bolt on.
AssetHarvester (ICSE 2025) cites a **25%–99% false-positive rate** across secret-detection
tools and reports that developers ignore the warnings because of it; Soltaniani & Ghafari
(EMSE 2026) state plainly that rule-based detectors yield a high false-positive rate and that
the state of the art is ML classification (CodeBERT best in their study). My 20-line regex
rule is therefore the weakest available answer to the problem, and should not be presented as
the fix.

**Item 7, and why it matters most.** Haeri & Ghelichi (2026) isolate *why* "write your own
tests and repair until they pass" helps: holding the tester, test budget and repair loop
fixed, they changed a single prompt line controlling whether the tester receives the spec as
a checklist of rules. The gain comes from **specification grounding**, not from the tests
merely existing. That is, independently, the empirical case for this kit's premise. The
practical consequence: item 7 must thread the spec's rules into the property prompt; a bare
"write a property test" reproduces the weaker condition.

### One correction to §6.4

At a constant p = 0.90, independent trials give `0.90^5 = 0.59`, not 0.65. The harness's 0.65
comes from modelling **per-task** difficulty (each task has its own p, averaging 0.90), and by
convexity `E[p^5] ≥ (E[p])^5`. Both numbers are right; the §6.4 wording was ambiguous. The
constant-p figure (0.59) is the pessimistic bound and the simpler one to quote.

### New citations from this pass

- Kaufman et al., ICSE 2022 — `doi:10.1145/3510003.3510187` (industrial practice: few mutants as goals)
- Betka & Wagner 2022 — `doi:10.1002/smr.2450` (extreme mutation: speed vs precision)
- Sánchez et al., EMSE 2022 — `doi:10.1007/s10664-022-10177-8` (mutation testing in the wild)
- Ramler et al., SAC 2017 — `doi:10.1145/3019612.3019830` (safety-critical industrial case)
- SecMutBench, AIware 2026 — `doi:10.1145/3805760.3814933` (classifying kill quality)
- Zhang 2018, ICSE — `doi:10.1145/3180155.3180198` (file-level RTS competitive)
- Shi et al. 2019 — `doi:10.1145/3360613` (static RTS can be unsafe)
- Wang et al., ASE 2024 — `doi:10.1145/3691620.3695551` (incremental coverage analysis)
- Soltaniani & Ghafari, EMSE 2026 — `doi:10.1007/s10664-026-10929-w` (rule-based secrets → high FP; ML wins)
- Opdebeeck et al., SCAM 2025 — `doi:10.1109/scam67354.2025.00014` (name-pattern matching: FP *and* FN)
- Basak et al., ICSE 2025 — `doi:10.1109/icse55347.2025.00067` (25–99% FP; 12M secrets leaked 2023)
- Hill 2026 — `arXiv:2608.26183` (vacuous pass, found four times over)
- Canedo 2026 — `arXiv:2608.17214` (oracle anchoring: a test that compares code to itself)
- Haeri & Ghelichi 2026 — `arXiv:2607.06636` (specification grounding drives test effectiveness)
- Tanaka et al., AIware 2025 — `doi:10.1109/aiware69974.2025.00009` (LLM PBT vs example-based on edge cases)
- Etemadi et al. 2025 — `doi:10.1007/978-3-032-07132-3_3` (LLM-extracted properties → PBT)
- Molina et al., TOSEM 2025 — `doi:10.1145/3715107` (test oracle automation roadmap)
- `spec-kitty` issue #569, opened 2026-04-09 (web, project issue) — dedupe-by-id merge driver
- `appsec.guide` Semgrep CI ladder (web, handbook); `docs.semgrep.dev` blocking/errors semantics (web, official)

---

## 11. Rounds 3–5 and convergence declaration

**Convergence criterion (fixed in advance):** validation stops when a full round produces **no new plan
item and no mechanism change**. Two consecutive rounds meeting that bar, with the penultimate round's
corrections already absorbed, count as converged.

| Round | Targeted | Outcome |
| --- | --- | --- |
| 3 | equivalent mutants; traceability; AC tally | **Traceability rejected** (no empirical support for improved fault detection). AC tally re-justified on *mechanism* grounds only (prevents `0/0` pass), not BDD methodology. TCE named as the standard equivalent-mutant filter. |
| 4 | is TCE usable in Python; how noisy are rule-based survivors | **Item 5 revised again.** Local experiment: TCE catches identical control and docstring changes, but **misses** `x*2` vs `x+x` and `x/2` vs `x>>1` — bytecode differs, behaviour does not. So TCE is a *partial* filter in Python and must not be ported as a complete one. Kiele et al. ESEM 2026 (`doi:10.4230/lipics.esem.2026.49`): rule-based survivors carry only a **4.4%/5.7%** verified-fault rate → ~95% of survivors are candidates, not findings. |
| 5 | changed-lines safety; PBT adoption | **No item or mechanism change — confirmed only.** Facebook PTS (`arXiv:1810.05286`) is the industrial proof: halves CI infrastructure while still surfacing **>99.9%** of faulty changes. Google's ICSE-SEIP 2019 experience report (`doi:10.1109/icse-seip.2019.00009`) is the caveat: history-based selection underperforms at scale, and **84% of test-result transitions at Google are caused by flaky tests, with 16% of tests flaky** → added as US4/FR-018 (classify a single re-run as flake, keep both outcomes). Goldstein et al. ICSE 2024 (`doi:10.1145/3597503.3639581`) confirms PBT practice at Amazon, Volvo, Stripe. |

**Also measured in round 5 — applied to ourselves:** `scripts/self-gate.sh:1477-1490` already implements
the three-state verdict correctly (`INCOMPLETE`, never `PASS`, when sections are skipped; `--strict`
makes it nonzero). This is cited in the spec as the **precedent to copy**, not a defect to repair.

**CONVERGED — 2026-10-22.** Round 5 changed no plan item and no mechanism. The plan's item set is stable
at 8; the design of items 3 and 5 has been rewritten twice, item 6 narrowed once, item 1 broadened once,
item 2 re-justified, item 7 refined, item 4 confirmed with a flakiness limitation added, and one
candidate item (traceability) was rejected outright. Spec written at `specs/005-verification-integrity/spec.md`.

### Residual uncertainty (deliberately not resolved)

- No local measurement of `scripts/verify` against FR-001/FR-002 yet — the spec records this as an
  assumption and makes measuring it the first implementation task.
- `pass^k` figures: 0.59 is the constant-difficulty bound, 0.65 the empirical per-task-difficulty result
  (convexity makes `E[p^k] ≥ (E[p])^k`). Both are correct for different assumptions; FR-032 requires
  showing both so neither is read as the whole truth.
- Secret-scanning coverage of hand-written passwords remains **0 of 6** for scanner defaults. This is a
  known, recorded limitation — not something the ladder is expected to fix.

### New citations from rounds 3–5

- Madeyski et al., TSE 2013 — `doi:10.1109/tse.2013.44` (equivalent mutants)
- Papadakis et al., ICSE 2015 — `doi:10.1109/icse.2015.103` (Trivial Compiler Equivalence)
- Kiele et al., ESEM 2026 — `doi:10.4230/lipics.esem.2026.49` (verified-fault rate of survivors)
- Facebook PTS — `arXiv:1810.05286` (industrial predictive test selection)
- Leong et al., ICSE-SEIP 2019 — `doi:10.1109/icse-seip.2019.00009` (Google: 84% transitions flaky, 16% tests flaky)
- Goldstein et al., ICSE 2024 — `doi:10.1145/3597503.3639581` (PBT in practice: Amazon, Volvo, Stripe)
- RESTestBench 2026 — `arXiv:2604.25862` (precise vs vague requirements and generated-test effectiveness)
- Farooq et al., IEEE Access 2023 (BDD systematic review — mixed evidence, used to justify *not* claiming BDD benefits)
