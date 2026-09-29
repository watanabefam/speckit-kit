# Existing-Project Inspection

Load before adopting Spec Kit's workflow in a repository that already has code. Written once
per repository, kept short, updated when the shape of the project changes.

```markdown
# Existing-Project Inspection

## Repository Structure

## Application Entry Points

## Relevant Components

## Test Strategy

## Build and Deployment

## Coding Conventions

## Data Stores and Migrations

## External Services

## Security and Access Controls

## Observability

## Known Constraints

## Existing Behaviour That Must Remain Unchanged

## Spec Kit Adoption Notes
```

## What not to assume

In an established repository, do **not** assume:

- the proposed architecture is new
- existing behaviour matches the product description
- the tests fully describe behaviour
- the repository uses current conventions
- a clean rewrite is acceptable

The repository is evidence. Reconcile it with the specification rather than treating the
specification as a description of what already exists.

## Why this matters

This is the most common way a brownfield change goes wrong: the agent writes a fluent plan
describing the system it assumes exists, and every downstream artifact inherits the
assumption. The inspection is cheap. Skipping it is expensive and the cost lands late.

If the inspection contradicts the specification, repair the specification first — see
"Repair contradictions at the source" in `SKILL.md`.
