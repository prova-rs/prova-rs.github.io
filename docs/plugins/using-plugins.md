---
sidebar_position: 1
---

# Using Plugins

Plugins are declared once, in `prova.toml`, and attached in test files with `require()`. The plugin set is a property of the *project* — it is not profile-specific, and it applies to every run.

## `[plugins]` in prova.toml

Each key under `[plugins]` is the name `require()` will resolve; each value is a **source** — where the plugin's Lua comes from. A source is either a string shorthand or a detailed table.

```toml
[plugins]
# String shorthands
greet    = "./plugins/greet.lua"                                   # local file
fixtures = "./test-support"                                        # local dir (init.lua / fixtures.lua)
postgres = "prova-rs/prova-postgres@v1.0.0"                        # GitHub org/repo at a ref
redis    = "github:acme/prova-redis@v1"                            # explicit host prefix
mq       = "https://github.com/acme/prova-rabbitmq@v2.1"           # full URL with a ref

# Detailed table form
rabbitmq = { git = "https://github.com/acme/prova-rabbitmq", tag = "v1.0.0" }
nats     = { git = "https://github.com/acme/prova-nats", rev = "abc123", module = "src/nats.lua" }
support  = { path = "./test-support" }
```

### String shorthands

A bare string is classified by shape:

| Form | Example | Resolves to |
|---|---|---|
| Local path | `"./plugins/greet.lua"`, `"greet.lua"`, `"/abs/x.lua"` | A `.lua` file or a directory, relative to the manifest's directory |
| Git URL | `"https://github.com/acme/prova-redis.git"`, `"git@github.com:acme/prova-redis.git"` | The repo's default branch |
| Git URL `@ref` | `"https://github.com/acme/prova-redis@v1.2"` | The repo at tag/branch `v1.2` |
| Host prefix | `"github:acme/prova-redis@v1"`, `"gl:acme/prova-redis"` | Built-in hosts: `github`/`gh` → github.com, `gitlab`/`gl` → gitlab.com |
| `owner/repo@ref` | `"prova-rs/prova-postgres@main"` | `https://github.com/owner/repo` at that ref |
| `[sources]` alias | `"acme:prova-redis@v1"` | The alias's base URL + repo (see below) |

Two rules keep the classification unsurprising:

- The bare **`owner/repo` form requires an `@ref`**. Without one, `test-support/redis` is a plain relative path — a string that looks like a directory is never a surprise network fetch.
- The **`@ref` splits only after the last `/`**, so `git@github.com:...` scp-style URLs keep their early `@`.

The `@ref` is passed to `git clone --branch`, which accepts **either a tag or a branch**. To pin an exact commit, use the table form with `rev`.

### The detailed table form

Exactly one of `path` / `git` is expected:

| Key | Type | Description |
|---|---|---|
| `path` | string | A local path to a `.lua` file or a directory. |
| `git` | string | A git repository URL. |
| `tag` | string | Pin to a tag (shallow-cloned). |
| `branch` | string | Pin to a branch (shallow-cloned). |
| `rev` | string | Pin to a specific commit (full clone, then checkout). |
| `module` | string | Path within the repo/dir to the entry file. Overrides the plugin's own manifest; defaults to the plugin's `prova-plugin.toml` `entry`, then `init.lua`, then `<name>.lua`. |

### `[sources]` — registered aliases

Alias a host+org (or any base URL) once, then write short plugin sources against it:

```toml
[sources]
acme   = "github:acme"                    # a host:org shorthand
mirror = "https://git.acme.io/plugins"    # or a full base URL

[plugins]
redis = "acme:prova-redis@v1"             # → https://github.com/acme/prova-redis @ v1
queue = "mirror:prova-queue"              # → https://git.acme.io/plugins/prova-queue
```

## `require()` semantics

`require(name)` — where `name` is the key you chose under `[plugins]` — loads the plugin's entry file and returns whatever it `return`s (by convention a namespace table like `{ client = ..., container = ... }`).

- **Entry file resolution** (for a directory or repo source), in precedence order: the consumer's `module =` override → the plugin's `prova-plugin.toml` `entry` → `init.lua` → `<name>.lua`. Published plugins declare `entry` in their manifest, so resolution never depends on the alias you picked.
- **Your alias is yours.** `mq = "prova-rs/prova-rabbitmq@v1"` makes `require("mq")` work; the plugin's *canonical* name (from its manifest) namespaces its own internal `require`s, independent of your alias.
- **Compatibility is checked at resolve time.** A plugin's `[requires] prova = ">=0.2, <0.3"` range must admit the running Prova version; an incompatible plugin fails the run with a clear message naming the plugin.

