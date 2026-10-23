# 0004 — Presence is required, content may be non-applicable, empty is a failure

## Context

`decisions/0003` deferred spec-template conformance across `specs/001`–`006` to one amendment, because
all six failed the section check by differing amounts (1 to 19 sections of 27). This record decides the
rule that amendment applies, then records that it applied it.

The question the deferral left open was what a spec should do about a required section that genuinely
does not apply. Four research rounds against primary sources settled it, and three of them corrected
what I had assumed:

1. **No universal convention exists, and the one that does is specific.** Python PEP 12 calls its
   outline "Suggested Sections" and never says to write N/A; Rust RFCs and Kubernetes KEPs mark some
   sections "(Optional)" and say nothing general; MADR says "optional element. Feel free to remove."
   The only normative *presence* rule found is IETF's: "All Internet-Drafts MUST contain an IANA
   Considerations section", and when there are no actions it must say "This document has no IANA
   actions." ([IETF author guidance](https://authors.ietf.org/en/iana-considerations); the RFC Editor
   then removes the no-actions section from the *published* RFC, [RFC 7322 §4.8.3](https://datatracker.ietf.org/doc/rfc7322/).)
   So: presence during authoring, an explicit statement of non-applicability in the body. That is the
   pattern adopted here — cited as a precedent for the shape, not as a rule that covers this case.
2. **markdownlint cannot express "this named heading is optional".** My first instinct was to borrow
   MD043's `?`; that is wrong. `?` means "exactly one unspecified heading"
   ([MD043](https://github.com/DavidAnson/markdownlint/blob/main/doc/md043.md)). The mechanism that
   does exist is the one the kit already uses: mark the heading OPTIONAL in the template and let the
   checker skip it.
3. **`Not applicable — reason` has no linter precedent, and bare `N/A` counts as content.** rumdl's
   MD082 counts anything that renders, so `None`, `N/A` and `—` all satisfy it, and no reviewed
   guidance requires a justification after a non-applicability claim
   ([MD082](https://github.com/rvben/rumdl/blob/main/docs/md082.md)). A checker that rejects the
   terse form would spend its credibility on false positives.
4. **Enforcement order matters more than enforcement.** GitLab's documented practice is to fix
   existing violations *before* making a rule blocking, or to add it as a warning and promote it later,
   because warnings do not fail CI and are ignored
   ([GitLab Vale guidance](https://docs.gitlab.com/development/documentation/testing/vale/)).
   Crossplane enforces only new/changed content during a migration
   ([Crossplane](https://docs.crossplane.io/contribute/vale/)) — a ratchet, which has the known failure
   mode that untouched documents stay non-conformant forever.

## Decision

**1. Presence is required; content may state non-applicability with a reason.** A required heading is
never deleted. A section that does not apply keeps its heading and says `Not applicable — <reason>`.
The reason is required by the template and by review, not by the checker: the machine cannot tell a
truthful reason from a false one, and pretending otherwise is the kind of claim this kit exists to
refuse.

**2. A section that never applies is a template defect.** If no spec of a kind could fill a section,
it is marked OPTIONAL in the template (which the checker honours) rather than left for every author to
write "not applicable".

**3. An empty section is a failure.** The new check: a required heading with nothing rendered under it
is reported as `STUB` and fails. Blank lines, HTML comments and thematic breaks are not content; a
fenced code block is (that distinction was a false positive during this check's own repair, and the
gate now pins both directions). A heading whose content is its subsections is *not* a stub — rumdl
flags those by default and offers `allow-parent-headings`, and the templates here use container headings
(`## Requirements` → `### Functional Requirements`), so the allowance is always on. A bare `N/A` is
accepted, per finding 3.

**4. Order is waived for the sections the kit relocates.** `## Problem / Opportunity` is appended last
but belongs above the append point, so it joins the four headings already exempted for the same reason.
Presence is still required.

**5. The gate enforces it, after the migration rather than before.** `scripts/self-gate.sh` now runs the
check over every `specs/*/spec.md` and fails if any does not conform, and fails if it found no specs at
all (a conformance assertion that examined nothing is the defect spec 005 describes). This is GitLab's
order: clean first, then block. Shipping the check with no gate behind it was the original problem —
a structure rule that nothing runs is prose.

## Consequences

- All six specs conform: 27/27 headings each, present, ordered, non-empty. `003` needed one heading;
  `001` needed nineteen.
- Content added during the migration is either derived from the spec's own text or an explicit
  `Not applicable — reason`; no new claims were introduced to fill a section. Where a spec had real
  material that belonged under a missing heading (004's edge cases, 002's parking-lot distinction),
  that material was written from what the spec already said.
- The checker gained fence awareness. An earlier repair had removed two comment lines from the sample
  bash block it had copied into `specs/005-verification-integrity/tasks.md`, because the check read a
  `#` inside a fenced block as a heading. That is the direction this record forbids: the check was
  wrong, and conforming the artifact to it hides the defect. The fence case is now pinned by the gate
  in both directions (a fenced block is content; a `#` inside one is not a heading).
- `decisions/0003`'s deferral is discharged; the amendment it described is this one.
