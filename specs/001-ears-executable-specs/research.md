# Research: EARS Executable Specifications

**Feature**: `001-ears-executable-specs` | **Date**: 2026-10-04

All NEEDS CLARIFICATION resolved — spec checklist passed 2026-10-04 with zero open markers. This file consolidates the Phase 0 findings.

## R1. EARS pattern presentation in the spec template

- **Decision**: Compact 5-row table — `Pattern | Keyword | Shape | Use-when (1 line) | 1 example` — generic `<system>` placeholder, plus a 3-line order/complex footnote (`Where → While → When → If/Then → SHALL`; one complex example; `>3 preconditions or math → table/list referenced from a WHILE requirement`).
- **Rationale**: Matches Mavin's own quick-reference and RequireKit/ADR-020 tables; lowest authoring friction, copy-pasteable into markdown. The "use-when" line prevents WHEN/WHILE/IF confusion at write time. ~30 lines of guidance the author reads while writing.
- **Alternatives considered**: (a) Full prose section per pattern — rejected: bloats every spec, authors skip it. (b) `WHEN…THEN…SHALL` variant seen in Kiro derivatives — rejected: non-canonical, breaks ordering and linter compatibility.
- **Sources**: Mavin et al. EARS paper; alistairmavin.com/ears; Wikipedia/EARS; QRA "When Not to Use EARS"; RequireKit patterns.

Canonical shapes for the template:

| Pattern | Shape | Example |
| --- | --- | --- |
| Ubiquitous | `The <system> SHALL <response>.` | `The order service SHALL reject orders over 100 line items.` |
| Event-driven | `WHEN <trigger-event>, the <system> SHALL <response>.` | `WHEN the user selects "mute", the laptop SHALL suppress all audio output.` |
| State-driven | `WHILE <state>, the <system> SHALL <response>.` | `WHILE there is no card in the ATM, the ATM SHALL display "insert card to begin".` |
| Unwanted-behaviour | `IF <unwanted-condition>, THEN the <system> SHALL <mitigation>.` | `IF an invalid credit card number is entered, THEN the website SHALL display "please re-enter card details".` |
| Optional-feature | `WHERE <feature-present>, the <system> SHALL <response>.` | `WHERE the car has a sunroof, the car SHALL have a sunroof control panel on the driver door.` |

## R2. Normative language (SHALL vs MUST)

- **Decision**: SHALL-only, uppercase, RFC 2119-defined. One boilerplate line: `The keywords SHALL, SHALL NOT, SHOULD, MAY in this spec are interpreted per RFC 2119/BCP 14; EARS requirements use SHALL (SHALL NOT only as last resort — prefer "SHALL be immune / SHALL reject").` Forbid lowercase should/may/must as normative verbs in the requirements section.
- **Rationale**: EARS canon is SHALL; RFC 2119 declares MUST≡SHALL semantically so nothing is lost; single-verb consistency enables trivial checklist/linter detection; RFC 8174 requires uppercase for normative force. ISO directives likewise prefer SHALL.
- **Alternatives considered**: (a) SHALL/MUST interchangeable — rejected: doubles detection surface. (b) MUST-only — rejected: breaks EARS recognisability and tooling keyed on SHALL.

## R3. Misuse detection (template vs checklist split)

- **Decision**: Checklist-gated, linter-compatible, two tiers. Tier-1 blocking (missing/empty SHALL, >1 SHALL, missing actor, missing trigger) fails review; Tier-2 advisory (vague adjective, WHEN/WHILE swap suspicion, WHERE-as-location, implementation detail, over-complexity) requests revision. Template carries guidance; checklist carries binary probes.
- **Rationale**: Structure fixes omission/ambiguity only if reviewed (Mavin empirical result; QVscribe/`speccheck` prove automatability). Blocking only on structural faults avoids reviewer fatigue; vagueness needs judgement.
- **Alternatives considered**: (a) Prose guidance only — rejected: unenforceable, decays. (b) Hard lint-fail on all style incl. vague words — rejected: false positives on domain terms.

Mechanical probes (for the checklist): SHALL + verb phrase present? exactly one SHALL? one named actor before SHALL? WHEN names a point event (≥3-word trigger)? WHILE names a durable state? faults use IF…THEN with second-pass twin? WHERE names a variant not a location? response observable (not stack choice)? ≤2 keywords?

## R4. Language-agnostic PBT framework detection

