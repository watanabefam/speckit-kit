# Quickstart — for AI assistants

**You are reading this because someone asked you to set up spec-driven development, and you have
just been given this repo.** Everything you need is below. Do not ask them anything technical.

Your goal: the project directory ends up with a working `/speckit` command, and the user knows
which command to run next.

## Bootstrap

Run these in order. Each step prints whether it was already present, so **re-running is safe**.

**0. Get the kit's files if you do not already have them.**

Skip this if you are reading this inside a checkout of the kit.

```bash
KIT="$(mktemp -d)/kit"
curl -fsSL https://github.com/watanabefam/speckit-kit/archive/refs/heads/main.tar.gz \
  | tar xz -C "$(dirname "$KIT")"
KIT="$(dirname "$KIT")/speckit-kit-main"
```

No git required. If `curl` is unavailable, use `git clone https://github.com/watanabefam/speckit-kit`
and point `KIT` at the clone.

**1. Make sure the Spec Kit CLI is available.**

```bash
command -v specify >/dev/null 2>&1 || specify --version
```

If that fails, install it (prefer `uv`; fall back to `pipx`):

```bash
command -v uv >/dev/null 2>&1 && uv tool install "specify-cli==1.0.13" \
  || pipx install "specify-cli==1.0.13"
```

**2. Install the kit's commands into the project directory** (the one the user wants set up —
usually your current working directory):

```bash
"$KIT/bin/speckit-init" .
```

That single command installs Spec Kit, the project's rules, and the `/speckit` entry point.

**3. Confirm it worked** — all three must be present:

```bash
test -f .opencode/commands/speckit.md && echo "ok: /speckit"
test -f .opencode/commands/speckit.constitution.md && echo "ok: /speckit.constitution"
test -d .specify/presets/spec-driven-development && echo "ok: rules preset"
```

If any line is missing, report it and stop. Do **not** hand-edit anything under `.specify/` or
`.opencode/commands/` — those files are generated and edits get overwritten.

## Then tell the user this, verbatim

> Done. Run `/speckit.constitution` once — it writes the project's delivery principles. After that,
> run `/speckit` and describe what you want to build; it picks the right workflow and walks you
> through it.

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

## Do not reconstruct this from memory

The files are authoritative. If step 0 or 2 fails, report the exact error and stop — do not
hand-write `.specify/` files or recreate the installer yourself. A hand-built approximation will
drift from the real thing and fail silently later.

## What you just set up, in one paragraph

Spec-driven development means writing down what you want *before* writing the code. The documents
are the source of truth; the code is made to match them. It costs slightly more upfront and saves
rework, because disagreements get caught in a document instead of in production.

For small, well-understood changes `/speckit` deliberately skips most of this. Over-process is a
failure mode here too.
