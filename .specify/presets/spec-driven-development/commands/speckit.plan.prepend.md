<!-- Section integrity — enforced by the spec-driven-development preset -->

**The resolved template is this artifact's contract.** A preset appends required sections to
`plan-template` in this project. Those appended sections are exactly as mandatory as the core
ones. Do not treat them as optional scaffolding.

1. Materialise the resolved template **before writing anything**:
   `bash .specify/scripts/bash/resolve-template.sh plan-template > <PLAN_FILE>`
2. Fill that file **in place**. Edit it — do not write the plan from scratch.
3. **Do not drop, rename, reorder, or summarise any section the resolved file contains**,
   including the sections that appear *after* the core ones (Carried Forward, Scope
   Confirmation, Repository Findings, Architecture Overview, Major Components, Data Flow,
   Interfaces and Contracts, Dependencies, Error Handling, Security and Privacy,
   Performance and Reliability, Validation Strategy, Alternatives Considered, Risks and
   Mitigations, Requirement-to-Design Traceability, Implementation Boundaries).

Repository Findings must be filled from actually reading the code — see the sweep
instruction in that section.

If a section genuinely does not apply, keep its heading and write
`Not applicable — <reason>`. A generated plan that is missing preset sections is a defect,
not a simplification, and must not be reported as complete.
