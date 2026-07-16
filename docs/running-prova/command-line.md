---
sidebar_position: 1
---

# The Command Line

The `prova` binary is one run command plus a small family of subcommands: `init` to scaffold a project, `eval` for one-shot snippets, `skill` for agents, the topology verbs (`up`, `watch`, `start`, `down`, `ps`), and `plugin lint` for plugin authors. Give the run command paths and it runs them; give it nothing and it runs the suite declared in `prova.toml`. Every flag composes with either mode, and command-line flags always win over manifest values.

```text
usage:
  prova <file-or-dir>...    run the given files/dirs
  prova                     run the suite declared in prova.toml (found by walking up)
  prova init                scaffold prova.toml + LuaLS IDE support in this project
  prova eval '<code>'       run a one-shot Lua snippet in the full prova environment and print
                            the returned value (`-` reads the snippet from stdin)
  prova skill               print the agent skill (how to drive Prova); --install writes it
                            to .claude/skills/prova/SKILL.md at the project root
  prova up <topology>       stand up a topology and hold it until Ctrl-C (--fixed for canonical ports)
  prova watch <topology>    stand up a topology and re-apply on definition change (dev loop)
  prova start <topology>    stand up a topology detached (returns; use `down` to stop)
  prova down <topology>     tear down a detached topology
  prova ps                  list running topologies
  prova plugin lint <f>...  check plugin files against the namespacing grammar

options:
  -p, --profile NAME        run a profile from the manifest
      --manifest PATH       use a specific manifest (default ./prova.toml)
      --format console|json|tap  output format (--json is shorthand)
      --junit PATH          also write a JUnit XML report to PATH (for CI; composes with --format)
  -j, --jobs N              run up to N units concurrently
  -P, --plugin name=source  add an ad-hoc plugin (repeatable; layers over the manifest)
  -k PATTERN                select nodes whose path contains PATTERN (repeatable; !PAT excludes)
      --tags a,b            select nodes tagged with any listed tag (repeatable; !tag excludes)
      --node PATH           select an exact node path (repeatable) — re-run what a report named
      --last-failed         select only the nodes that failed in the previous run
  -u, --update-snapshots    (re)write snapshots instead of comparing (matches_snapshot)
      --unreferenced M      snapshots no test used: ignore (default) | warn | delete (full runs only)
      --list                discover tests without running them (respects selection)
  -V, --version             print version
  -h, --help                print this help
```

## Run a subset

```shell
prova -k MySQL                 # every node whose path mentions MySQL — one variant of a matrix
prova --tags '!build'          # skip the slow build tier
prova --node "dotnet-rest[MySQL] CRUD round-trip › created items land in MySQL"
prova --last-failed            # re-run exactly what was red, nothing else
```

