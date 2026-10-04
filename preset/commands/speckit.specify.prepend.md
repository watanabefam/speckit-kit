<!-- Section integrity — enforced by the spec-driven-development preset -->

**The resolved template is this artifact's contract.** A preset appends required sections to
`spec-template` in this project. Those appended sections are exactly as mandatory as the core
ones. Do not treat them as optional scaffolding.

1. Materialise the resolved template **before writing anything**:
   `bash .specify/scripts/bash/resolve-template.sh spec-template > <SPEC_FILE>`
2. Fill that file **in place**. Edit it — do not write the spec from scratch.
3. **Do not drop, rename, reorder, or summarise any section the resolved file contains**,
   including the sections that appear *after* the core ones (Carried Forward, Problem,
   Goals, Non-Goals, Dependencies and External Contracts, MVP Scope, Future Work,
   Validation Plan, Requirement Traceability).

If a section genuinely does not apply, keep its heading and write
`Not applicable — <reason>`. A generated spec that is missing preset sections is a defect,
not a simplification, and must not be reported as complete.