- **Decision**: Ship a signal table (ecosystem → manifest files → framework names to grep) as plan-addendum prose + a framework-decision record (`detected framework / version / adopt-vs-fallback`). Ban any single framework as kit default; concrete names appear only as negative examples.
- **Rationale**: Satisfies FR-008 + FR-012 + "kit provides the instruction, not a registry". Detection is two greps any agent can do.
- **Alternatives considered**: (a) Hardcoded per-language defaults — rejected (FR-008/SC-003 violation). (b) Machine-readable registry YAML — rejected (maintenance/drift burden).

Signal table:

| Ecosystem | Canonical framework(s) | Detection signal |
| --- | --- | --- |
| Python | Hypothesis (`@given` + strategies) | `pyproject.toml`/`setup.py`/`requirements*.txt` contains `hypothesis` |
| JS/TS | fast-check (`fc.assert(fc.property(...))`) | `package.json` devDeps contains `fast-check` |
| Rust | proptest (first choice); quickcheck crate (legacy alt) | `Cargo.toml` `[dev-dependencies]` contains `proptest`/`quickcheck` |
| Go | gopter vs rapid (modern generics); stdlib `testing/quick` frozen | `go.mod` requires `gopter`/`rapid` |
| Swift | SwiftCheck (`Arbitrary`) | `Package.swift` depends on `SwiftCheck` |
| Java | jqwik (`@Property`+`@ForAll`); alts junit-quickcheck, QuickTheories | `pom.xml`/`build.gradle*` contains `jqwik` |
| Kotlin | jqwik or Kotest property | gradle contains `kotest-property`/`jqwik` |
| C#/.NET | FsCheck or CsCheck | PackageReference to `FsCheck`/`CsCheck` |
| Ruby | PropCheck (modern) or Rantly | `Gemfile`/gemspec contains `prop_check`/`rantly` |
| Elixir | StreamData (`check all`) or PropCheck | `mix.exs` deps contain `:stream_data`/`:propcheck` |

When none exists: plan records adopt-a-framework OR example-based-fallback; tasks follow the recorded decision.

## R5. Correctness-property shape + opt-out

- **Decision**: `## Correctness Properties` table in plan-addendum: `Property ID (P-001…) | Requirement (FR-00x) | for-any statement | Non-mapped reason | notes`. 1:many allowed per requirement. Non-mapped rows leave the statement blank and fill the reason (e.g., "qualitative UX judgement — no decidable oracle; manual review instead"). No P-ID minted for opt-outs. Coverage = mapped XOR opted-out = 100% (SC-002).
- **Rationale**: Reviewable universal-quantifier syntax; mechanical unbuilt/scope-creep detection (FR-011); SC-002 trial (≥8 reqs incl. ≥2 non-mappable) stays auditable.
- **Alternatives considered**: (a) Properties in spec — rejected (spec is behaviour authority; US2/FR-006 place them in plan). (b) Separate properties file — rejected (append-only simplicity, gate burden).
- Good mappings need a decidable postcondition over a generatable domain (round-trip, idempotence, commutativity, ordering + preservation, conservation, determinism, error-safety). Qualitative/UX/existential/taste claims do not map — forcing yields vacuous tests.

## R6. Property-test task rule shape

- **Decision**: Extend tasks-addendum Task Rules + Detail Block: one PBT task per property (P-ID), tracing FR-ID + P-ID, naming the plan-recorded framework; co-located with the behaviour (no trailing phase); follows the adopt/fallback decision; T003-style worked example.
- **Rationale**: Closes FR-007 loop with per-property traceability (SC-003); reuses the convention agents already follow.
- **Alternatives considered**: (a) One mega task per feature — rejected (unreviewable, loses traceability). (b) Auto-generated test code in templates — rejected (language-specific).

## R7. Preset delivery (extend-in-place)

- **Decision**: Extend the existing 4 addenda in place (EARS → spec; properties → plan; task rules → tasks; constitution untouched by default). No new files, entries, or schema changes.
- **Rationale**: Self-gate requires ≥4 targets incl. the four exact names with every file existing; a 5th target risks gate churn and resolve-order surprises; SC-005 needs all layers composing in append order with idempotent re-run. Smallest diff preserving the gate.
- **Alternatives considered**: (a) New `properties-addendum.md` + 5th entry — rejected (above). (b) Fork/replace core — rejected (forbidden by gate + installer model + FR-010).
- Preset constraints reconfirmed: `strategy: "append"` ×4, quoted versions, `speckit_version: ">=1.0.0,<2.0.0"`, bash-3.2-safe gate, marker-once idempotency, skill-unloaded operation, `lean` bypass documented-not-fixed.