Selection is dependency-aware (upstream gates are pulled in) and flow-atomic; deselected nodes never provision fixtures, so filtering a container-heavy matrix is as cheap as it sounds. Full semantics in the [CLI reference](../reference/cli.md#selection-semantics).

## Starting a project: `prova init`

`prova init` scaffolds everything a project needs in one command: a `prova.toml` manifest (in `./prova/` by default; `--hidden` for `./.prova/`, `--flat` for a root-level `./prova.toml`) and the [IDE integration](./ide-setup.md) — a synced `annotations/` folder plus a `.luarc.json` pointer, unless you pass `--no-luals`. It refuses to run if a manifest already exists, so it never clobbers a configured project.

```shell
prova init            # ./prova/prova.toml + IDE wiring
prova init --hidden   # ./.prova/prova.toml
prova init --flat     # ./prova.toml at the root
```

Drop a test file under the manifest's directory and a plain `prova` runs it — [Your First Test Suite](../getting-started/your-first-test-suite.md) walks the whole loop.

## Two modes: explicit paths vs. manifest-driven

**Explicit paths** run exactly what you point at — files or directories, any mix:

```shell
prova tests/orders_test.lua                 # one file
prova tests/orders tests/payments           # two directories
prova tests --jobs 4                        # a whole tree, 4 suites at a time
```

Explicit paths **bypass the manifest entirely** — no `[run]` paths, no `[run.env]`, no declared suites. This keeps the inner loop predictable: what you typed is what runs.

**Manifest-driven** runs kick in when you pass no paths. Prova finds the manifest by walking up from the current directory (checking `prova.toml`, `prova/prova.toml`, and `.prova/prova.toml` — or takes the file given with `--manifest`), applies its environment variables, resolves its [declared plugins](/docs/plugins/using-plugins), and runs its declared paths and suites:

```shell
prova                                       # the [run] profile from ./prova.toml
prova --profile ci                          # overlay [profiles.ci] on [run]
prova --manifest infra/prova.toml -p smoke  # a manifest somewhere else
```

If there's no readable manifest and no paths, Prova prints usage and exits with code `2`. See [Manifest & Profiles](./manifest-and-profiles.md) for how the manifest is structured and merged.

## Probing with `prova eval`

`prova eval '<code>'` runs a one-shot Lua snippet in the **full prova environment** — every built-in module, the manifest's plugins via `require()`, and a real transient `ctx` — and prints the returned value. It kills the "write a throwaway test file just to poke at something" ceremony: probe an API's shape, dress-rehearse a fixture, check what a container's URL looks like.

```shell
prova eval 'return 1 + 1'
prova eval 'return fs.glob("**/*.toml")'
prova eval 'local db = require("postgres").container(ctx); return db.url'
prova eval - < snippet.lua                       # read the snippet from stdin
prova eval 'return http.get("http://localhost:8080/health"):json()' --format json
```

The `ctx` is real: `ctx:manage`, `ctx:defer`, and `ctx:tempdir` all work, and **everything the snippet provisions is torn down when it returns** — success or error — so probing a live container is safe and self-cleaning. Scalars print plainly, tables print as pretty JSON, and `--format json` forces JSON for everything (a snippet is a bare expression or statements with an explicit `return`; `-` reads it from stdin). `--profile`, `--manifest`, and `-P/--plugin` compose exactly as on a run; without a manifest the snippet still runs with just the built-ins.

## Holding environments: the topology verbs

A [topology](../writing-tests/topologies.md) declared with `prova.topology(name, fn)` is addressable from the command line — the same definition your tests `use`:

```shell
prova up orders              # stand it up, print endpoints, hold until Ctrl-C
prova up orders --fixed      # same, but on canonical ports (postgres 5432, …)
prova watch orders           # re-provision on every edit to the definition (dev loop)
prova start orders           # stand it up detached and return
prova ps                     # list running topologies (name, pid, uptime, endpoints)
prova down orders            # tear down a detached topology
```

`up` and `watch` hold your terminal and tear down on Ctrl-C; `start` spawns a detached holder (its output goes to `<home>/running/<name>.log`) that `down` stops with the identical in-process teardown. By default ports are random so several topologies coexist; `--fixed` pins canonical container ports for external tools. All the verbs accept `--profile` and `--manifest`. The full walkthrough is in [Topologies](../writing-tests/topologies.md); the flag-by-flag reference in the [CLI reference](../reference/cli.md#topology-verbs-up-watch-start-down-ps).

## Flags

### `--profile`, `-p`

Select a `[profiles.<name>]` overlay from the manifest. Naming a profile that doesn't exist is an error (exit `2`). Only meaningful for manifest-driven runs — explicit paths ignore the manifest, profile included.

```shell
prova --profile ci
prova -p smoke
```

### `--manifest`

Use a specific manifest file instead of `./prova.toml`:

```shell
prova --manifest configs/acceptance.toml --profile dev
```

### `--format` (and `--json`), `--junit`

Choose the output format: `console` (human-readable, the default), `json` (a JSONL event stream for machines), or `tap` (Test Anything Protocol). `--json` is shorthand for `--format json`, and `--format=json` works too. `--junit PATH` additionally writes a JUnit XML report to a file, composing with whatever `--format` prints — console for the human, `results.xml` for the CI dashboard, one run.

```shell
prova tests --format json
prova tests --json                # same thing
prova tests --format tap
prova tests --junit results.xml   # console to stdout + JUnit XML to the file
```

All the formats are covered in detail in [CI & Output](./ci-and-output.md).

### `--jobs`, `-j`

Run up to N suites concurrently. Concurrency in Prova is **throughput only — it never changes what your tests mean**: a flow stays serial at `--jobs 100`, and declared resources and dependencies are respected at any level of parallelism (see [Dependencies & Scheduling](../writing-tests/dependencies-and-scheduling.md)).

```shell
prova tests --jobs 8
prova tests -j 8
```

The value must be a positive integer; anything else is a usage error. The default is `1`.

### `--plugin`, `-P`

Register an ad-hoc [plugin](/docs/plugins/) for this run — `name=source`, repeatable, layered over the manifest (a `--plugin` entry overrides a manifest plugin of the same name). The source is anything `[plugins]` accepts: a local path, a git URL, or the `org/repo@ref` shorthand.

```shell
prova --plugin redis=acme/prova-redis@v1
prova -P postgres=../prova-postgres          # a local checkout, for plugin development
```

Plugins a project depends on belong in the manifest's `[plugins]` table, where they are versioned with the tests — the flag is for one-off extras and for developing a plugin against a real suite. See [Using Plugins](/docs/plugins/using-plugins).

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
$ prova tests/orders --list
orders api › creates an order
orders api › rejects an empty cart
checkout flow › add item
checkout flow › pay
```

No fixtures are built and no test bodies execute — this is pure collection, the same discovery a GUI or IDE frontend would use.

## Discovery rules

Given a directory, Prova recursively collects **test files**: any file named `*_test.lua` or `*.test.lua`. Results are sorted, so discovery order is deterministic. A path that is itself a file is taken as-is.

How files group into **suites** matters for parallelism and shared state:

- A directory containing a `suite.lua` becomes **one suite** owning every test file in its entire subtree, with `suite.lua` run first as setup. All of the suite's files share one Lua state, so `Scope.Suite` fixtures are built once and shared across them.
- Every test file *not* under a `suite.lua` directory is its own **singleton suite** — one file, no setup.

`--jobs` parallelizes **across suites**; each suite gets its own Lua state. The zero-config default — no `suite.lua` anywhere — is therefore exactly per-file parallelism. See [Suites & Shared State](../writing-tests/suites-and-shared-state.md) for the authoring side of this.

:::tip
`suite.lua` is the zero-config way to group; the manifest's `[suites.<name>]` tables cover grouping that doesn't match your directory tree. Both are described in [Manifest & Profiles](./manifest-and-profiles.md).
:::

If discovery finds no test files at all, Prova reports it and exits with code `2`:

```text
prova: no test files found (looked for *_test.lua / *.test.lua)
```

## Exit codes

| Code | Meaning |
|---|---|
| `0` | Run completed and every test passed (skips don't fail a run) |
| `1` | Run completed with at least one test failure |
| `2` | Usage or environment error — unknown flag, bad `--jobs` value, unreadable manifest, unknown profile, no tests found, or a runner error |

This is the contract CI relies on: gate on the exit code, parse the output only when you want detail.

## For plugin authors: `prova plugin lint`

`prova plugin lint <file>...` checks plugin files against the namespacing grammar and nudges you to ship the `---@meta` stub that gives consumers editor completion. It belongs to the plugin-authoring workflow — see [Authoring Plugins](/docs/plugins/authoring-plugins).

The full flag-by-flag reference lives at [CLI Reference](../reference/cli.md).
