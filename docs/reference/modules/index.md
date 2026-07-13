---
sidebar_position: 4
sidebar_label: "Modules"
---

# Modules

Prova ships a set of first-party capability modules — the tools that bring a system into existence and poke it. They are **injected as globals** into every test file: no `require()` is needed, `shell`, `http`, `docker`, and friends are simply there.

```lua
local r = shell.run("cargo build --release", { check = true })
local res = http.get("http://127.0.0.1:8080/health")
```

Each heavyweight module is behind a **default-on Cargo feature** (`http`, `postgres`, `mysql`, `sqlite`, `docker`, `grpc`, `graphql`, `yaml`, `redis`, `pulsar`, `kafka`, `s3` — feature name = namespace), so custom builds can opt out of a dependency tree; a standard prova binary has all of them. The `archetect` module is a plugin (from the `prova-archetect` crate) wired in by the prova host rather than a core built-in.

## The grammar

Every service namespace has two doors. **`X.client(...)` attaches** to something already running — a URL or address in, a connected client out. **`X.container(ctx, opts?)` provisions** an ephemeral instance via Docker and returns the **standard resource shape** `{ client, url, container, ... }`: `client` is exactly what `X.client()` returns (already managed), `url` is the connection string that reaches the instance — the thing you inject into the app under test's environment — and `container` is the underlying [container handle](docker.md#container). Some resources carry extras (`s3.container` adds `access_key`/`secret_key`). Learn the shape once and every module reads the same.

The network-facing clients are **plaintext-only in v1** — no TLS, no SASL, no token auth. They are aimed at localhost services and ephemeral CI containers, which is exactly what black-box acceptance tests stand up.

| Module | Purpose | Needs | Reference |
|---|---|---|---|
| `fs` | Read, write, glob, and inspect files; temp dirs | — | [fs](fs.md) |
| `shell` | Run commands (`shell.run`) and manage long-running processes (`shell.spawn`) | — | [shell & net](shell.md) |
| `net` | `net.free_port()` — an OS-assigned free TCP port | — | [shell & net](shell.md#net) |
| `http` | HTTP verbs, reusable REST clients, readiness polling | — | [http](http.md) |
| `grpc` | Native dynamic gRPC client via server reflection — no `.proto` files | Reflection-enabled server | [grpc](grpc.md) |
| `graphql` | GraphQL queries/mutations over HTTP POST | — | [graphql](graphql.md) |
| `docker` | Ephemeral containers (testcontainers-style) with readiness gates | Docker daemon | [docker](docker.md) |
| `postgres` / `mysql` / `sqlite` | One SQL API over all three engines, plus `postgres.container`/`mysql.container` recipes | Docker daemon for the container recipes | [Postgres, MySQL & SQLite](databases.md) |
| `redis` | Thin cache client + `redis.container` recipe | Docker daemon for `redis.container` | [redis](redis.md) |
| `kafka` | Produce/consume + `kafka.container` recipe | Docker daemon for `kafka.container` | [Kafka & Pulsar](messaging.md) |
| `pulsar` | Produce/consume + `pulsar.container` recipe | Docker daemon for `pulsar.container` | [Kafka & Pulsar](messaging.md) |
| `s3` | Object-storage client + `s3.container` MinIO recipe | Docker daemon for `s3.container` | [s3](s3.md) |
| `yaml` | Parse YAML text (including multi-document streams) to Lua values | — | [yaml](yaml.md) |
| `archetect` | Render and verify [Archetect](https://archetect.github.io) archetypes in-process | — | [archetect](archetect.md) |

Tests that need the Docker daemon should declare `requires = { "docker" }` so they **skip gracefully** (never fail) on machines where it is absent — see [Dependencies & Scheduling](../../writing-tests/dependencies-and-scheduling.md).

Module functions that perform I/O (`shell.run`, everything in `http`, `docker.run`, all the `client` and `container` functions) are **async under the hood** and must be called inside a fixture factory or test body, where prova's runtime is driving the coroutine. The `prova` and `ctx`/`t` surfaces they compose with are documented under the [Lua API](../lua-api/index.md).
