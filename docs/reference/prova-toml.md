---
sidebar_position: 2
sidebar_label: "prova.toml"
---

# prova.toml Reference

The suite manifest. Place a `prova.toml` at your repository root and `prova` with
no arguments runs the configured suite — CI is just `prova`. Its tables:
`[run]` (the default profile), `[profiles.<name>]` (overlays selected with
`--profile`), `[requires]` (the prova version this package needs),
`[suites.<name>]` (explicitly-declared suites), `[plugins]` (+ `[sources]`) for
external plugins, `[topologies]`, `[updates]`, `[luals]` for IDE integration, and
`[agent]`.

One file, whichever hats it declares — there is no separate plugin manifest. A
package that also exports a namespace adds `[plugin]`; see
[Authoring Plugins](../plugins/authoring-plugins.md).

All tables and keys are optional, but a resolved run must yield at least one path
or one suite, or `prova` exits `2`.

## `[run]` — the default profile

| Key | Type | Default | Description |
|---|---|---|---|
| `proofs` | array of strings | `[]` | Directory-name patterns holding the proof suites to discover (`*_test.lua` / `*.test.lua`). This is the key `prova init` writes. |
| `config` | string | — | The runtime companion (`prova.lua` / `.prova/config.lua`) where [custom capabilities](../writing-tests/dependencies-and-scheduling.md#custom-capabilities-the-provalua-companion) are registered. |
| `plugin_root` | string | — | Directory of this project's own plugins; each child directory is reachable as `require("<dir>")`. |
| `jobs` | integer | `1` | Maximum units run concurrently. Throughput only — never changes test semantics. |
| `format` | string | `"console"` | Output format: `"console"`, `"json"`, or `"tap"`. Any other value is an error (exit `2`). |
| `color` | string | `"auto"` | Console color: `"auto"` (TTY only, honors `NO_COLOR`), `"always"`, or `"never"`. CLI `--color` wins. |
| `progress` | string | `"auto"` | Narrate blocking pauses on stderr so a long run never looks hung: `"auto"`, `"always"`, `"never"`. |
| `quiet` | boolean | `false` | Print only failures, the recap, and the summary. CLI `--quiet` wins (it can only enable). |
| `github` | string | `"auto"` | GitHub Actions annotations + step summary: `"auto"` (on exactly when `GITHUB_ACTIONS=true`), `"on"`, `"off"`. CLI `--gha` and `PROVA_GHA` win. |
| `junit` | string | — | Also write a JUnit XML report to this home-relative path — the manifest form of `--junit`, so a CI profile needs no extra flag. |
| `env` | table of string → string | `{}` | Environment variables set for the whole run, applied to the process before any test executes. Written as a `[run.env]` sub-table. |
| `globals` | table | — | Injection knobs for the bundled namespaces. See [below](#globals). |
| `must_run` | array of strings | `[]` | Capabilities this run **guarantees**; an unmet one **fails** the run up front. See [below](#must_run). |

### `must_run`

`must_run` is the inverse of a test's [`requires`](../writing-tests/dependencies-and-scheduling.md#capability-gating-requires). Where `requires` **skips** a unit whose capability is absent, `must_run` **fails the whole run** — before anything executes — if a guaranteed capability is missing. It stops a green "0 failed" from hiding "everything skipped" (a CI box that lost its Docker daemon, say).

```toml
[run]
must_run = ["docker"]

[profiles.ci]
must_run = ["docker", "dotnet >= 9"]   # unmet → FAIL, never skip
```

- **Same grammar as `requires`** — a name, optionally with a semver constraint (`"dotnet >= 9"`, `"unix"`), resolved by the same probes. No capability is privileged; `must_run = ["kubectl"]` means kubectl on `PATH`.
- **Checked as a precondition** (fail-fast), reporting the probe's own answer, e.g. `profile 'ci' guarantees capability 'docker', which is unavailable`.
- **Additive across `[run]` and the selected profile** — the sets are **unioned**, so a laxer profile can never silence a stricter guarantee. A `must_run` naming an unregistered/typo'd capability still fails (a guarantee that can't be honored).
- Custom capabilities registered in [`prova.lua`](../writing-tests/dependencies-and-scheduling.md#custom-capabilities-the-provalua-companion) work here too.

:::note Empty selection is also a failure
Related to the same "silent green" hazard: a selection that matches nothing (`-k thisdoesnotexist`) exits non-zero rather than reporting `0 passed`. Opt out with `--allow-empty`.
:::

### `globals`

Every bundled namespace — `fs`, `shell`, `http`, `json` and the rest — is injected as an ambient
global, so a proof reads without a preamble of imports. `[run] globals` is the knob for teams that
would rather be explicit:

```toml
[run.globals]
exclude = ["fs", "shell"]
```

An excluded name is no longer injected; reach it with `require` under whatever local name you like:

```lua
local fs = require("fs")        -- or `local files = require("fs")`
```

**Excluding is an injection choice, never a capability loss.** Nothing becomes unavailable — the
same module, same functions, just named by you at the top of the file instead of appearing from
nowhere. Useful when a house style forbids ambient globals, or when a project has its own `fs` and
wants the name back.

## `[requires]` — the version this package needs

```toml
[requires]
prova = ">= 0.13"
```

Declares the minimum prova a suite needs, so an out-of-date binary says so **up front** instead of
failing somewhere in the middle with whatever symptom the missing feature happens to produce.

**Write `>=`.** The value is a semver *range*, and a bare `"0.13"` means `^0.13`, which on 0.x is
`>=0.13.0, <0.14.0` — a wall that refuses the very upgrades a suite should keep working across.
`>= 0.13` is how you say "this version or newer".

Read **before** the rest of the manifest is validated, from generic TOML. That ordering is what
lets it work at all: `[run]` and friends reject unknown keys, so a manifest written for a newer
prova would otherwise fail on a key this binary has never heard of — and "unknown field" is the
wrong diagnosis for an out-of-date binary. Two consequences worth knowing: `[requires]` must never
change shape, and the version must stay parseable by every future binary, because the binary that
needs to read it is by definition the old one.

The same key also declares a **plugin's** compatibility range (see
[Using Plugins](../plugins/using-plugins.md)), and it means exactly the same thing in both places.
That is not a coincidence to be tidied away later: a `prova.toml` is one file wearing whichever
hats it declares, and `prova init plugin` scaffolds a plugin that carries its own proof suite — so
one `requires.prova` is read once by the package gate and once by the plugin resolver. They must
agree, and a proof holds them to it.

## `[profiles.<name>]` — overlays

Each profile accepts the same keys as `[run]` (`proofs`, `jobs`, `format`, `color`,
`progress`, `quiet`, `github`, `junit`, `env`, `must_run`), plus its own `plugins` table. Selecting one with
`prova --profile <name>` overlays it on `[run]`:

- `proofs` — the profile's **replace** the base's, but only if the
  profile's list is non-empty; an absent or empty list inherits the base.
- `jobs`, `format` — taken from the profile when present, otherwise from `[run]`.
- `env` — **merged** key-by-key: base entries first, then the profile's entries;
  on a key collision the profile wins.
- `must_run` — **unioned** with the base: the profile's guarantees are *added* to
  `[run]`'s, never subtracted (a guarantee is additive by design).
- `plugins` — `[profiles.<name>.plugins]` entries are **overlaid** on the
  project-wide `[plugins]` set: the base plugins all remain available, the
  profile adds its own, and a same-named entry from the profile wins. See
  [below](#profile-scoped-plugins).
- Naming a profile that does not exist is an error (exit `2`).

## `[suites.<name>]` — explicit suites

Declares a named suite whose files load into **one Lua state**, so `Scope.Suite`
fixtures are built once and shared across them. Use it when the grouping does not
match the directory tree; a directory's own `suite.lua` is the zero-config
alternative (see [CLI discovery rules](./cli.md#discovery-rules)).

| Key | Type | Default | Description |
|---|---|---|---|
| `paths` | array of strings | `[]` | Files/directories whose discovered test files form the suite. **`paths`, not `proofs`** — the two mean different things (literal paths here; directory-*name* patterns in `[run]`), and writing `proofs` in a suite is an error. |
| `setup` | string | — | Optional setup file (a `suite.lua`) loaded first; where suite-scoped fixtures and `suite.config{...}` live. |

Declared suites run **in addition to** the resolved `proofs`, and are not affected
by profile overlays. Capability gating and environment belong in the setup file
(`suite.config{ requires = ... }`) and `[run.env]`, not in the suite declaration.

## `[plugins]` — external plugins

Maps each name `require()` will resolve in test files to a **plugin source** — a
local path or a git repo. The project-wide `[plugins]` set applies to every run;
a profile can layer additional (or overriding) entries on top with
`[profiles.<name>.plugins]` (see below).

```toml
[plugins]
greet    = "./plugins/greet.lua"                           # local path shorthand
postgres = "prova-rs/prova-postgres@v1.0.0"                # org/repo@ref → GitHub (@ref required)
redis    = "github:acme/prova-redis@v1"                    # host-prefix shorthand
rabbitmq = { git = "https://github.com/acme/prova-rabbitmq", tag = "v1.0.0" }
nats     = { git = "https://github.com/acme/prova-nats", rev = "abc123", module = "src/nats.lua" }
```

The detailed table form takes exactly one of `path` / `git`, an optional pin
(`tag` / `branch` / `rev`), and an optional in-repo `module` path. Git sources
are fetched into a local cache keyed by URL + ref and reused across runs; pin
tags for reproducibility. `--plugin`/`-P name=source` adds an ad-hoc plugin on
top of (and overriding) the manifest's set.

A companion `[sources]` table registers aliases for shorthands
(`acme = "github:acme"` makes `"acme:prova-redis@v1"` a valid source), and
`[luals]` controls whether prova manages the project's `.luarc.json` pointer for
editor completion (`manage = "auto" | "always" | "never"`, default `"auto"`).

Every source form, resolution rule, and the caching/pinning semantics are
documented in [Using Plugins](../plugins/using-plugins.md).

## Profile-scoped plugins

A `[profiles.<name>.plugins]` table declares plugins of the profile's own,
overlaid on the project-wide `[plugins]` set when the profile is selected. This is the principled home for CI-only or
nightly-only capabilities: the plugin is still declared in `prova.toml` — pinned
in-repo, versioned with the tests — instead of injected as an out-of-band
`--plugin` flag in a workflow file.

```toml
[plugins]
redis = "prova-rs/prova-redis@v1"

[profiles.ci]
[profiles.ci.plugins]
kafka = "acme/prova-kafka@v2"           # only resolved under --profile ci
redis = "./plugins/redis-ci.lua"        # overrides the project-wide entry under ci
```

The overlay is per-entry: base plugins remain available under the profile, the
profile's entries are added, and a same-named profile entry **wins** over the
base. Values take every source form `[plugins]` accepts. `--plugin`/`-P` still
layers over the fully resolved (base + profile) set.

## `[topologies]` — environments addressable by name

Names an environment a plugin can stand up, so `prova up <name>` (and any proof) can reach it.
Sugar for `prova.topology(<name>, require(<plugin>).<factory>)` — a property of the package, not a
profile.

```toml
[topologies]
vm = { plugin = "parallels", topology = "vm", options = { image = "ubuntu-24.04" } }
```

| Key | Type | Default | Description |
|---|---|---|---|
| `plugin` | string | *required* | The plugin providing it — a name from `[plugins]`, or an ambient plugin under `plugin_root`. |
| `topology` | string | — | The plugin's **advertised** topology name (`[[plugin.topologies]]`). Mutually exclusive with `factory`. |
| `factory` | string | — | A dotted path to a factory inside the plugin's namespace, when it advertises none. Mutually exclusive with `topology`. |
| `requires` | array of strings | `[]` | Capabilities the environment needs, added to whatever the plugin's advertisement declares. Unmet blocks `prova up` **before** provisioning. |
| `options` | table | `{}` | Passed to the factory as `require("<plugin>").<factory>(ctx, <options>)` — what the factory needs and the caller cannot otherwise supply. Absent → registered bare. |

Exactly one of `topology` / `factory` must be present. Because `requires` is checked before
anything is provisioned, a machine without the capability **skips cleanly** rather than failing
half-way through a stand-up.

## `[updates]` — freshness policy for git plugin sources

Governs the shared cache's gate for `[plugins]` git sources: inside `interval` the cache is used
with no network at all; past it, a cheap `ls-remote` decides whether a pull is actually needed.
Mirrors archetect's `updates` config, so the sibling tools read the same knobs.

| Key | Type | Default | Description |
|---|---|---|---|
| `interval` | duration string | `1d` | How long a cached source is trusted without checking. `"1d"`, `"12h"`, `"30m"`, `"3600s"`, or a bare integer (seconds). |
| `force` | boolean | `false` | Ignore the freshness gates entirely. The CLI `-U` / `--update` also sets this. |
| `retention` | duration string | `90d` | How long an unused materialized source tree survives before the quiet prune reaps it. |

`--offline` is the opposite end: never fetch, use only what is already cached.

## `context` — project docs an agent can discover

A top-level array of markdown/text files surfaced by [`prova learn`](../running-prova/command-line.md)
as `ctx:<stem>` topics, so a team's own doctrine rides the same discovery rail as prova's built-in
ones — an agent finds it by listing topics rather than by being told a path.

```toml
context = ["docs/agent.md", "~/team/conventions.md"]
```

Paths are home-relative and `~/` expands. A property of the package, not a profile. A declared file
that does not exist is **reported loudly** by `learn` rather than silently skipped — a context doc
nobody notices has gone missing is worse than none.

Note it is a top-level key. Putting `context` inside `[run]` is an error rather than a
silently-ignored setting, which it used to be before `[run]` became strict.

## `[agent]` — how `prova learn` addresses an agent

| Key | Type | Default | Description |
|---|---|---|---|
| `spec_first` | boolean | `true` | Whether `prova learn project` nudges spec-first PDD — author behaviour as `spec`-flagged proofs, then burn them down. Set `false` for a package not run that way. |

It is a one-line inclination in `learn`, never a gate: turning it off changes what an agent is
*told*, not what prova enforces.

## `[luals]` — editor integration policy

Controls whether prova manages the project's `.luarc.json` pointer for LuaLS completion.

| Key | Type | Default | Description |
|---|---|---|---|
| `manage` | string | `"auto"` | `"auto"` — create if absent, else reconcile prova's entries quietly and non-destructively (user keys untouched, identical content never rewritten, so the steady state is silent); a file prova cannot parse as plain JSON is left alone with a hint. `"always"` — same reconcile, but an unmergeable file is an error, for the explicit `prova ide setup` ask. `"never"` — install annotations, never touch the pointer. |

`.luarc.json` holds machine-local absolute paths, so it usually belongs in `.gitignore`. Set
`manage = "never"` when the file is deliberately committed and hand-maintained.

## Complete annotated example

```toml
[run]                       # the default profile (`prova` with no --profile)
proofs = ["proofs"]         # directory patterns to discover (*_test.lua / *.test.lua)
jobs   = 4                  # concurrency — throughput only
format = "console"          # "console" (human) | "json" (JSONL event protocol)

[run.env]                   # environment for the whole run
LOG_LEVEL = "info"

# `prova --profile ci`: inherits proofs/format, overrides jobs, merges env.
[profiles.ci]
jobs   = 8
format = "json"
[profiles.ci.env]
CI = "true"

# A fast subset for the inner loop: `prova --profile smoke`.
[profiles.smoke]
proofs = ["tests/smoke"]

# The same suite pointed at a live dev cluster: `prova --profile dev`.
[profiles.dev]
proofs = ["tests/acceptance"]
[profiles.dev.env]
TARGET_BASE_URL = "https://orders.dev.example.com"

# An explicit suite: these files share one Lua state (Scope.Suite fixtures).
[suites.grpc]
paths = ["services/grpc"]
setup = "services/grpc/suite.lua"

# External plugins: `require("postgres")` in any test file resolves to this source.
[plugins]
postgres = "prova-rs/prova-postgres@main"
```

## Resolution order

How the manifest, `--profile`, `--manifest`, and CLI arguments interact:

1. **Explicit path arguments bypass the manifest entirely.**
   `prova tests/foo_test.lua` never reads `prova.toml` — no profiles, no
   `[run.env]`, no declared suites.
2. Otherwise Prova reads `./prova.toml`, or the file named by `--manifest`.
   An unreadable manifest is an error when `--manifest` or `--profile` was given;
   with neither, `prova` prints usage instead. Both exit `2`.
3. `--profile <name>` overlays `[profiles.<name>]` on `[run]` as described above.
4. The resolved `env` is applied to the process environment.
5. **CLI flags win last**: `--jobs` and `--format` override the resolved
   `jobs`/`format`.
