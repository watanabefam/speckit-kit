<!--
  spec-driven-development preset — command contribution.
  Composed with strategy: "prepend" (after frontmatter, before the command's steps).
  Contract: adds rules only. Never removes, reorders, or overrides the core command.
-->

## Section integrity (mandatory)

**The resolved template is this artifact's contract.** A preset appends required sections to
`plan-template` in this project. Those appended sections are exactly as mandatory as the core
ones — do not treat them as optional scaffolding.

1. Materialise the resolved template **before writing anything**:
   `bash .specify/scripts/bash/resolve-template.sh plan-template > <PLAN_FILE>`
2. Fill that file **in place**. Edit it — do not write the plan from scratch.
3. **Do not drop, rename, reorder, or summarise any section the resolved file contains**,
   including the sections after the core ones (Carried Forward, Scope Confirmation, Repository
   Findings, Architecture Overview, Major Components, Data Flow, Interfaces and Contracts,
   Dependencies, Error Handling, Security and Privacy, Performance and Reliability,
   Validation Strategy, Alternatives Considered, Risks and Mitigations,
   Requirement-to-Design Traceability, Implementation Boundaries).

If a section genuinely does not apply, keep its heading and write
`Not applicable — <reason>`. A generated plan missing preset sections is a defect.

## Step rules

### Inspect the repository before proposing anything

Read the code **before** designing against it: repository structure, the components this
change touches, their existing tests, and the project's conventions.

Fill **Repository Findings** from that inspection, not from expectation.

### Sweep before you list

A new block, field, entity, or enum member almost always appears in **more than one place**.
Search the repository for every occurrence of the concept — not just the obvious component.
Check at least:

- the schema or definition
- **any layer that enumerates the same set** — a validation schema (Zod, JSON Schema), a type
  union, a literal enum, a registry, a route table
- the component or handler
- the renderer or dispatch site
- existing tests and fixtures

A file that re-lists the same set MUST be updated too, or the build fails on the new value —
and it fails *late*, at implementation or typecheck. Name those files explicitly.

### The repository is evidence, not a blank slate

Never assume a new architecture is preferable to the existing one. Reconcile the design with
what is there. If the code contradicts the spec, repair the spec first — do not design around
a contradiction.

### Stop at the approval gate

Present the plan and **stop**. Do not begin implementation from this step.
