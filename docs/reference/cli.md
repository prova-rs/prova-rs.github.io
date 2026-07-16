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
A `prova test` subcommand, name filtering (`-k`), tag expressions, `--shuffle`,
and `--update-snapshots` are not yet implemented. See the
[Roadmap](./roadmap.md).
:::

## Options

All value-taking flags accept both `--flag value` and `--flag=value`.

| Flag | Default | Description |
|---|---|---|
| `-p`, `--profile <NAME>` | — | Overlay the named `[profiles.<NAME>]` from the manifest on `[run]`. Errors if the profile does not exist. |
| `--manifest <PATH>` | walk-up discovery | Read the manifest from a specific path instead of discovering it (see below). |
| `--format <console\|json>` | `console` | Output format: human-readable console output, or one JSON object per line on stdout (run/node started/finished events). Any other value is a usage error. |
| `--json` | — | Shorthand for `--format json`. |
| `-j`, `--jobs <N>` | `1` | Run up to `N` units concurrently. Must be a positive integer. Throughput only — never changes test semantics (flows stay serial; declared resources gate co-scheduling). |
| `-P`, `--plugin <name=source>` | — | Add an ad-hoc plugin for this run (repeatable). `source` takes the same string forms as a manifest `[plugins]` entry: a local file/dir path, a git URL (with an optional `@ref`), a `github:org/repo@ref` shorthand, or a bare `org/repo@ref`. Layers **over** the manifest — a CLI plugin overrides a manifest plugin of the same name. See [Using plugins](../plugins/using-plugins.md). |
| `--list` | — | Discover and print every test/step path (one per line) without executing anything, then exit `0`. |
| `-V`, `--version` | — | Print `prova <version>` and exit `0`. |
| `-h`, `--help` | — | Print usage help and exit `0`. |

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

## Exit codes

| Code | Meaning |
|---|---|
| `0` | The run completed and no test failed (skipped tests do not fail a run). Also used for `--list`, `--version`, `--help`, a successful `prova init`, and a clean `prova plugin lint`. |
| `1` | The run completed and at least one test failed, or `prova plugin lint` found issues. |
| `2` | Usage, configuration, or collection error: unknown flag, invalid `--jobs`/`--format`/`--plugin` value, unreadable or invalid manifest, ambiguous manifest layout, unknown profile, a plugin that fails to resolve, a manifest defining nothing to run, no test files found, a file that fails to load/collect, or `prova init` in an already-initialized project. |
