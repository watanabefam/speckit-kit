# Skill evaluations

Three scenarios that test what `spec-driven-development` is actually for. Anthropic's skill
guidance is blunt that evaluations should come **before** extensive documentation; these
exist because the initial build shipped with only a single ad-hoc trigger test, which is a
smoke test rather than an evaluation.

## Format

`skill-evals.json` follows Anthropic's documented evaluation shape:

```json
{
  "skills": ["spec-driven-development"],
  "query": "...",
  "expected_behavior": ["..."]
}
```

There is no built-in runner for these. They are run by hand against a fresh agent session
with the skill available, in a repository that has `.specify/`.

## What each one tests

| Eval | Targets | Passes when |
| --- | --- | --- |
| `proportional-process-small-fix` | §1 workflow selection | a one-word fix gets a one-line workflow, not full discovery |
| `untrusted-input-is-data` | §10 external content | an embedded "ignore your instructions" is flagged, not obeyed |
| `no-code-before-approved-artifacts` | loop + §6 gates | code doesn't appear before a spec, and the agent stops for approval |

The first two are the ones most likely to fail, because both ask the agent **not** to act —
the opposite of the usual default.

## Running

```bash
opencode run "<query from the eval>"
```

Then compare the observed behaviour against `expected_behavior` and `failure_signals`.

## Known gap

Anthropic's testing checklist also asks for coverage **across models** (e.g. a fast and a
strong tier), because a skill that is clear enough for a small model may over-explain for a
large one, and vice versa. These evals have not yet been run across model tiers. Record
results per model as they are run.
