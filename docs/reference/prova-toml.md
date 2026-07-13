---
sidebar_position: 2
sidebar_label: "prova.toml"
---

# prova.toml Reference

The suite manifest. Place a `prova.toml` at your repository root and `prova` with
no arguments runs the configured suite — CI is just `prova`. The manifest has
three table kinds: `[run]` (the default profile), `[profiles.<name>]` (overlays
selected with `--profile`), and `[suites.<name>]` (explicitly-declared suites).

All tables and keys are optional, but a resolved run must yield at least one path
or one suite, or `prova` exits `2`.

## `[run]` — the default profile

| Key | Type | Default | Description |
|---|---|---|---|
| `paths` | array of strings | `[]` | Files/directories to discover (`*_test.lua` / `*.test.lua`). |
| `jobs` | integer | `1` | Maximum units run concurrently. Throughput only — never changes test semantics. |
| `format` | string | `"console"` | Output format: `"console"` or `"json"`. Any other value is an error (exit `2`). |
| `env` | table of string → string | `{}` | Environment variables set for the whole run, applied to the process before any test executes. Written as a `[run.env]` sub-table. |

## `[profiles.<name>]` — overlays

Each profile accepts exactly the same keys as `[run]` (`paths`, `jobs`, `format`,
`env`). Selecting one with `prova --profile <name>` overlays it on `[run]`:

- `paths` — the profile's `paths` **replace** the base paths, but only if the
  profile's list is non-empty; an absent or empty `paths` inherits the base.
- `jobs`, `format` — taken from the profile when present, otherwise from `[run]`.
- `env` — **merged** key-by-key: base entries first, then the profile's entries;
  on a key collision the profile wins.
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
