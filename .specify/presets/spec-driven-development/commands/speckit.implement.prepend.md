<!--
  spec-driven-development preset — command contribution.
  Composed with strategy: "prepend" (after frontmatter, before the command's steps).
  Contract: adds rules only. Never removes, reorders, or overrides the core command.
-->

## Step rules

### Implement only approved work

Execute the tasks as written. Do not add features, scope, or refactors that nobody approved —
including ones that look obviously helpful. "Helpful" is not the same as "approved".

### Evidence before "done"

You may **not** mark a task or feature complete because the code compiles, a single test
passes, a file was edited, or the implementation looks correct.

Mark a task complete only against the evidence its **Verification** line names. State what you
ran and what it showed. If something could not be verified, say so plainly rather than
implying it passed.

### Tick tasks honestly, as you go

Transition `- [ ]` to `- [x]` in `tasks.md` as each task actually completes. If a task could
not be completed — missing credentials, an external dependency, an environment you do not
have — **leave it unticked and say why**. Never tick a box to make the list look finished.

### If reality contradicts the plan

Stop. Explain the contradiction, identify the **earliest** affected artifact (spec before plan,
plan before tasks), repair that artifact, and re-check what depends on it. Do not patch a
downstream artifact while leaving the cause upstream — that is how artifacts drift apart.

If the repair changes scope, behaviour, architecture, security, data, or cost, surface it for
approval rather than proceeding.
