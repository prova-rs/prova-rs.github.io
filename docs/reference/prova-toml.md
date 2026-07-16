---
sidebar_position: 2
sidebar_label: "prova.toml"
---

# prova.toml Reference

The suite manifest. Place a `prova.toml` at your repository root and `prova` with
no arguments runs the configured suite — CI is just `prova`. The manifest has
five table kinds: `[run]` (the default profile), `[profiles.<name>]` (overlays
selected with `--profile`), `[suites.<name>]` (explicitly-declared suites),
`[plugins]` (+ `[sources]`) for external plugins, and `[luals]` for IDE
integration.

All tables and keys are optional, but a resolved run must yield at least one path
or one suite, or `prova` exits `2`.

## `[run]` — the default profile

| Key | Type | Default | Description |
|---|---|---|---|
| `paths` | array of strings | `[]` | Files/directories to discover (`*_test.lua` / `*.test.lua`). |
| `jobs` | integer | `1` | Maximum units run concurrently. Throughput only — never changes test semantics. |
| `format` | string | `"console"` | Output format: `"console"`, `"json"`, or `"tap"`. Any other value is an error (exit `2`). |
| `env` | table of string → string | `{}` | Environment variables set for the whole run, applied to the process before any test executes. Written as a `[run.env]` sub-table. |

## `[profiles.<name>]` — overlays

Each profile accepts the same keys as `[run]` (`paths`, `jobs`, `format`,
`env`), plus its own `plugins` table. Selecting one with
`prova --profile <name>` overlays it on `[run]`:

- `paths` — the profile's `paths` **replace** the base paths, but only if the
  profile's list is non-empty; an absent or empty `paths` inherits the base.
- `jobs`, `format` — taken from the profile when present, otherwise from `[run]`.
- `env` — **merged** key-by-key: base entries first, then the profile's entries;
  on a key collision the profile wins.
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
| `paths` | array of strings | `[]` | Files/directories whose discovered test files form the suite. |
| `setup` | string | — | Optional setup file (a `suite.lua`) loaded first; where suite-scoped fixtures and `suite.config{...}` live. |

Declared suites run **in addition to** the resolved `paths`, and are not affected
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

## Complete annotated example

```toml
[run]                       # the default profile (`prova` with no --profile)
paths  = ["tests"]          # files/dirs to discover (*_test.lua / *.test.lua)
jobs   = 4                  # concurrency — throughput only
format = "console"          # "console" (human) | "json" (JSONL event protocol)

[run.env]                   # environment for the whole run
LOG_LEVEL = "info"

# `prova --profile ci`: inherits paths/format, overrides jobs, merges env.
[profiles.ci]
jobs   = 8
format = "json"
[profiles.ci.env]
CI = "true"

# A fast subset for the inner loop: `prova --profile smoke`.
[profiles.smoke]
paths = ["tests/smoke"]

# The same suite pointed at a live dev cluster: `prova --profile dev`.
[profiles.dev]
paths = ["tests/acceptance"]
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
