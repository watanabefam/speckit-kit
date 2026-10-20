# 0001 — Ratify the constitution

## Context

The project shipped with `.specify/memory/constitution.md` still holding the unmodified scaffold:
every principle a bracketed placeholder (`[PROJECT_NAME]`, `[PRINCIPLE_1_NAME]`, …), the version
line still `[CONSTITUTION_VERSION]`. `speckit-check` reported that the resolved template required
nine sections the file did not carry.

Two forces were in tension. The kit's whole argument is that written artifacts govern the work, yet
its own governing artifact was empty — the adopter was asked to do something the kit had not done
for itself. Against that, a constitution invented wholesale is worse than an empty one: it would
encode aspiration rather than the practices the repository actually enforces, and a principle nobody
can test is noise that makes the rest less credible.

A further constraint shaped the content. The kit repeatedly refuses to overstate what it can do —
commands are read, not obeyed; only hooks and permissions block. A constitution that promised
enforcement would contradict the product's central claim on its first page.

## Decision

We will ratify a first constitution at version 1.0.0, drawing its principles from behaviour the
repository already enforces or already states, rather than from new ambition. Specifically: evidence
over assertion, proportionate process, traceable artifacts, repair at the source, and honest
enforcement; plus security and prompt boundaries, workflow and quality gates, and governance. We
will keep the preset's eight Delivery Principles unchanged as the appended contribution.

## Status

Accepted

## Consequences

The constitution now has a quotable standard, and `speckit-check` no longer reports missing sections.

Negative consequences, stated plainly:

- Five core principles plus eight delivery principles is thirteen — enough that a reader may treat
  them as a checklist to satisfy rather than a standard to meet. That risk is accepted because the
  alternative was zero.
- Principle V constrains future documentation: the kit may not describe a command as enforcing
  anything, even where that phrasing would be more satisfying.
- Ratifying at 1.0.0 means every later refinement is a visible version bump, including PATCH-level
  wording fixes that previously needed no ceremony.

Follow-up records implied: if a principle is ever found untestable, record 0002 should supersede it
rather than quietly reword it.

## Evidence

- `.specify/memory/constitution.md` — the ratified text (version 1.0.0).
- `speckit-check .` — before: "the resolved template requires 9 section(s) this constitution lacks";
  after: install current, no missing-section notice.
- `.specify/presets/spec-driven-development/templates/constitution-addendum.md` — the eight Delivery
  Principles, retained verbatim.
- `AGENTS.md`, `README.md`, `skill/spec-driven-development/SKILL.md` — the stated practices each core
  principle was derived from.
- `hooks/speckit-hooks.yaml`, `scripts/self-gate.sh`, `.github/workflows/self-gate.yml` — the
  enforced practices referenced in Sections 2 and 3.

**Confidence:** high for the derivation of each principle from existing repository practice; medium
for the choice of five core principles over a longer or shorter list, which is a judgement call
rather than a finding.
