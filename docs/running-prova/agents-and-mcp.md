---
sidebar_position: 5.5
---

# Agents & MCP

Prova is built to be driven by an agent as much as by a person: the same commands, the same lanes,
the same ledger, and the same bar. Two things make that work: the binary teaches itself, and it
serves itself over the Model Context Protocol. `prova learn mcp` carries the same material in the
binary.

## The binary teaches itself

```shell
prova learn                # the topic catalog, one screen per topic
prova learn promises       # one topic; slots render THIS package's own facts
prova introspect http      # the API surface: every matching function, signature and summary
prova skill --install      # write the agent skill to .claude/skills/prova/SKILL.md
```

Topics are rendered at call time, so `prova learn project` names this package's proof directories,
lanes and writable spec sources rather than a generic example. An agent arriving in a repository
should ask the binary before guessing from the files around it.

## Serving Prova over MCP

```shell
prova mcp                                     # serve on stdio
prova mcp --profile ci --manifest prova.toml  # the same resolution flags as a run
```

The tools mirror the CLI, and each returns compact JSON (`learn` returns markdown). The embedded
skill is sent as the connection's instructions, so a client knows the practice the moment it
connects.

| Tool | CLI twin |
|---|---|
| `run`, `list` | `prova` with selection flags, `prova tests` |
| `eval` | `prova eval '<code>'` |
| `learn`, `introspect` | `prova learn`, `prova introspect` |
| `owed`, `evidence`, `attest` | the ledger verbs |
| `tests`, `specs`, `capture` | the tests and specs lanes; `capture` is `prova specs capture` |
| `reminders`, `switches`, `capabilities`, `packages` | the matching verbs |
| `up`, `down`, `status` | `prova up`, `prova down`, `prova ps`, held inside the server |

The package resolves once, at startup, from the server's working directory. Any call can retarget
with `package` (a directory or manifest path), which resolves fresh, so a package scaffolded a moment
ago works without restarting the server. Calls are handled in order, so side effects land in the
order the agent made them.

## Warm topologies: the reason to prefer MCP while iterating

The CLI is cold by design: every run provisions its fixtures again. The MCP server is one long-lived
process, so it can hold a [topology](../writing-tests/topologies.md) warm:

```text
up   { name = "orders" }                              -- provision once, held in the server
run  { topology = "orders", last_failed = true }      -- reruns in milliseconds
eval { code = "return orders.db.url", topology = "orders" }
down { name = "orders" }                              -- the one place teardown happens
```

- Warm calls never provision implicitly: a topology that is not held is an explicit error, so `up`
  first.
- The holder owns teardown. Warm runs never reap; `down`, or the server shutting down, does.
- Held state accumulates on purpose. `down` and then `up` when isolation matters.

## Splitting work between the two surfaces

| Over MCP | From the CLI |
|---|---|
| iterating: `run`, `eval`, warm topologies | scaffolding: `prova init`, `prova ide setup` |
| discovery: `learn`, `introspect` | `prova package lint`, `prova skill --install` |
| capturing findings: `capture` | anything CI runs: CI is always the CLI |

## What an agent is expected to do

The practice an agent receives is the one this site describes: write the proof first and expect it to
be red; implement until `prova --last-failed` is green; never weaken a proof to pass it; capture what
it finds and does not fix as backlog, a claim, a promise or a reminder rather than growing the current
change; and report the tally, not a claim. `prova owed` is its assignment, `prova tests burndown` its
inner loop, and `prova attest` the definition of done. See
[The Proof-Driven Change](../workflows/the-proof-driven-change.md).
