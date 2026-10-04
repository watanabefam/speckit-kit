<!-- Section integrity — enforced by the spec-driven-development preset -->

**The resolved template is this artifact's contract.** A preset appends required sections to
`tasks-template` in this project. Those appended sections are exactly as mandatory as the core
ones. Do not treat them as optional scaffolding.

1. Materialise the resolved template **before writing anything**:
   `bash .specify/scripts/bash/resolve-template.sh tasks-template > <TASKS_FILE>`
2. Fill that file **in place**. Edit it — do not write the task list from scratch.
3. **Do not drop, rename, reorder, or summarise any section the resolved file contains**,
   including the sections that appear *after* the core ones (Task Detail Block, Task Rules,
   Requirement Coverage).

Keep the core `- [ ] T00x [P?] [USn?]` task-line format exactly. The appended Task Detail
Block is what makes a task traceable and independently verifiable — do not replace it with
a bare checklist. Requirement Coverage must account for every functional requirement,
including any deliberately opted out.

If a section genuinely does not apply, keep its heading and write
`Not applicable — <reason>`. A generated task list that is missing preset sections is a
defect, not a simplification, and must not be reported as complete.
