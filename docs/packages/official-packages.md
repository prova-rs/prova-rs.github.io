---
sidebar_position: 3
---

# Official Packages

The `prova-rs` organization maintains a package for each of the common infrastructure dependencies. The resource packages are pure-Lua docker-exec packages — zero native code — authored through [`prova.containerized`](./authoring-packages.md#provacontainerized) and driving the CLI already inside the image via `container:run`. Each one is self-testing (its repo runs its own `prova` suite in CI) and the container-backed ones require the Docker daemon at `container()` time, so gate consuming tests with `requires = { "docker" }`.

Every resource package's `X.container(ctx, opts?)` returns the standard resource shape `{ client, url, container, host, port }`.

| Package | Provisions / speaks | Repository |
|---|---|---|
| `postgres` | PostgreSQL (`postgres:16-alpine`) — SQL over `psql`: `execute` / `query` / `query_value`, client-side `$1` binding | [prova-rs/prova-postgres](https://github.com/prova-rs/prova-postgres) |
| `mysql` | MySQL (`mysql:8`) — SQL over the `mysql` CLI, same client verbs as postgres | [prova-rs/prova-mysql](https://github.com/prova-rs/prova-mysql) |
| `redis` | Redis cache — over `redis-cli`: get/set/seed keys, plus a generic command escape hatch | [prova-rs/prova-redis](https://github.com/prova-rs/prova-redis) |
| `kafka` | Kafka topics/streams — over the console tools: `create_topic` / `produce` / `consume` | [prova-rs/prova-kafka](https://github.com/prova-rs/prova-kafka) |
| `pulsar` | Apache Pulsar standalone — over `pulsar-client`: `produce` / `consume` (heavy image; slow first boot) | [prova-rs/prova-pulsar](https://github.com/prova-rs/prova-pulsar) |
| `rabbitmq` | RabbitMQ (AMQP) — over `rabbitmqadmin`: `declare_queue` / `publish` / `get` | [prova-rs/prova-rabbitmq](https://github.com/prova-rs/prova-rabbitmq) |
| `s3` | S3-compatible object store (MinIO) — over `mc`: `put` / `get` / `list` / buckets, with credential fields on the resource | [prova-rs/prova-s3](https://github.com/prova-rs/prova-s3) |
| `mongodb` | MongoDB — docker-exec over the `mongosh` CLI | [prova-rs/prova-mongodb](https://github.com/prova-rs/prova-mongodb) |
| `vault` | HashiCorp Vault — ephemeral dev-mode server, KV v2 seeded and asserted over the `vault` CLI | [prova-rs/prova-vault](https://github.com/prova-rs/prova-vault) |
| `kind` | A real Kubernetes cluster (kind) as a **topology** — black-box test operators, CRDs, and chart probes against a live control plane | [prova-rs/prova-kind](https://github.com/prova-rs/prova-kind) |
| `parallels` | A Parallels VM as a **topology** — black-box test a full-OS target Docker can't contain | [prova-rs/prova-parallels](https://github.com/prova-rs/prova-parallels) |
| `xcodebuild` | Run and decode Xcode test bundles — enumerate, build-for-testing, and per-case results from `xcresult` | [prova-rs/prova-xcodebuild](https://github.com/prova-rs/prova-xcodebuild) |

All of them are indexed in the [package registry](https://github.com/prova-rs/package-registry), so `prova packages` finds them by name, description, or capability, and `prova packages add <name>` pins one into your manifest.

## Declaring them

```toml
[dependencies]
postgres = "prova-rs/prova-postgres@v1"
redis    = "prova-rs/prova-redis@v1"
kafka    = "prova-rs/prova-kafka@v1"
```

```lua
local postgres = require("postgres")
local db = postgres.container(ctx, { database = "orders" })
```

## Pinning

Every official package releases version tags, with `v1` as the moving major tag — pin `@v1` to ride compatible releases, or an exact tag (`@v1.0`) for a fully frozen build. Tagged pins are immutable and shallow-cloned — reproducible builds, stable cache (see [caching and freshness](./using-packages.md#caching-and-freshness)). Each package declares the Prova versions it supports via `[requires] prova` in its manifest, and an incompatible pairing fails at resolve time with a clear message.

Missing a technology? [Author your own](./authoring-packages.md) — `prova init package` generates the whole repo, and any of the packages above is a readable reference implementation.
