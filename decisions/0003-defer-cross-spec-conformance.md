# 0003 — Defer cross-spec template conformance to one amendment

## Context

`spec 005` closed with a known artifact gap: its `spec.md` fails the kit's own section-integrity
check. Measuring the blast radius changed the decision, so the measurement is recorded here rather
than a one-spec rewrite being done as cleanup.

```
$ for f in specs/*/spec.md; do bash .specify/scripts/check-section-integrity.sh . spec-template "$f"; done

001-ears-executable-specs     19 missing, 0 out of order   (of 27 required)
002-review-and-stress-gate    10 missing, 0 out of order
003-autonomous-throughput      1 missing, 0 out of order
004-reliability-hardening     18 missing, 1 out of order
005-verification-integrity    17 missing, 1 out of order
006-workflow-orchestration    17 missing, 1 out of order
```

Every spec fails, and the gap is not uniform: `003` needs one heading (`### Which document wins`),
`005` needs seventeen. `tasks.md` (28/28) and `plan.md` (44/44) pass for 005, so this is spec-template
drift, not a broken artifact.

Nothing is blocked by it. `scripts/self-gate.sh` checks that the checker exists and is wired where
`/speckit.plan` looks for it — not that any spec conforms — so the failure is invisible to the gate
and to `./scripts/verify`.

## Decision

Do not restructure `005`'s spec as part of `005`. The reasons are ordered by weight:

1. **It is one of six, and the shapes differ.** Filling seventeen sections of `005` moves the repo
   from six failing specs to five, and leaves the kit with specs migrated from two different template
   revisions — the condition the template exists to prevent.
2. **Partial conformance is worthless mechanically.** The checker fails on any missing section, so
   adding only the sections that carry meaning (Normative Status, Which document wins) changes
   nothing it reports. Semantics improve; the check does not.
3. **It would rewrite an approved artifact mid-implementation.** `005`'s content was reviewed and its
   plan approved; a template migration is a content edit that needs its own review, not a footnote in
   a feature's final commit.

The amendment, when opened, should:

- fix the template mapping once, for all six, and state the rule for sections that do not apply to a
  given spec (an explicit "not applicable, because…" rather than a deleted heading);
- start from `003` (one section) as the proof that the rule works before applying it to `001` (19);
- decide whether `scripts/self-gate.sh` should run the spec check at all. Today a spec can be
  non-conformant indefinitely and every automated check still passes; that is a deliberate absence
  today, and it should be made deliberate in writing rather than by omission.

## Consequences

- The gap is recorded, reproducible, and still open. `005`'s `progress.md` names it under
  "Conformance gap found, not fixed", so a reader of the evidence trail is not misled.
- Any future spec written from the current template will pass; the six legacy ones will keep failing
  the check until the amendment runs.
- If a seventh spec is written before then, it inherits the demand to conform, and the amendment's
  scope grows by one. That is an argument for doing it soon, not for doing it here.
