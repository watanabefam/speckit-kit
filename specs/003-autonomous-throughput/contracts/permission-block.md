# Contract — Permission block

**Consumers:** opencode (evaluates it), the installer (writes it), the self-gate (asserts it).
**Requirements:** FR-001, FR-002, FR-003, FR-015.

## Shape

The installer writes a `permission` block into the **project** `opencode.json`. If the file exists, the
block is printed and the file is left untouched.

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "*": "allow",

    // Broad gates first — these only prompt.
    "bash": {
      "*": "allow",
      "git push*": "ask",
      "git reset --hard*": "ask",
      "git clean*": "ask",
      "rm -rf*": "ask",
      "psql*": "ask",
      "kubectl delete*": "ask",
      "terraform apply*": "ask",
      "gh pr merge*": "ask",

      // Specific denies LAST — opencode evaluates in order and the last match wins,
      // so a deny only holds if it follows the broader rule it must override.
      "git push*--force*": "deny",
      "git push*-f": "deny",
      "git push* -f": "deny",
      "git commit --no-verify*": "deny",
      "git -c core.hooksPath=*": "deny",
      "npm publish*": "deny",
      "pnpm publish*": "deny",
      "yarn publish*": "deny",
      "cargo publish*": "deny",
      "supabase db push*": "deny",
      "supabase db reset*": "deny",
      "prisma migrate reset*": "deny"
    }
  }
}
```

## Rules

- **Order is load-bearing.** The catch-all comes first; specific `deny` rules come **last**. Reversing
  the order silently downgrades a deny to an allow — the exact failure FR-003 exists to prevent.
- **Fail-closed.** A command matching both an allow and a deny resolves to deny.
- **No secrets.** No token, key, host credential, or path outside the project appears in the block.
- **Editable.** The block is ordinary project config; a user may change it, and the change is visible
  in the diff.

## Known limitation — globs cannot express flags or wrappers

opencode patterns are simple globs on the command string. Two things a glob cannot express, and how
each is covered:

- **Flag position and quoting.** `git push --force*` misses `git push origin main --force`, and a
  `-f` glob false-positives on the benign `--follow-tags`. The glob `git push*--force*` covers the
  long flag in any position; the **token-based hook `block-force-push`** covers `-f`, `--force-*`,
  and `+<refspec>`. The hook **strips quote characters first**, so `git push '-f' …` cannot evade it.
- **Wrappers and infixes.** `supabase db push*` misses `npx supabase db push`, and `pnpm publish*`
  misses `pnpm -r publish`. The **token-based hook `block-destructive-commands`** covers `publish`
  (npm/pnpm/yarn/cargo), `supabase db push|reset`, and `prisma migrate reset|deploy`, including
  `npx`/`dlx` and `-r` forms. It is **segment-guarded** — the CLI must start a command segment — so a
  command that merely mentions the words (`grep -r npm publish .`) is allowed.

`self-gate.sh` §1d3 asserts the glob coverage, and §1f exercises each hook predicate against its
force/irreversible forms *and* its benign ones, including the quoted forms that first defeated it.

## Residual risk — rule precedence is documented, not verified here

The block's correctness depends on opencode evaluating rules in order and taking the **last** match
(its documented behaviour). The gate only *simulates* that fold; a live session is required to confirm
it, and until then a first-match implementation would leave the boundary inert. This is task **T042**
and risk **R1/R2**, and the CHANGELOG states the dependency rather than claiming enforcement.

## Non-goals

- This block does **not** isolate the agent (no filesystem/network boundary). Isolation is parked.
- It does **not** replace the hooks; the hooks remain the two near-zero-false-positive rules.
- It does **not** protect a repository whose user edits the block away; that is the user's choice.

## Acceptance

1. No `opencode.json` → the file is created with the block above.
2. Existing `opencode.json` → unchanged; the block and a merge instruction are printed.
3. A denied command is blocked **without the model's cooperation** (opencode, not the prompt).
4. Every entry on the irreversible list is matched by a `deny` rule (SC-002, P-003).
