# 0005 — Conformance covers plans and task lists, with a recorded baseline for work records

## Context

`decisions/0004` made section conformance a gate-enforced rule for `specs/*/spec.md`. The obvious next
move was to extend it to every `plan.md` and `tasks.md`. Measuring first changed the answer:

```
specs/001/plan.md     5 missing of 44      specs/001/tasks.md     2 missing, 1 out of order of 23
specs/002/plan.md    40 missing of 44      specs/002/tasks.md    22 missing of 23
specs/003/plan.md    conforms              specs/003/tasks.md    10 missing of 23
specs/004/plan.md    44 missing of 44      specs/004/tasks.md    23 missing of 23
specs/005/plan.md    conforms              specs/005/tasks.md    conforms
```

Two plans and two task lists fail across *every* heading. Those are not artifacts that drifted: they
are the work records of features that were accepted and implemented before the current templates
existed, written against a different layout entirely.

## Research

1. **Accepted documents are not retro-fitted.** Rust RFCs should not be substantially changed once
   accepted — an amendment is a new RFC ([RFC process](https://rust-lang.github.io/rfcs/)); Python
   treats non-Draft PEPs as historical documents and advises against mass typo-only PRs on older ones
   ([CONTRIBUTING.rst](https://github.com/python/peps/blob/main/CONTRIBUTING.rst)); implemented KEPs
   are no longer actively changed
   ([KEP process](https://github.com/kubernetes/enhancements/blob/master/keps/sig-architecture/0000-kep-process/README.md)).
   A formatting-only commit is documented as damaging file history and blame.
2. **Counts-based baselines with stale-entry failure are a supported mechanism.** RuboCop's
   `.rubocop_todo.yml` records offence counts and `--report-unused-todo-entries` fails on entries that
   no longer occur ([RuboCop](https://docs.rubocop.org/rubocop/latest/usage/auto_gen_config.html));
   ESLint's bulk suppressions record file+rule+count and fail on unused entries, with
   `--prune-suppressions` to clean them ([ESLint](https://eslint.org/docs/latest/use/suppressions));
   PHPStan's baseline records counts and reports entries that no longer match
   ([PHPStan](https://phpstan.org/user-guide/baseline)).
3. **Whole-file opt-outs exist but are discouraged.** `<!-- markdownlint-disable-file -->` and Vale's
   `<!-- vale off -->` both work, and GitLab's guidance is to disable only the offending lines where
   possible — which is why this is a registry rather than an inline "skip me" marker that any new
   artifact could add.
4. **No linter skips work based on a document's own status field** — the idea was checked and does not
   exist, so exemption is recorded in a registry, not inferred from `Status: Accepted`.
5. **Fix first, then block.** GitLab's documented order for adding error-level rules is clean → warn →
   promote ([GitLab](https://docs.gitlab.com/development/documentation/testing/vale/)), the same order
   0004 used for specs.

## Decision

**1. Conformance covers specs, plans and task lists.** `scripts/conformance-baseline.py check` walks
`specs/*/spec.md`, `specs/*/plan.md` and `specs/*/tasks.md`, runs the checker on each, and the gate
fails on any failure.

**2. Living artifacts must conform; work records may be excused, once, with a reason.** Five entries in
`specs/.conformance-baseline.json` excuse the artifacts above, each with a reason naming the feature,
the layout it was written against, and why reformatting it is the wrong repair.

**3. The baseline stores exact counts, and staleness fails.** An artifact that gets *worse* fails; an
artifact that conforms again also fails until its entry is removed; an entry whose artifact is deleted
fails. This is the anti-rot rule the three tools above apply, and it is why counts are recorded rather
than a bare path — a baseline nobody has to shrink is a list of permanent exceptions.

**4. Migrate what is small and genuinely missing content.** `001`'s plan gained the
`## Correctness Properties` section its own feature mandates — a real gap, not a formatting one — and
`001`'s tasks gained the parallel example and property-task sections. These were cheap, and one of them
was the feature failing to follow its own rule. Everything else was a reformat, so it was recorded.

**5. The gate pins the baseline's own failure mode.** A negative control runs the check against a
fixture corpus containing an unexcused, non-conformant artifact and asserts it fails — otherwise a bug
that made everything pass would look exactly like a clean corpus.

## Consequences

- `conformance: 11 conformant, 5 excused by the baseline, 0 failure(s), 0 stale entr(ies)` is now a gate
  line, not a manual review item.
- The checker also stopped demanding the literal heading `## Phase N: Polish & Cross-Cutting Concerns`.
  That is a placeholder for "your own polish phase", and requiring it verbatim made every real task
  list fail on a heading nobody was supposed to copy — the same class of defect as reading a shell
  comment as a heading.
- Five excuses exist and are visible with `python3 scripts/conformance-baseline.py show`. They are a
  debt with a shrink obligation, not a permission: the moment one of those artifacts is touched for a
  real reason, regenerating the baseline either drops its entry or records the new count.
- `002`'s and `004`'s work records will stay non-conformant until someone changes them for a reason of
  their own. That is the intended outcome, and it is recorded rather than silent.
