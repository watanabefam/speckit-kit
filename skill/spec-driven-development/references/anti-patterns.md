# Decision Procedure and Anti-Patterns

## Working procedure

Use at the start of a request, and again whenever the work changes direction.

```
1.  Read the project instructions and the repository's Spec Kit artifacts.
2.  Classify the request.
3.  Decide whether discovery is genuinely needed.
4.  Inspect the repository when the request concerns implementation.
5.  Identify affected users, systems, behaviour, and scope.
6.  Check for blocking or material ambiguity.
7.  Ask the smallest set of important questions, or record reasonable assumptions.
8.  Select the appropriate workflow.
9.  Produce only the artifact the current phase calls for.
10. Stop at the required approval gate.
11. Carry forward decisions, constraints, assumptions, risks, open questions.
12. Preserve traceability: requirement → design → task → verification.
13. Repair earlier artifacts when a contradiction appears.
14. Implement only approved work.
15. Converge against the specification and acceptance criteria.
```

## Anti-patterns

### Giant prompt duplication

Repeating the whole methodology inside every artifact or request. Apply it; don't quote it.

### Unconditional full discovery

Running competitor research, persona development, and product analysis for a maintenance
task. This is the single most expensive misapplication of this workflow.

### Artifact duplication

Maintaining competing versions of the specification, the design, the task plan, or the
acceptance criteria. One authoritative artifact per purpose.

### Silent scope expansion

Adding helpful features nobody asked for. "Helpful" is not the same as "approved".

### Design before repository inspection

Producing an implementation plan without reading the relevant code and tests.

### Questions without impact

Asking questions whose answers do not materially change the work.

### Approval theatre

Requesting approval for formatting changes and obvious test updates. It trains the user to
rubber-stamp, which defeats the gates that actually matter.

### False completion

Claiming done without verification evidence. See `convergence.md`.

### Symptom patching

Fixing a contradiction in a downstream artifact while leaving the cause in an upstream one.
Always repair the earliest affected artifact.

### Skill neglect

Having this skill available and not loading it, then improvising a workflow. If `.specify/`
exists, load it.
