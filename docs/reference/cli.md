---
sidebar_position: 1
sidebar_label: "CLI"
---

# CLI Reference

Complete reference for the `prova` command-line interface.

## Usage

```text
prova [OPTIONS] [PATHS...]      run tests (the default command)
prova init [INIT-OPTIONS]       scaffold prova.toml + LuaLS IDE support
prova eval '<code>'             run a one-shot Lua snippet in the full prova environment
prova skill [--install]         print (or install) the embedded agent skill
prova up <topology>             stand up a topology and hold it until Ctrl-C
prova watch <topology>          stand up a topology and re-apply on definition change
prova start <topology>          stand up a topology detached (use `down` to stop)
prova down <topology>           tear down a detached topology
prova ps                        list running topologies
prova plugin lint <FILE>...     check plugin files against the namespacing grammar
```

With no subcommand, positional arguments are files or directories containing
test files.

```shell
# Run the suite declared in prova.toml (found by walking up from the cwd)
prova

# Run specific files/directories (bypasses the manifest entirely)
prova tests/ smoke_test.lua

# Run a manifest profile
prova --profile ci

# Run a subset: keyword, tags, exact node, or last run's failures
prova -k MySQL
prova --tags '!build'
prova --node "orders api › creates an order"
prova --last-failed

# Stream machine-readable JSONL events
prova --format json tests/

# Discover tests without running them
prova --list tests/

# Run up to 4 units concurrently
prova --jobs 4 tests/

# Add an ad-hoc plugin for this run (repeatable; layers over the manifest)
prova --plugin redis=../prova-redis/redis.lua
```

:::note Planned
A `prova test` subcommand and `--shuffle` are not yet implemented. See the
[Roadmap](./roadmap.md).
:::

## Options

All value-taking flags accept both `--flag value` and `--flag=value`.