```lua
local postgres = require("postgres")

local db = prova.fixture("db", Scope.File, function(ctx)
  return postgres.container(ctx, { database = "orders" })   -- { client, url, container, host, port }
end)
```

## `--plugin` / `-P` — ad-hoc attachment

Attach a plugin for one run without touching the manifest:

```bash
prova -P postgres=prova-rs/prova-postgres@main
prova --plugin greet=./plugins/greet.lua --plugin mq=acme:prova-rabbitmq@v1
```

`-P name=source` is repeatable and accepts every source form the manifest does. Ad-hoc plugins **layer over** the manifest's `[plugins]`: a CLI plugin with the same name overrides the declared one (useful for testing a local checkout of a plugin your suite normally pins from git). Local paths given on the CLI resolve relative to the current directory.

## Caching and pinning

Git sources are fetched by shelling out to `git` into Prova's plugin cache, keyed by URL **and** ref. A checkout that already exists is reused — a repeat run never re-clones.

- `tag` and `rev` pins are immutable: the cache entry is correct forever.
- A **branch** (including `@main`) is cached on first fetch and then reused — it does *not* auto-update on later runs. Clear the cached checkout to pick up new commits.

**Guidance:** pin **tags** for production and CI suites — builds stay reproducible and the cache always agrees with the ref. `@main` tracks the latest at first fetch and is fine for demos and early adoption; the [official plugins](./official-plugins.md) are pinned `@main` today only because their first releases are pending — switch to release tags as soon as they exist.

## IDE annotations

On every run with a manifest, Prova refreshes a prova-owned `annotations/` folder next to `prova.toml`, containing:

- the embedded core stubs (`prova.lua`, `modules.lua`) — the whole `prova` DSL and built-in module surface, and
- each resolved plugin's `library/*.lua` LuaCATS stub, under `annotations/plugins/`.

A single `.luarc.json` at the project root points LuaLS (the Lua language server in VS Code, Neovim, etc.) at that folder — so adding a plugin to `prova.toml` makes `require("postgres")` complete and type-check in your editor with **no editor configuration**. The folder is always refreshed and gitignored in-place (`annotations/.gitignore`); a removed plugin's stub disappears on the next sync.

Only the `.luarc.json` *pointer* is policy-gated, via `[luals]` in `prova.toml`:

```toml
[luals]
manage = "auto"    # "auto" (default) | "always" | "never"
```

- `"auto"` — create `.luarc.json` if absent (a non-Lua project, where Prova owns the config); if one already exists (a Lua-native project), leave it alone and print a hint to run `prova init`.
- `"always"` — create-or-merge Prova's two keys (`workspace.library`, `runtime.version`) into an existing `.luarc.json`, non-destructively.
- `"never"` — never touch `.luarc.json` (the annotations folder still syncs; wire the pointer yourself).

`prova init` force-wires the pointer regardless of policy — it is you explicitly asking for IDE support.

## A complete example

The [kitchen-sink example](https://github.com/prova-rs/prova/tree/main/examples/kitchen-sink) drives a Rust gRPC producer and a Python REST consumer joined by Pulsar, with each infrastructure dependency a one-line plugin:

```toml
[run]
paths = ["."]

[plugins]
postgres = "prova-rs/prova-postgres@main"
mysql    = "prova-rs/prova-mysql@main"
pulsar   = "prova-rs/prova-pulsar@main"
```

```lua
local postgres = require("postgres")
local mysql    = require("mysql")
local pulsar   = require("pulsar")

local infra = prova.fixture("infra", Scope.File, function(ctx)
  return {
    pg     = postgres.container(ctx, { user = "dev", password = "dev", database = "inventory" }),
    mysql  = mysql.container(ctx, { user = "dev", password = "dev", database = "audit" }),
    pulsar = pulsar.container(ctx),
  }
end)
```

Each resource's `url` is handed to the app under test's environment (`DATABASE_URL = env.pg.url`), and each `client` cross-checks state at that tier — see [Multi-Service Systems](../writing-tests/multi-service-systems.md) for the full walkthrough.
