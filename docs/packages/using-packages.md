---
sidebar_position: 1
---

# Using Packages

Packages are declared once, in `prova.toml`, and attached in test files with `require()`. The dependency set is a property of the *project*: `[dependencies]` applies to every run, and a profile can layer additional entries on top with `[profiles.<name>.dependencies]`.

## `[dependencies]` in prova.toml

Each key under `[dependencies]` is the name `require()` will resolve; each value is a **source** — where the package's Lua comes from. A source is either a string shorthand or a detailed table.

```toml
[dependencies]
# String shorthands
greet    = "./packages/greet.lua"                                  # local file
fixtures = "./test-support"                                        # local dir (init.lua)
postgres = "prova-rs/prova-postgres@v1"                            # GitHub org/repo at a ref
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
| Local path | `"./packages/greet.lua"`, `"greet.lua"`, `"/abs/x.lua"` | A `.lua` file or a directory, relative to the manifest's directory |
| Git URL | `"https://github.com/acme/prova-redis.git"`, `"git@github.com:acme/prova-redis.git"` | The repo's default branch |
| Git URL `@ref` | `"https://github.com/acme/prova-redis@v1.2"` | The repo at tag/branch `v1.2` |
| Host prefix | `"github:acme/prova-redis@v1"`, `"gl:acme/prova-redis"` | Built-in hosts: `github`/`gh` → github.com, `gitlab`/`gl` → gitlab.com |
| `owner/repo@ref` | `"prova-rs/prova-postgres@v1"` | `https://github.com/owner/repo` at that ref |
| `[sources]` alias | `"acme:prova-redis@v1"` | The alias's base URL + repo (see below) |

Two rules keep the classification unsurprising:

- The bare **`owner/repo` form requires an `@ref`**. Without one, `test-support/redis` is a plain relative path — a string that looks like a directory is never a surprise network fetch.
- The **`@ref` splits only after the last `/`**, so `git@github.com:...` scp-style URLs keep their early `@`.

The `@ref` accepts **either a tag or a branch**. To pin an exact commit, use the table form with `rev`.

### The detailed table form

Exactly one of `path` / `git` is expected:

| Key | Type | Description |
|---|---|---|
| `path` | string | A local path to a `.lua` file or a directory. |
| `git` | string | A git repository URL. |
| `tag` | string | Pin to a tag (shallow-cloned). |
| `branch` | string | Pin to a branch (shallow-cloned). |
| `rev` | string | Pin to a specific commit (full clone, then checkout). |
| `module` | string | Path within the repo/dir to the entry file. Overrides the package's own manifest; defaults to the package's `[package] entry`, then `init.lua`, then `<name>.lua`. |

### `[sources]` — registered aliases

Alias a host+org (or any base URL) once, then write short sources against it:

```toml
[sources]
acme   = "github:acme"                    # a host:org shorthand
mirror = "https://git.acme.io/packages"   # or a full base URL

[dependencies]
redis = "acme:prova-redis@v1"             # → https://github.com/acme/prova-redis @ v1
queue = "mirror:prova-queue"              # → https://git.acme.io/packages/prova-queue
```

## Finding packages — the registry