| Flag | Default | Description |
|---|---|---|
| `-p`, `--profile <NAME>` | — | Overlay the named `[profiles.<NAME>]` from the manifest on `[run]`. Errors if the profile does not exist. |
| `--manifest <PATH>` | walk-up discovery | Read the manifest from a specific path instead of discovering it (see below). |
| `--format <console\|json\|tap>` | `console` | Output format: human-readable console output, one JSON object per line on stdout (run/node started/finished events), or TAP (Test Anything Protocol). Any other value is a usage error. |
| `--json` | — | Shorthand for `--format json`. |
| `--junit <PATH>` | — | Also write a JUnit XML report to `PATH` (for CI dashboards). Composes with any `--format` — the stdout format and the XML file are independent sinks of the same event stream. An unwritable path is a usage error. |
| `-j`, `--jobs <N>` | `1` | Run up to `N` units concurrently. Must be a positive integer. Throughput only — never changes test semantics (flows stay serial; declared resources gate co-scheduling). |
| `-P`, `--plugin <name=source>` | — | Add an ad-hoc plugin for this run (repeatable). `source` takes the same string forms as a manifest `[plugins]` entry: a local file/dir path, a git URL (with an optional `@ref`), a `github:org/repo@ref` shorthand, or a bare `org/repo@ref`. Layers **over** the manifest — a CLI plugin overrides a manifest plugin of the same name. See [Using plugins](../plugins/using-plugins.md). |
| `-k <PATTERN>` | — | Select nodes whose path contains `PATTERN` (case-insensitive substring; repeatable). `!PATTERN` excludes instead. See [Selection semantics](#selection-semantics). |
| `--tags <a,b>` | — | Select nodes carrying any listed tag — their own or inherited from an enclosing group (comma-separated; repeatable). `!tag` excludes. |
| `--node <PATH>` | — | Select an exact node path (repeatable) — re-run precisely the node a report named. |
| `--last-failed` | — | Select only the nodes that failed in the previous run (state kept in `.last-failed.json` in the prova home). With no failure state, prints a note and runs everything. |
| `-u`, `--update-snapshots` | — | (Re)write `.snap` files instead of comparing — accept the current output as the new snapshot. See [Matchers](./lua-api/matchers.md#matches_snapshot). |
| `--unreferenced <ignore\|warn\|delete>` | `ignore` | What to do with `.snap` files no test referenced this run: `warn` lists them and fails the run (exit `1`), `delete` removes them. Sound only on a **full** run — skipped (with a note) when any selection flag is active. |
| `--list` | — | Discover and print every test/step path (one per line) without executing anything, then exit `0`. Respects selection. |
| `-V`, `--version` | — | Print `prova <version>` and exit `0`. |
| `-h`, `--help` | — | Print usage help and exit `0`. |

## Selection semantics

`-k`, `--tags`, `--node`, and `--last-failed` compose into one selection:

- **Includes union, excludes veto.** A node runs if it matches *any* include
  (`-k pat`, `--tags a,b`, `--node path`) and *no* exclude (`-k '!pat'`,
  `--tags '!tag'`). With no includes at all, everything not excluded runs.
- **Dependency-aware.** A selected node's `depends_on` upstreams are pulled into
  the run automatically, so gates still gate.
- **Flow-atomic.** Selecting any step of a flow runs the whole flow — steps are
  never torn out of their sequence.
- **Cheap.** Deselected nodes never provision fixtures; a deselected node is
  reported as *deselected* (counted in the summary), never as skipped.
- Group `tags` are inherited by every node inside the group.

## `prova init`

Scaffold a prova project: a `prova.toml` manifest, its home directory, and
(unless opted out) the LuaLS IDE integration.

```text
prova init                 # home in ./prova/ (visible — tests + config in one dir)
prova init --hidden        # home in ./.prova/ (tucked away)
prova init --flat          # manifest at ./prova.toml (no nesting)
prova init --no-luals      # skip IDE wiring (sets [luals] manage = "never")
```

`init` generates:

- **`prova.toml`** — a starter manifest with `[run] paths = ["."]` (so any
  `*_test.lua` dropped in the home dir just runs) and a commented `[plugins]`
  example.
- **`<home>/annotations/`** — the core LuaCATS `---@meta` stubs, so
  `lua-language-server` completes the injected globals. Each **plugin's** stub is
  added automatically on the first `prova` run that resolves it.
- **`.luarc.json`** at the project root, pointing the editor at the annotations
  — skipped with `--no-luals`, which instead writes `[luals] manage = "never"`
  into the manifest.

`init` **refuses to run** if any of the three manifest locations
(`prova.toml`, `prova/prova.toml`, `.prova/prova.toml`) already exists — it
never clobbers an existing layout. See [IDE setup](../running-prova/ide-setup.md).

## `prova eval`

```text
prova eval '<lua code>' [--format json] [--profile NAME] [--manifest PATH] [-P name=source]
prova eval -            # read the snippet from stdin
```

Run a one-shot Lua snippet in the **full prova environment** — the built-in
modules (`fs`, `shell`, `http`, `docker`, …), manifest-declared plugins via
`require()`, and a real transient `ctx` — then print the returned value and
exit. Anything the snippet provisions through `ctx:manage`/`ctx:defer`/
`ctx:tempdir` is **torn down when it returns**, success or error.

The snippet may be a bare expression (`1 + 1`) or statements with an explicit
`return`. Pass `-` to read the snippet from stdin.

```shell
prova eval 'return 1 + 1'
prova eval 'return fs.exists("Cargo.toml")'
prova eval 'local db = require("postgres").container(ctx); return db.url'
```

Manifest resolution works exactly as on the run path (walk-up discovery,
`--manifest`, `--profile`, `-P/--plugin` layering), so `require("postgres")`
works from a project directory; **without a manifest the snippet still runs**
with just the built-ins.

Output: scalars print plainly (a string without quotes, so the value is
shell-friendly), `nil` prints nothing, and tables/arrays print as pretty JSON.
`--format json` (or `--json`) forces JSON for everything. Exit codes: `0` on
success, `1` if the snippet raises, `2` on usage errors.

## `prova skill`

```text
prova skill              # print the embedded agent skill to stdout
prova skill --install    # write it to .claude/skills/prova/SKILL.md at the project root
```

Print the **agent skill** — a compact document teaching a coding agent how to
drive Prova (the test-file idiom, the resource grammar, topologies, selection,
`eval`). It is embedded in the binary (`include_str!`), so it is versioned with
the features it describes and can never drift. `--install` writes it to
`.claude/skills/prova/SKILL.md` under the project root (found by walking up to
the manifest; the current directory if there is none), so the repo carries it
durably.

## Topology verbs: `up`, `watch`, `start`, `down`, `ps`

The inhabited counterparts of a test run — they stand up a **named topology**
(declared with [`prova.topology`](../writing-tests/topologies.md)) outside any
test. All of them accept `--profile NAME` and `--manifest PATH`, resolving the
manifest and its plugins exactly as a run does.

### `prova up <topology>` — attached

```text
prova up <topology> [--fixed] [--profile NAME] [--manifest PATH]
```

Stand up the named topology, print each resource's endpoint (`name → url`),
and **hold it running until Ctrl-C** (SIGINT or SIGTERM), then run the normal
`ctx:manage` teardown. By default resources get **random host ports**
(parallel-safe — several topologies can be up at once); `--fixed` pins each
resource to its **canonical container port** on the host (postgres on `5432`,
redis on `6379`, …) for a predictable, external-tool-friendly address — only
one fixed instance of a port can run at a time.

A running `up` records itself under `<home>/running/<name>.json` (pid +
endpoints) so `prova ps`/`down` can supervise it, and removes the record on
clean teardown. Standing up a topology whose record is still live is refused;
a stale record (the holder is gone) is cleaned and the command proceeds.

### `prova watch <topology>` — the dev loop

```text
prova watch <topology> [--fixed] [--profile NAME] [--manifest PATH]
```

Like `up`, but **re-provisions whenever the topology's definition files
change** — a live dev loop over the same definition your tests use. Each pass
builds a fresh Lua state so edits take effect; a failed edit is reported and
the loop waits for the fix instead of exiting. Attached-only; pair with
`--fixed` so endpoints stay stable across re-applies.

### `prova start <topology>` — detached

```text
prova start <topology> [--fixed] [--profile NAME] [--manifest PATH]
```

Stand up the topology **detached**: spawns `prova up <topology>` in its own
process group (stdio to `<home>/running/<name>.log`), waits for it to come up
(up to 300s — provisioning can be slow on first image pulls), prints the
endpoints and the holder's pid, and returns, leaving it running. On failure it
prints the log tail.

### `prova down <topology>`

Tear down a detached topology by signalling its holder (SIGTERM), which runs
the same in-process teardown an attached Ctrl-C would — **one provisioning
path, one teardown path**. Waits up to 120s for the holder to exit.
Idempotent: a missing or stale record is not an error.

### `prova ps`

```text
prova ps [--manifest PATH]
```

List this project's running topologies — name, status, pid, uptime, and each
endpoint. Stale records (holder gone) are reported once and cleaned up.

## `prova plugin lint`

```text
prova plugin lint <FILE>...
```

Load each plugin file with the same primitives a run would install and check it
against the plugin namespacing grammar. Prints `ok <file> (resource; facets: …)`
or `ok <file> (library)` per clean file, `FAIL` with the issues otherwise; also
warns (non-fatally) when a plugin ships no `library/<name>.lua` LuaCATS stub.
Exits `0` when every file passes, `1` otherwise. See
[Authoring plugins](../plugins/authoring-plugins.md).

## Paths vs. the manifest

- **With positional `PATHS`** — the manifest is bypassed entirely. Only the
  given files/directories run (relative to the cwd); `--jobs` defaults to `1`
  and `--format` to `console` unless passed explicitly. `[run.env]`, profiles,
  `[suites.*]`, and manifest `[plugins]` are all ignored (`--plugin` still
  applies).
- **Without positional `PATHS`** — Prova finds the manifest by **walking up**
  from the current directory (like git finding `.git`), checking each ancestor
  for one of `prova.toml`, `prova/prova.toml`, or `.prova/prova.toml`. Finding
  more than one in the same directory is an error (ambiguous layout). It then
  resolves `[run]` (plus the `--profile` overlay, if any), applies `[run.env]`
  to the process environment, resolves `[plugins]` (fetching git sources into
  the cache), and runs the manifest's `paths` and declared `[suites.*]` —
  all manifest paths relative to the manifest's directory. If no manifest is
  found, `prova` prints usage and exits `2`. `--manifest PATH` points directly
  at a manifest instead of discovering one.
- **CLI flags override manifest values**: `--jobs` and `--format` on the
  command line win over `jobs`/`format` resolved from the manifest, and
  `--plugin` entries override same-named manifest plugins.

On a manifest run (not `--list`), Prova also refreshes the IDE annotation
folder (core + plugin stubs) and manages `.luarc.json` per `[luals] manage` —
never blocking the run (a sync error is a warning), with all such output on
stderr so `--format json` stdout stays a clean event stream.

See [prova.toml](./prova-toml.md) for the full manifest schema and merge semantics.

## Discovery rules

- Test files match `*_test.lua` or `*.test.lua`. Directories are searched
  recursively.
- A path that names a **file** directly is run as-is, even if its name does not
  match the test-file pattern.
- A directory containing a `suite.lua` becomes **one suite**: `suite.lua` runs
  first as the setup file, and every test file in that directory's subtree loads
  into the same Lua state (sharing `Scope.Suite` fixtures).
- Every other discovered test file is a singleton suite of its own.
- If discovery finds no test files at all, `prova` reports the error and exits `2`.

## `prova mcp`

```shell
prova mcp [--profile NAME] [--manifest PATH] [-P name=source]
```

Serves Prova as an MCP server over stdio, resolved against the prova home exactly like a CLI run. Tools mirror the CLI: `run` (the selection fields — `keywords`, `tags`, `nodes`, `last_failed`, plus `profile`), `list` (same selection), and `eval` (one-shot code). Every tool returns one text content item containing JSON; a failing `run` sets `isError` and carries `failures: [{ path, message }]`. The server's `instructions` field is the embedded [agent skill](#prova-skill) — MCP clients know Prova on connect. Warm topology tools (`up`/`down`/`status`, `run { topology }`) are the next phase.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | The run completed and no test failed (skipped tests do not fail a run). Also used for `--list`, `--version`, `--help`, a successful `prova init`/`eval`/`skill`, a clean `prova plugin lint`, and a cleanly torn-down topology verb. |
| `1` | The run completed and at least one test failed, `--unreferenced warn` found orphaned snapshots, a `prova eval` snippet raised, or `prova plugin lint` found issues. |
| `2` | Usage, configuration, or collection error: unknown flag, invalid `--jobs`/`--format`/`--plugin`/`--unreferenced` value, unreadable or invalid manifest, ambiguous manifest layout, unknown profile, a plugin that fails to resolve, a manifest defining nothing to run, no test files found, a file that fails to load/collect, `prova init` in an already-initialized project, or a topology that fails to provision / is already up. |
