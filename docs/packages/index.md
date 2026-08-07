---
sidebar_position: 5
sidebar_label: "Packages"
---

# Packages

In Prova, **everything is a package**: your project, the libraries it depends on, the topologies they advertise — one `prova.toml`-rooted shape, worn different ways. The core stays deliberately small: a test runner, the `prova` DSL, and a set of [built-in modules](../reference/modules/index.md) — `fs`, `shell`, `http`, `grpc`, `graphql`, `docker`, `sqlite`, `yaml`, and friends. Everything that speaks a specific *technology* — Postgres, MySQL, Redis, Kafka, Pulsar, RabbitMQ, S3, and anything else you can put in a container — is a **package**: a pure-Lua module fetched from a git repo or a local path, declared in `prova.toml`, and attached to your tests with a plain `require()`.

## Why packages

Bundling a native client for every database and broker would bloat the binary, privilege some technologies over others, and chain Prova's release cycle to a dozen driver ecosystems. Packages invert that:

- **Zero native dependencies.** A resource package is Lua all the way down. It provisions an ephemeral container with [`prova.containerized`](./authoring-packages.md#provacontainerized) and drives the CLI *already inside the image* via `container:run` — `psql` for Postgres, `redis-cli` for Redis, `mc` for MinIO. No driver to compile, nothing to install.
- **Core stays domain-agnostic.** Prova ships the primitives (Docker, shell, HTTP, parsing helpers); packages ship the domain knowledge (readiness quirks, connection URLs, client verbs). Adding a technology never requires a new Prova release.
- **The same grammar everywhere.** Every resource package's `X.container(ctx, opts?)` returns the same standard resource shape — `{ client, url, container, host, port }` — so once you've used one, you've used them all.

## How a package arrives

Three steps, no package manager:

```toml
# prova.toml
[dependencies]
postgres = "prova-rs/prova-postgres@v1"
```

```lua
-- proofs/orders.prova.lua
local postgres = require("postgres")

local db = prova.fixture("db", Scope.File, function(ctx)
  return postgres.container(ctx, { database = "orders" })
end)
```

```
$ prova
```

Prova fetches the repo into a local cache (pinned by ref, reused across runs), resolves the module's entry file from the package's own manifest, and makes it available under the name you chose — `require("postgres")` returns the package's namespace table. It also links the package's LuaCATS annotations so the client's methods autocomplete in your editor.

## Learning path

1. **[Using Packages](./using-packages.md)** — the `[dependencies]` schema in `prova.toml`, every source form (local path, git URL, `owner/repo@ref` shorthand, `[sources]` aliases), searching the registry with `prova packages`, the `-P/--package` flag, caching and freshness, and IDE integration.
2. **[Authoring Packages](./authoring-packages.md)** — build your own: `prova init package`, the dual-role `prova.toml`, the `prova.containerized` spec, the `container:run` + `prova.parse` toolkit, and `prova package lint` — walked through the real Postgres package.
3. **[Official Packages](./official-packages.md)** — the `prova-rs` catalog: Postgres, MySQL, Redis, Kafka, Pulsar, RabbitMQ, S3/MinIO, MongoDB, Vault, kind, Parallels, and xcodebuild.
