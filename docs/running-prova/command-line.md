---
sidebar_position: 1
---

# The Command Line

The `prova` binary is one run command plus a small family of verbs: `init` to scaffold a package, `run` to enter a lane, `eval` for one-shot snippets, `learn` and `skill` for discovery, the ledger verbs (`promises`, `burndown`, `owed`, `evidence`, `attest`, `reminders`, `falsify`), the topology verbs (`up`, `watch`, `start`, `down`, `ps`), `mcp` to serve an agent over MCP, and `packages` / `package lint` for the package ecosystem. Give the run command paths and it runs them; give it nothing and it runs the suite declared in `prova.toml`. Every flag composes with either mode, and command-line flags always win over manifest values.

```text
usage:
  prova <file-or-dir>...    run the given files/dirs
  prova                     run the suite declared in prova.toml (found by walking up)
  prova run [<lane>]        run the suite through a named lane ([profiles.<lane>]) — sugar
                            for --profile; `prova run --list` lists this package's lanes
  prova init [<key>]        render a catalog archetype into this package, then wire IDE support
  prova ide setup           (re)wire this package's LuaLS support: core stubs + .luarc.json
  prova eval '<code>'       run a one-shot Lua snippet in the full prova environment and print
                            the returned value (`-` reads the snippet from stdin)
  prova learn [<topic>]     the topic catalog: progressive disclosure of how Prova works
  prova skill               print the agent skill (how to drive Prova); --install writes it
                            to .claude/skills/prova/SKILL.md at the project root
  prova promises            list the open promises — proofs authored ahead of implementation
  prova burndown [<sel>]    the implementing loop: run only promised tests, open promises
                            failing loud with full detail
  prova falsify [<sel>]     prove the proofs can fail: apply declared falsifiers, invert the verdict
  prova owed                what this package still owes: open promises, unproven claims,
                            dangling covers, due reminders
  prova evidence            the whole account: CLAIMED / BOUND / PROMISED / ATTESTED, then owed
  prova attest [<address>]  did the proof covering this claim actually RUN? (no address: every claim)
  prova reminders           the attention account: every reminder with its recorded state
  prova list [<sel>]        discover tests without running them (respects selection)
  prova mcp                 serve Prova to an agent as an MCP server over stdio
  prova up [<topology>]     list topologies, or stand one up and hold it until Ctrl-C
  prova watch <topology>    stand up a topology and re-apply on definition change (dev loop)
  prova start <topology>    stand up a topology detached (returns; use `down` to stop)
  prova down <topology>     tear down a detached topology
  prova ps                  list running topologies
  prova packages [<query>]  search the configured package registries (info / add subcommands)
  prova package lint <f>... check package files against the namespacing grammar
```

## Run a subset

```shell
prova -k MySQL                 # every node whose path mentions MySQL — one variant of a matrix
prova --tags '!build'          # skip the slow build tier
prova --node "dotnet-rest[MySQL] CRUD round-trip › created items land in MySQL"
prova --last-failed            # re-run exactly what was red, nothing else
```