Before hand-writing a capability, search. A **registry** is a git repository of one TOML entry per package — no server, no API. Every `prova` binary knows [prova-rs/package-registry](https://github.com/prova-rs/package-registry) as its built-in default; add your org's own under `[[registries]]` in `~/.config/prova/config.toml`.

```bash
prova packages                    # list everything the configured registries serve
prova packages postgres           # search (name, description, capabilities)
prova packages info postgres      # one entry, full detail
prova packages add postgres       # pin into [dependencies] — then require("postgres") works
```

Discovery-only, by design: `require` never resolves through a registry. `add` writes an ordinary pinned `[dependencies]` entry into your manifest (at the entry's recommended `latest` tag unless you say `add <name>@ref`); from that moment the registry is out of the picture, and a fresh checkout reproduces your run with zero registries configured.

## Profile-scoped dependencies

A `[profiles.<name>.dependencies]` table declares packages of the profile's own, overlaid on the project-wide `[dependencies]` set when that profile is selected:

```toml
[dependencies]
redis = "prova-rs/prova-redis@v1"

[profiles.nightly]
[profiles.nightly.dependencies]
loadtest = "acme/prova-loadtest@v2"     # only resolved under --profile nightly
```

Base dependencies remain available under the profile; the profile adds its entries, and a same-named profile entry overrides the base one. This is the principled home for CI-only or nightly-only capabilities — the package stays declared in `prova.toml`, pinned and versioned with the tests, so a `--profile ci` run and local dev resolve the same source instead of a workflow file injecting it out-of-band. Reach for the `-P/--package` flag (below) only when the package is a fact about a single invocation.

## `require()` semantics

`require(name)` — where `name` is the key you chose under `[dependencies]` — loads the package's entry file and returns whatever it `return`s (by convention a namespace table like `{ client = ..., container = ... }`).

- **Entry file resolution** (for a directory or repo source), in precedence order: the consumer's `module =` override → the package's `[package] entry` → `init.lua` → `<name>.lua`. Published packages declare their entry in their manifest, so resolution never depends on the alias you picked.
- **Your alias is yours.** `mq = "prova-rs/prova-rabbitmq@v1"` makes `require("mq")` work; the package's *canonical* name (from its manifest) namespaces its own internal `require`s, independent of your alias.
- **Compatibility is checked at resolve time.** A package's `[requires] prova = ">= 0.17"` range must admit the running Prova version; an incompatible package fails the run with a clear message naming it.
- **Dependencies can have dependencies.** A package's own `[dependencies]` resolve transitively and stay private to it — you declare only what *you* `require()`, and there is no version bleed between packages.

```lua
local postgres = require("postgres")

local db = prova.fixture("db", Scope.File, function(ctx)
  return postgres.container(ctx, { database = "orders" })   -- { client, url, container, host, port }
end)
```

## Where packages live

Nearest first — the same code graduates outward as it becomes shared:

| Stage | Where |
|---|---|
| Package-local (this repo only) | a directory under `[run] packages` (e.g. `.prova/packages/lib/`) — requirable by name with **zero declaration**; `prova init package` inside a project scaffolds one |
| A local file or dir while incubating | `[dependencies] name = "./packages/name.lua"` or `{ path = "./test-support" }` |
| Shared, pinned | its own repo — consumers declare `[dependencies] name = "owner/repo@ref"` |

## `-P` / `--package` — ad-hoc attachment

Attach a package for one run without touching the manifest:

```bash
prova -P postgres=prova-rs/prova-postgres@v1
prova --package greet=./packages/greet.lua --package mq=acme:prova-rabbitmq@v1
```

`-P name=source` is repeatable and accepts every source form the manifest does. Ad-hoc packages **layer over** the manifest's `[dependencies]`: a CLI entry with the same name overrides the declared one (useful for testing a local checkout of a package your suite normally pins from git). Local paths given on the CLI resolve relative to the current directory.

## Caching and freshness

Git sources are fetched into Prova's package cache, keyed by URL **and** ref. A checkout that already exists is reused — a repeat run never re-clones.

- `tag` and `rev` pins are **immutable**: the cache entry is correct forever.
- A **branch** ref is re-checked for new commits on the freshness interval declared under `[updates]` (`interval = "1d"` by default). `-U`/`--update` forces a refresh right now; `--offline` never fetches and uses only what is already cached.

**Guidance:** pin **tags** for anything you care about — builds stay reproducible and the cache always agrees with the ref. The [official packages](./official-packages.md) all publish `v1` release tags; pin `@v1`.

## IDE annotations

Nothing is copied into your project. The core stubs (the whole `prova` DSL and built-in module surface) live in Prova's user data directory, and each resolved package's `library/*.lua` LuaCATS stub is referenced **in place, from the cache**: on every run with a manifest, Prova maintains the `workspace.library` list in a single `.luarc.json` at the project root, adding each declared package's `library/` directory as it resolves. Adding a package to `prova.toml` and running `prova` makes `require("postgres")` complete and type-check in your editor with **no editor configuration**; a removed package's entry disappears on the next sync.

The `.luarc.json` *pointer* is policy-gated, via `[luals]` in `prova.toml`:

```toml
[luals]
manage = "auto"    # "auto" (default) | "always" | "never"
```

- `"auto"` — create `.luarc.json` if absent (a non-Lua project, where Prova owns the config); if one already exists (a Lua-native project), leave it alone and print a hint to run `prova ide setup`.
- `"always"` — create-or-merge Prova's keys (`workspace.library`, `runtime.version`) into an existing `.luarc.json`, non-destructively.
- `"never"` — never touch `.luarc.json` (wire the pointer yourself).

`prova init` and `prova ide setup` force-wire the pointer regardless of policy — they are you explicitly asking for IDE support.

## A complete example

The [kitchen-sink reference](https://github.com/prova-rs/reference-kitchen-sink) drives a Rust gRPC producer and a Python REST consumer joined by Pulsar, with each infrastructure dependency a one-line package:

```toml
[run]
proofs = ["proofs"]

[dependencies]
postgres = "prova-rs/prova-postgres@v1"
mysql    = "prova-rs/prova-mysql@v1"
pulsar   = "prova-rs/prova-pulsar@v1"
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
