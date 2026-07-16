---
sidebar_position: 5
sidebar_label: "Plugins"
---

# Plugins

Prova's core stays deliberately small: a test runner, the `prova` DSL, and a set of [built-in modules](../reference/modules/index.md) — `fs`, `shell`, `http`, `grpc`, `graphql`, `docker`, `sqlite`, `yaml`. Everything that speaks a specific *technology* — Postgres, MySQL, Redis, Kafka, Pulsar, RabbitMQ, S3, and anything else you can put in a container — is a **plugin**: a pure-Lua module fetched from a git repo or a local path, declared in `prova.toml`, and attached to your tests with a plain `require()`.

## Why plugins

Bundling a native client for every database and broker would bloat the binary, privilege some technologies over others, and chain Prova's release cycle to a dozen driver ecosystems. Plugins invert that:

- **Zero native dependencies.** A plugin is Lua all the way down. It provisions an ephemeral container with [`prova.containerized`](./authoring-plugins.md#provacontainerized) and drives the CLI *already inside the image* via `container:run` — `psql` for Postgres, `redis-cli` for Redis, `mc` for MinIO. No driver to compile, nothing to install.
- **Core stays domain-agnostic.** Prova ships the primitives (Docker, shell, HTTP, parsing helpers); plugins ship the domain knowledge (readiness quirks, connection URLs, client verbs). Adding a technology never requires a new Prova release.
- **The same grammar everywhere.** Every plugin's `X.container(ctx, opts?)` returns the same standard resource shape — `{ client, url, container, host, port }` — so once you've used one, you've used them all.

## How a plugin arrives

Three steps, no package manager:

```toml
# prova.toml
[plugins]
postgres = "prova-rs/prova-postgres@main"
```

```lua
-- tests/orders_test.lua
local postgres = require("postgres")

local db = prova.fixture("db", Scope.File, function(ctx)
  return postgres.container(ctx, { database = "orders" })
end)
```

```
$ prova
```

Prova fetches the repo into a local cache (pinned by ref, reused across runs), resolves the module's entry file from its `prova-plugin.toml`, and makes it available under the name you chose — `require("postgres")` returns the plugin's namespace table. It also syncs the plugin's LuaCATS annotations so the client's methods autocomplete in your editor.

## Learning path

1. **[Using Plugins](./using-plugins.md)** — the `[plugins]` schema in `prova.toml`, every source form (local path, git URL, `owner/repo@ref` shorthand, `[sources]` aliases), the `--plugin` flag, caching and pinning, and IDE integration.
2. **[Authoring Plugins](./authoring-plugins.md)** — build your own: the `prova.containerized` spec, the `container:run` + `prova.parse` toolkit, the `prova-plugin.toml` manifest, repo anatomy, and the `prova-plugin-archetype` generator — walked through the real Postgres plugin.
3. **[Official Plugins](./official-plugins.md)** — the `prova-rs` catalog: Postgres, MySQL, Redis, Kafka, Pulsar, RabbitMQ, and S3/MinIO.
