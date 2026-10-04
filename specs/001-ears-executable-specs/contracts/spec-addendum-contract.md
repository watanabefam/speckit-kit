# Contract: spec-addendum (EARS guidance)

Target: `preset/templates/spec-addendum.md` (appended after core spec-template).

## MUST contain

1. Five-pattern EARS table with columns `Pattern | Keyword | Shape | Use-when | Example`:
   - Ubiquitous: `The <system> SHALL <response>.`
   - Event-driven: `WHEN <trigger>, the <system> SHALL <response>.`
   - State-driven: `WHILE <state>, the <system> SHALL <response>.`
   - Unwanted-behaviour: `IF <unwanted condition>, THEN the <system> SHALL <mitigation>.`
   - Optional-feature: `WHERE <optional feature>, the <system> SHALL <response>.`
   - Each row: syntax shape + at least one example (FR-001..FR-005).
2. SHALL-only boilerplate (RFC 2119/BCP 14 line); no lowercase normative verbs in requirements.
3. Order/complex footnote: `Where → While → When → If/Then → SHALL`; one complex (`WHILE+WHEN`) example; `>3 preconditions or math → table/list` escape hatch.
4. Misuse pointer: WHEN=point event / WHILE=durable state / IF=faults-second-pass / WHERE=variant-not-location; Tier-1 vs Tier-2 review split delegated to the checklist.

## MUST NOT contain

- Any concrete PBT framework as a default or recommendation (FR-008). The words `Hypothesis`, `fast-check`, etc. may appear ONLY in a "do NOT hardcode (e.g., Hypothesis)" negative-example sentence.
- Skill dependency: text must be usable with no skill loaded (FR-010).

## Gate probe

```bash
grep -q "Ubiquitous\|ubiquitous" preset/templates/spec-addendum.md
grep -q "WHEN <trigger>" preset/templates/spec-addendum.md
grep -q "WHILE <state>" preset/templates/spec-addendum.md
grep -q "IF <unwanted" preset/templates/spec-addendum.md
grep -q "WHERE <optional" preset/templates/spec-addendum.md
```
