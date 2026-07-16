---
sidebar_position: 1
---

# The Command Line

The `prova` binary is one run command plus two small subcommands (`init` to scaffold a project, `plugin lint` for plugin authors). Give the run command paths and it runs them; give it nothing and it runs the suite declared in `prova.toml`. Every flag composes with either mode, and command-line flags always win over manifest values.

```text
usage:
  prova <file-or-dir>...    run the given files/dirs
  prova                     run the suite declared in prova.toml (found by walking up)
  prova init                scaffold prova.toml + LuaLS IDE support in this project
  prova plugin lint <f>...  check plugin files against the namespacing grammar

options:
  -p, --profile NAME        run a profile from the manifest
      --manifest PATH       use a specific manifest (default ./prova.toml)
      --format console|json output format (--json is shorthand)
  -j, --jobs N              run up to N units concurrently
  -P, --plugin name=source  add an ad-hoc plugin (repeatable; layers over the manifest)
      --list                discover tests without running them
  -V, --version             print version
  -h, --help                print this help
```

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

:::note Planned
A `prova test` subcommand form, name/tag filtering (`-k`, `--tags`), and `--shuffle` are on the [roadmap](../reference/roadmap.md) — today the way to run a subset is to pass narrower paths or define a manifest profile with different `paths`.
:::

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

### `--format` (and `--json`)

Choose the output format: `console` (human-readable, the default) or `json` (a JSONL event stream for machines). `--json` is shorthand for `--format json`, and `--format=json` works too.

```shell
prova tests --format json
prova tests --json                # same thing
```

Both formats are covered in detail in [CI & Output](./ci-and-output.md).

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
