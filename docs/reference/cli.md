---
sidebar_position: 1
sidebar_label: "CLI"
---

# CLI Reference

Complete reference for the `prova` command-line interface.

## Usage

```text
prova [OPTIONS] [PATHS...]
```

`prova` is a single command with no subcommands. Positional arguments are files or
directories containing test files.

```shell
# Run the suite declared in ./prova.toml
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
```

:::note Planned
Subcommands (`prova test`, `prova ide setup`), name filtering (`-k`), tag
expressions (`--tags`), `--shuffle`, and `--update-snapshots` are not yet
implemented. See the [Roadmap](./roadmap.md).
:::

## Options

All value-taking flags accept both `--flag value` and `--flag=value`.

| Flag | Default | Description |
|---|---|---|
| `-p`, `--profile <NAME>` | — | Overlay the named `[profiles.<NAME>]` from the manifest on `[run]`. Errors if the profile does not exist. |
| `--manifest <PATH>` | `./prova.toml` | Read the manifest from a specific path instead of `./prova.toml`. |
| `--format <console\|json>` | `console` | Output format: human-readable console output, or one JSON object per line on stdout (run/node started/finished events). Any other value is a usage error. |
| `--json` | — | Shorthand for `--format json`. |
| `-j`, `--jobs <N>` | `1` | Run up to `N` units concurrently. Must be a positive integer. Throughput only — never changes test semantics (flows stay serial; declared resources gate co-scheduling). |
| `--list` | — | Discover and print every test/step path (one per line) without executing anything, then exit `0`. |
| `-V`, `--version` | — | Print `prova <version>` and exit `0`. |
| `-h`, `--help` | — | Print usage help and exit `0`. |

## Paths vs. the manifest

- **With positional `PATHS`** — the manifest is bypassed entirely. Only the given
  files/directories run; `--jobs` defaults to `1` and `--format` to `console`
  unless passed explicitly. `[run.env]`, profiles, and `[suites.*]` are all ignored.
- **Without positional `PATHS`** — Prova reads `./prova.toml` (or `--manifest`),
  resolves `[run]` (plus the `--profile` overlay, if any), applies `[run.env]` to
  the process environment, and runs the manifest's `paths` and declared `[suites.*]`.
  If no manifest is readable, `prova` prints usage and exits `2`.
- **CLI flags override manifest values**: `--jobs` and `--format` on the command
  line win over `jobs`/`format` resolved from the manifest.

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
| `0` | The run completed and no test failed (skipped tests do not fail a run). Also used for `--list`, `--version`, and `--help`. |
| `1` | The run completed and at least one test failed. |
| `2` | Usage, configuration, or collection error: unknown flag, invalid `--jobs`/`--format` value, unreadable or invalid manifest, unknown profile, a manifest defining nothing to run, no test files found, or a file that fails to load/collect. |
