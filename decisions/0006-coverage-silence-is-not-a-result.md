# 0006 — A coverage report's silence is unmeasured, not uncovered

## Context

`specs/005-verification-integrity` FR-033/FR-034 require a changed-line report that names its coverage
profile and refuses the stronger readings. The first implementation read the report as a partition of the
change: a line in `executed_lines` was reached, and a line that was not in `executed_lines` was
`unexercised`. That second half is a claim the report does not make.

`decisions/0005` had already recorded the gap from the outside: diff_cover ships `--expand-coverage-report`
because a report can omit a file. Reading the formats themselves made the gap wider and more ordinary than
"a missing file" — the ordinary case is a single line.

## Research

1. **`coverage.py` lists statements, not lines, and it lists three kinds of them.** `jsonreport.py`'s
   `report_one_file` emits `executed_lines` (`sorted(analysis.executed)`), `missing_lines`
   (`sorted(analysis.missing)`) and `excluded_lines` (`sorted(analysis.excluded)`) beside a `summary`
   ([jsonreport.py](https://github.com/nedbat/coveragepy/blob/master/coverage/jsonreport.py)). `results.py`
   computes `n_statements=len(self.statements)`, `n_missing=len(self.missing)`, `n_excluded=len(self.excluded)`
   and `n_executed = n_statements - n_missing`
   ([results.py](https://github.com/nedbat/coveragepy/blob/master/coverage/results.py)). So a comment, a
   blank line, a stale line added after the run and a `# pragma: no cover` line all appear in **none** of
   the executed/missing arrays, and the last of those is a third, distinct state.
2. **The same shape is not Python-specific.** lcov's `geninfo` recognises `LCOV_EXCL_LINE` and
   `LCOV_EXCL_START/STOP` to keep lines out of the tracefile, and writes `DA:` records only for instrumented
   lines ([geninfo(1)](https://manpages.debian.org/bookworm/lcov/geninfo.1.en.html)).
3. **The available alternative is inference, and it is a guess.** diff_cover's `--expand-coverage-report`
   fills every line the report omits with **the previous line's hit count** so a partially reported file can
   be scored
   ([violations_reporter.py](https://github.com/Bachmann1234/diff_cover/blob/main/diff_cover/violationsreporters/violations_reporter.py)).
   That is a defensible product decision for a diff-coverage percentage and an indefensible one for a
   verification report: it turns silence into a number with no provenance, which is the defect this feature
   exists to name.
4. **A report can also contradict itself.** `summary.num_statements` is the report's own claim about how many
   statements it measured; if it disagrees with `len(executed)+len(missing)` for a file, the file's line lists
   are truncated or from another revision, and no line in them can be trusted.

## Decision

1. **Five states, and only two of them measure the change.** A changed line is `reached`, `unexercised`,
   `excluded` (declared out of measurement — a pragma or an `LCOV_EXCL_*` marker), `unmentioned` (the report
   is silent), or `unprofiled` (its file is absent). A report the summary contradicts makes every changed line
   in that file `inconsistent`, which is a fourth kind of unmeasured.
2. **Only measured lines enter the denominator.** The figure reads `reached N of M measured changed lines`,
   and unmeasured lines are counted and named beside it. An unmeasured line is never a numerator term and
   never a denominator term, so a change the tests never looked at cannot move the percentage in either
   direction.
3. **A full profile is necessary but no longer sufficient.** FR-034 previously said only a full-suite profile
   supports "no test executes this line". It now says that, **and** that the claim is supported only for a line
   the report lists as missing; for a silent line no profile supports either reading, and the report says so.
4. **Refuse the inference.** No line is filled from its neighbour, no file is assumed covered because a
   sibling was, and a report that does not say is not made to say.

## Consequences

- FR-043 (new), FR-034 (qualified), SC-008 (extended), plan property P-013, task T077, and a fixture
  (`case coverage-silence`) whose negative control is reverting the classification branch: silence → rejected
  by both the case and the property.
- `bin/speckit-verify --coverage` prints `excluded`, `unmentioned`, `unprofiled` and `report inconsistent`
  lines, and the `--json` report carries the same four sets.
- Numbers get smaller and harder to misread. A project whose coverage JSON is stale will now see
  `unmentioned` rather than a fabricated `unexercised` count — that is the point, and it will look like a
  regression to anyone who trusted the old figure.
- Nothing here blocks a merge. The changed-line section is a reporting obligation, per 005's non-goals.
