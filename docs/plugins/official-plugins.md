---
sidebar_position: 3
---

# Official Plugins

The `prova-rs` organization maintains a plugin for each of the common infrastructure dependencies. All of them are pure-Lua docker-exec plugins — zero native code — authored through [`prova.containerized`](./authoring-plugins.md#provacontainerized) and driving the CLI already inside the image via `container:run`. Each one is self-testing (its repo runs its own `prova` suite in CI) and requires the Docker daemon at `container()` time, so gate consuming tests with `requires = { "docker" }`.

Every plugin's `X.container(ctx, opts?)` returns the standard resource shape `{ client, url, container, host, port }`.

| Plugin | Provisions / speaks | Repository |
|---|---|---|
| `postgres` | PostgreSQL (`postgres:16-alpine`) — SQL over `psql`: `execute` / `query` / `query_value`, client-side `$1` binding | [prova-rs/prova-postgres](https://github.com/prova-rs/prova-postgres) |
| `mysql` | MySQL (`mysql:8`) — SQL over the `mysql` CLI, same client verbs as postgres | [prova-rs/prova-mysql](https://github.com/prova-rs/prova-mysql) |
| `redis` | Redis cache — over `redis-cli`: get/set/seed keys, plus a generic command escape hatch | [prova-rs/prova-redis](https://github.com/prova-rs/prova-redis) |
| `kafka` | Kafka topics/streams — over the console tools: `create_topic` / `produce` / `consume` | [prova-rs/prova-kafka](https://github.com/prova-rs/prova-kafka) |
| `pulsar` | Apache Pulsar standalone — over `pulsar-client`: `produce` / `consume` (heavy image; slow first boot) | [prova-rs/prova-pulsar](https://github.com/prova-rs/prova-pulsar) |
| `rabbitmq` | RabbitMQ (AMQP) — over `rabbitmqadmin`: `declare_queue` / `publish` / `get` | [prova-rs/prova-rabbitmq](https://github.com/prova-rs/prova-rabbitmq) |
| `s3` | S3-compatible object store (MinIO) — over `mc`: `put` / `get` / `list` / buckets, with credential fields on the resource | [prova-rs/prova-s3](https://github.com/prova-rs/prova-s3) |

## Declaring them

```toml
[plugins]
postgres = "prova-rs/prova-postgres@main"
redis    = "prova-rs/prova-redis@main"
kafka    = "prova-rs/prova-kafka@main"
```

```lua
local postgres = require("postgres")
local db = postgres.container(ctx, { database = "orders" })
```

## Pinning

The official plugins have **not cut releases yet** — there are no version tags today, which is why every example pins `@main`. Note the [caching semantics](./using-plugins.md#caching-and-pinning): a branch ref like `@main` is cached on first fetch and reused, so it tracks "latest as of the first run on this machine", not latest-always.

Once releases exist, **pin tags** in anything you care about:

```toml
[plugins]
postgres = "prova-rs/prova-postgres@v1.0.0"
```

Tagged pins are immutable and shallow-cloned — reproducible builds, stable cache. Each plugin declares the Prova versions it supports via `requires.prova` in its manifest (currently `>=0.2, <0.3` across the catalog), and an incompatible pairing fails at resolve time with a clear message.

Missing a technology? [Author your own](./authoring-plugins.md) — the archetype generates the whole repo, and any of the plugins above is a readable reference implementation.
