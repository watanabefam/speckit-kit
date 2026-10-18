# Data Model — Autonomous Throughput and a Mechanical Boundary

**Feature**: `003-autonomous-throughput` | **Companion to**: [`plan.md`](./plan.md) (authoritative)

The kit has no database. Each "entity" below is a file structure the installer writes or an agent
reads. The model exists so the shapes are fixed before implementation, and so `tasks.md` can build
against them.

---

## E1 — Permission rule

A single entry in the installed permission block. Evaluated by opencode, not by the kit.

| Field | Type | Allowed values | Notes |
| --- | --- | --- | --- |
| `action` | enum | `allow` / `ask` / `deny` | opencode's three outcomes |
| `resource` | string | a command glob (`git push*`, `rm *`) | matched against the tool input |
| `scope` | enum | `project` / `global` | this feature writes `project` only |

**Validation rules**

- The catch-all (`"*"`) is written **first**; specific rules follow. opencode evaluates in order and
  **the last matching rule wins**, so order is load-bearing.
- `deny` must cover every entry on the fixed irreversible list (see `contracts/permission-block.md`).
- A rule must not name a secret, a token, or a host credential.

**State transitions**

```
absent  --init (no opencode.json)-->  created   (block written)
absent  --init (opencode.json exists)-->  printed   (block offered, file untouched)
created --user edit-->  user-modified   (never overwritten; drift reported)
```

---

## E2 — Command record

One entry in the `## Commands` block and the source of `scripts/verify`.

| Field | Type | Allowed values | Notes |
| --- | --- | --- | --- |
| `name` | enum | `install` / `test` / `lint` / `typecheck` / `build` / `verify` | `verify` is the aggregate |
| `command` | string | an exact shell command, or `unresolved` | e.g. `npm test`, `uv run pytest` |
| `source` | enum | `detected` / `confirmed` | `confirmed` = user supplied at the one-time prompt |
| `runs` | list of `name` | subset of the above, in order | only on the `verify` record |

**Validation rules**

- A `detected` command must come from an actual file in the project (`package.json` scripts,
  `pyproject.toml`, `Cargo.toml`, `go.mod`, `Makefile`) — never a guess.
- If no command is detectable, every record is `unresolved` and **no `scripts/verify` is generated**.
- `verify` runs its `runs` list in order and exits non-zero on the first failure.

**State transitions**

```
unknown  --detect (found)-->  detected   (recorded; verify generated)
unknown  --detect (not found)-->  unresolved   (one-time prompt; no verify)
detected --user confirm-->  confirmed   (overrides detection)
```

---

## E3 — Autonomy contract

A single document, installed once. Not data in the usual sense — it is the fixed shape of every
agent response.

| Field | Type | Notes |
| --- | --- | --- |
| `Done` | section | what changed, with the evidence that proves it |
| `Continuing` | section | autonomous next actions, taken now unless told otherwise |
| `Decision needed` | section | one recommendation, its trade-off, and what is blocked |
| `Approval required` | section | exact command, target, impact, rollback |

**Validation rules**

- Exactly one file exists (FR-004); no `/speckit.*` command carries equivalent prose.
- The four buckets are the only sections; the file stays within the instruction budget (~25 lines).

---

## E4 — Execution budget

The stopping condition for continuous execution.

| Field | Type | Default | Notes |
| --- | --- | --- | --- |
| `max_consecutive_failures` | integer | 3 | halt after this many in a row |
| `max_tasks_per_run` | integer | unbounded (or a configured cap) | optional ceiling |
| `halt_on` | enum set | `budget` / `gate` / `missing_credential` | the only reasons to stop |

**State transitions**

```
running --task passes-->  running        (failures reset to 0)
running --task fails-->   running(1..n-1) (counter increments)
running --counter == max-->  halted       (failing tasks left unticked; reason recorded)
running --gate / missing credential-->  paused   (resumable from the ledger)
```

---

## E5 — Ledger entry

The resume point. One line per completed task, appended as the task finishes.

| Field | Type | Notes |
| --- | --- | --- |
| `task_id` | string | e.g. `T003` |
| `status` | enum | `complete` / `fix round n/m` |
| `evidence` | string | the command run and what it showed |
| `commits` | string | the commit range for the task |

**Validation rules**

- A task is `DONE` **iff** it has a `complete` ledger line — the resume rule.
- A line without evidence is a claim, not a checkpoint.
- The ledger names its plan; a ledger naming a different plan is archived, never merged.

**State transitions**

```
(no line) --task completes-->  complete
(no line) --task fails-->  fix round n/m   (left unticked in tasks.md)
```

---

## Relationships

```
opencode.json  ──contains──►  E1 Permission rule (0..n)
AGENTS.md      ──contains──►  E2 Command record (0..n)  ──generate──►  scripts/verify
.opencode/autonomy-contract.md ──is──►  E3 Autonomy contract
implement run  ──bounded by──►  E4 Execution budget  ──appends──►  E5 Ledger entry (0..n)
```

No entity depends on another's runtime value; the shapes are independent, which is why they can be
implemented and tested as separate tasks.