Selection is dependency-aware (upstream gates are pulled in) and flow-atomic; deselected nodes never provision fixtures, so filtering a container-heavy matrix is as cheap as it sounds. Full semantics in the [CLI reference](../reference/cli.md#selection-semantics).

## Lanes: `prova run`

Teams shape profiles into **lanes** — one `prova` for every layer of the bar — and `prova run` is their front door:

```shell
prova run ut                   # the fast unit lane ([profiles.ut]: tags = ["unit", "!slow"])
prova run ci                   # the merge gate — same as --profile ci
prova run --list               # what lanes does this package have?
```

A lane's `description` in the manifest is what `run --list` prints; its `tags` are the lane's baked selection, and CLI selection narrows **within** it. See [Manifest & Profiles](./manifest-and-profiles.md).

## Starting a package: `prova init`

`prova init` scaffolds a package by rendering a catalog archetype into the current directory, then wiring [IDE integration](./ide-setup.md) as a finishing step (unless you pass `--no-ide`). The archetype owns the layout; Prova selects and renders it. It refuses to overwrite an existing manifest, so it never clobbers a configured project.

```shell
prova init            # choose an archetype interactively, then render it here
prova init project    # render the built-in project archetype
prova init package    # render the package archetype (a namespace others require())
prova init --list     # print the catalog; render nothing
```

The catalog is the built-in `project` and `package` entries, anything a configured registry serves, and your own `[init.*]` entries in `~/.config/prova/config.toml` — see [Scaffolding](./scaffolding.md) for the full picture. Drop a proof file under the rendered manifest's root and a plain `prova` runs it — [Your First Test Suite](../getting-started/your-first-test-suite.md) walks the whole loop.

## Two modes: explicit paths vs. manifest-driven

**Explicit paths** run exactly what you point at — files or directories, any mix:

```shell
prova proofs/orders.prova.lua               # one file
prova proofs/orders proofs/payments         # two directories
prova proofs --jobs 4                       # a whole tree, 4 suites at a time
```

Explicit paths **bypass the manifest entirely** — no `[run]` configuration, no `[run.env]`, no declared suites. This keeps the inner loop predictable: what you typed is what runs.

**Manifest-driven** runs kick in when you pass no paths. Prova finds the manifest by walking up from the current directory (checking `prova.toml`, `.prova.toml`, `prova/prova.toml`, and `.prova/prova.toml` — or takes the file given with `--manifest`), applies its environment variables, resolves its [declared packages](/docs/packages/using-packages), and runs its declared proofs and suites:

```shell
prova                                       # the [run] profile from the discovered manifest
prova --profile ci                          # overlay [profiles.ci] on [run]
prova --manifest infra/prova.toml -p smoke  # a manifest somewhere else
```

If there's no readable manifest and no paths, Prova prints usage and exits with code `2`. See [Manifest & Profiles](./manifest-and-profiles.md) for how the manifest is structured and merged.

## Probing with `prova eval`

`prova eval '<code>'` runs a one-shot Lua snippet in the **full prova environment** — every built-in module, the manifest's packages via `require()`, and a real transient `ctx` — and prints the returned value. It kills the "write a throwaway test file just to poke at something" ceremony: probe an API's shape, dress-rehearse a fixture, check what a container's URL looks like.

```shell
prova eval 'return 1 + 1'
prova eval 'return fs.glob(".", "**/*.toml")'
prova eval 'local db = require("postgres").container(ctx); return db.url'
prova eval - < snippet.lua                       # read the snippet from stdin
prova eval 'return http.get("http://localhost:8080/health"):json()' --format json
```

The `ctx` is real: `ctx:manage`, `ctx:defer`, and `ctx:tempdir` all work, and **everything the snippet provisions is torn down when it returns** — success or error — so probing a live container is safe and self-cleaning. Scalars print plainly, tables print as pretty JSON, and `--format json` forces JSON for everything (a snippet is a bare expression or statements with an explicit `return`; `-` reads it from stdin). `--profile`, `--manifest`, and `-P/--package` compose exactly as on a run; without a manifest the snippet still runs with just the built-ins.

## Learning from the binary: `prova learn`

`prova learn` is the discovery rail — the topic catalog, one screen per topic, rendered with **this** package's facts (its proofs, dependencies, topologies, lanes):

```shell
prova learn                    # list the topics
prova learn pdd                # the practice
prova learn project            # this package's shape — where things live here
prova learn packages           # using capabilities the core doesn't ship
```

The same content an agent gets over MCP; a team's own docs join the catalog via the manifest's top-level `context` key. See the [CLI reference](../reference/cli.md#prova-learn) for the full topic list.

## The ledger verbs

The evidence account, queryable. None of these execute proof bodies except `burndown` and `falsify`:

```shell
prova promises        # the open surface: proofs authored ahead of implementation
prova burndown        # run only the promised tests, open ones failing loud — the implementing loop
prova owed            # every open obligation: promises, unproven claims, dangling covers, due reminders
prova evidence        # where does this package stand? CLAIMED / BOUND / PROMISED / ATTESTED + owed
prova attest          # is every claim evidenced by an executed, passing proof? — the CI gate
prova reminders       # the attention account: DUE / WATCHING / UNEVALUATED
prova falsify         # apply declared falsifiers; a proof that survives its mutation is vacuous
```

`promises` and `burndown` are the authoring loop for [Promises & Burndown](../writing-tests/promises-and-burndown.md); the rest are covered verb-by-verb in the [CLI reference](../reference/cli.md#prova-owed).

## Holding environments: the topology verbs

A [topology](../writing-tests/topologies.md) registered in the manifest's `[topologies]` table is addressable from the command line — the same factory your tests build as a fixture:

```shell
prova up                     # list the topologies this package registers
prova up orders              # stand it up, print endpoints, hold until Ctrl-C
prova up orders --fixed      # same, but on canonical ports (postgres 5432, …)
prova watch orders           # re-provision on every edit to the definition (dev loop)
prova start orders           # stand it up detached and return
prova ps                     # list running topologies (name, pid, uptime, endpoints)
prova down orders            # tear down a detached topology
```

`up` and `watch` hold your terminal and tear down on Ctrl-C; `start` spawns a detached holder (its output goes to `<home>/running/<name>.log`) that `down` stops with the identical in-process teardown. By default ports are random so several topologies coexist; `--fixed` pins canonical container ports for external tools. All the verbs accept `--profile` and `--manifest`. The full walkthrough is in [Topologies](../writing-tests/topologies.md); the flag-by-flag reference in the [CLI reference](../reference/cli.md#topology-verbs-up-watch-start-down-ps).

## Serving an agent: `prova mcp`

`prova mcp` serves Prova as an MCP server over stdio, resolved against the prova home exactly like a run. Its tools mirror the CLI — `run`, `list`, `eval`, `owed`, `evidence`, `attest`, `introspect`, `learn` — and the embedded [agent skill](../getting-started/what-is-prova.md#prova-teaches-your-agent) rides along as the server's `instructions`, so an MCP client knows Prova the moment it connects.

```shell
prova mcp                                   # serve on stdio; the client speaks JSON-RPC
prova mcp --profile ci --manifest prova.toml  # same resolution flags as a run
```

Because the server is one long-lived process, it can also **hold a topology warm** — the one thing the CLI cannot do. `up { name }` provisions a [topology](../writing-tests/topologies.md) once inside the server; `run { topology = name }` and `eval { topology = name }` then resolve that held live instance instead of re-provisioning, so an agent's iterate-and-re-run loop lands in milliseconds and state accumulates across calls. `down` runs the teardown, `status` lists what's held. This is the MCP analogue of leaving `prova up` running in a terminal. The full tool set, result shapes, and warm semantics are in the [CLI reference](../reference/cli.md#prova-mcp).

## Flags

### `--profile`, `-p`

Select a `[profiles.<name>]` overlay from the manifest (`prova run <name>` is the memorable spelling). Naming a profile that doesn't exist is an error (exit `2`). Only meaningful for manifest-driven runs — explicit paths ignore the manifest, profile included.

```shell
prova --profile ci
prova -p smoke
```

### `--manifest`

Use a specific manifest file instead of discovering one:

```shell
prova --manifest configs/acceptance.toml --profile dev
```

### `--format` (and `--json`), `--junit`

Choose the output format: `console` (human-readable, the default), `json` (a JSONL event stream for machines), or `tap` (Test Anything Protocol). `--json` is shorthand for `--format json`, and `--format=json` works too. `--junit PATH` additionally writes a JUnit XML report to a file, composing with whatever `--format` prints — console for the human, `results.xml` for the CI dashboard, one run.

```shell
prova proofs --format json
prova proofs --json                # same thing
prova proofs --format tap
prova proofs --junit results.xml   # console to stdout + JUnit XML to the file
```

All the formats are covered in detail in [CI & Output](./ci-and-output.md).

### `--jobs`, `-j`

Run up to N suites concurrently. Concurrency in Prova is **throughput only — it never changes what your tests mean**: a flow stays serial at `--jobs 100`, and declared resources and dependencies are respected at any level of parallelism (see [Dependencies & Scheduling](../writing-tests/dependencies-and-scheduling.md)).

```shell
prova proofs --jobs 8
prova proofs -j 8
```

The value must be a positive integer; anything else is a usage error. The default is `1`.

### `--package`, `-P`

Register an ad-hoc [package](/docs/packages/) for this run — `name=source`, repeatable, layered over the manifest (a `-P` entry overrides a manifest dependency of the same name). The source is anything `[dependencies]` accepts: a local path, a git URL, or the `org/repo@ref` shorthand.

```shell
prova --package redis=acme/prova-redis@v1
prova -P postgres=../prova-postgres          # a local checkout, for package development
```

Packages a project depends on belong in the manifest's `[dependencies]` table, where they are versioned with the tests — the flag is for one-off extras and for developing a package against a real suite. See [Using Packages](/docs/packages/using-packages).

### `--update-snapshots`, `-u` and `--unreferenced`

Snapshot management for [`matches_snapshot`](../writing-tests/assertions.md#snapshots) assertions. `-u` (re)writes every `.snap` a run touches instead of comparing — the "accept the new output" verb; review the diff like code. `--unreferenced warn|delete` reconciles `.snap` files **no test referenced**: `warn` lists them and fails the run (so CI catches rot), `delete` removes them. Reconciliation only makes sense on a full run, so it is skipped (with a note) whenever a selection flag is active.

```shell
prova -u                          # accept current output as the new snapshots
prova --unreferenced warn         # CI: fail if orphaned .snap files exist
prova --unreferenced delete       # clean them up locally
```

### `--list`

Discover tests without running them. Prova loads each test file, builds the plan, and prints one line per runnable test — group names joined to the test name with `›`:

```shell
$ prova proofs/orders --list
orders api › creates an order
orders api › rejects an empty cart
checkout flow › add item
checkout flow › pay
```

No fixtures are built and no test bodies execute — this is pure collection, the same discovery a GUI or IDE frontend would use.

The rest of the flags — `--color`, `--quiet`, `--progress`, `--gha`, `--record`, `--heed`, `--promises`, `--due`, `--allow-empty`, `--topology`, `--fresh`, `-U`/`--offline`, `--update-baseline` — are covered flag-by-flag in the [CLI reference](../reference/cli.md#options).

## Discovery rules

Given a directory, Prova recursively collects **proof declaration files**: any file named `*.prova.lua` (`*_test.lua` and `*.test.lua` are also accepted). Results are sorted, so discovery order is deterministic. A path that is itself a file is taken as-is.

How files group into **suites** matters for parallelism and shared state:

- A directory containing a `suite.lua` becomes **one suite** owning every test file in its entire subtree, with `suite.lua` run first as setup. All of the suite's files share one Lua state, so `Scope.Suite` fixtures are built once and shared across them.
- Every test file *not* under a `suite.lua` directory is its own **singleton suite** — one file, no setup.

`--jobs` parallelizes **across suites**; each suite gets its own Lua state. The zero-config default — no `suite.lua` anywhere — is therefore exactly per-file parallelism. See [Suites & Shared State](../writing-tests/suites-and-shared-state.md) for the authoring side of this.

:::tip
`suite.lua` is the zero-config way to group; the manifest's `[suites.<name>]` tables cover grouping that doesn't match your directory tree. Both are described in [Manifest & Profiles](./manifest-and-profiles.md).
:::

If discovery finds no test files at all, Prova reports it and exits with code `2` (pass `--allow-empty` when an empty selection is expected).

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Run completed and every test passed (skips don't fail a run) |
| `1` | Run completed with at least one test failure |
| `2` | Usage or environment error — unknown flag, bad flag value, unreadable manifest, unknown profile, no tests found, or a `must_run` guarantee unmet (a broken environment is not a skipped test) |

This is the contract CI relies on: gate on the exit code, parse the output only when you want detail.

## For package authors: `prova package lint`

`prova package lint <file>...` checks package files against the namespacing grammar and nudges you to ship the `---@meta` stub that gives consumers editor completion. It belongs to the package-authoring workflow — see [Authoring Packages](/docs/packages/authoring-packages).

The full flag-by-flag reference lives at [CLI Reference](../reference/cli.md).
