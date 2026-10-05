# Quickstart — for AI assistants

**You are reading this because someone asked you to set up spec-driven development.** Everything you
need is below. Do not ask them anything technical.

## Do this

```bash
~/.local/bin/speckit-init .
```

That is the whole setup. It installs Spec Kit, the project's rules, and the `/speckit` entry point.

Then say this to the user, verbatim:

> Done. Run `/speckit.constitution` once — it writes the project's delivery principles. After that,
> run `/speckit` and describe what you want to build; it picks the right workflow and walks you
> through it.

## If `~/.local/bin/speckit-init` is not found

Try `speckit-init .` (it may be on `PATH`). If that also fails, the kit is not installed on this
machine — tell the user, and stop. Do not hand-edit anything in `.specify/` or
`.opencode/commands/`: those files are generated and your edits will be overwritten.

The command is safe to re-run. It detects what is already installed and updates only what changed.

## The two commands that matter

| Command | When |
| --- | --- |
| `/speckit.constitution` | Once, first. Writes the project's delivery principles. |
| `/speckit` | Every time after that. Describe what you want; it chooses the workflow and routes. |

The rest of the loop (`/speckit.specify`, `/speckit.plan`, `/speckit.tasks`, `/speckit.implement`)
is reached *through* `/speckit`. You rarely need to invoke them directly.

## If the user has no idea what to build

That is a normal starting point. `/speckit` also answers "should I even build this?" — run it and
describe the idea.

## What you just set up, in one paragraph

Spec-driven development means writing down what you want *before* writing the code. The documents
are the source of truth; the code is made to match them. It costs slightly more upfront and saves
rework, because disagreements get caught in a document instead of in production.

For small, well-understood changes `/speckit` deliberately skips most of this. Over-process is a
failure mode here too.
