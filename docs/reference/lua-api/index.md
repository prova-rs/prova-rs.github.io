---
sidebar_position: 3
sidebar_label: "Lua API"
---

# Lua API Reference

Prova **injects its entire API as globals** into every test file — no `require`
is needed. Write `prova.test(...)` or `shell.run(...)` directly.
(`require("prova")` is still supported and returns the same table, for anyone who
prefers an explicit import.)

The LuaCATS stubs shipped in Prova's `library/` directory are the API contract:
they drive editor completion, hover, and type-checking via `lua-language-server`.
The stubs annotate a small aspirational subset ahead of the engine; the
[Roadmap](../roadmap.md) tracks exactly which members those are. Everything
documented in this section is implemented.

## Injected globals

| Global | Description |
|---|---|
| [`prova`](./prova.md) | The registration DSL: `fixture`, `test`, `test_each`, `flow`, `group`, `describe`, resource constructors, `sleep`, `retry`. |
| [`suite`](./prova.md#suiteconfig) | Suite configuration — `suite.config{...}` in a `suite.lua` setup file. |
| [`Scope`](./prova.md#scope-constants) | Typed fixture-scope constants: `Scope.Test`, `Scope.Flow`, `Scope.File`, `Scope.Suite`. |
| [`fs`](../modules/fs.md) | Filesystem: read/write files, temp dirs, globbing. |
| [`shell`](../modules/shell.md) | Run commands (`shell.run`) and spawn managed processes (`shell.spawn`). |
| [`net`](../modules/index.md) | Network helpers (e.g. free-port allocation for locally spawned apps). |
| [`http`](../modules/http.md) | HTTP client: `get`/`post`/…, `:json()`, and the `wait_for` readiness probe. |
| [`grpc`](../modules/grpc.md) | gRPC via server reflection: `client`, `call`, `call_status`, `wait_for`. |
| [`graphql`](../modules/graphql.md) | GraphQL client, same shape as `http`/`grpc`. |
| [`docker`](../modules/docker.md) | Ephemeral containers: pull/run/port-map/logs/exec/stop. |
| [`postgres`](../modules/databases.md) | Postgres client + `postgres.container` recipe; one generic SQL `Connection`. |
| [`mysql`](../modules/databases.md) | MySQL client + `mysql.container` recipe; same `Connection` type. |
| [`sqlite`](../modules/databases.md) | SQLite client (file or `sqlite::memory:`); same `Connection` type. |
| [`redis`](../modules/redis.md) | Redis client. |
| [`pulsar`](../modules/messaging.md) | Apache Pulsar producer/consumer. |
| [`kafka`](../modules/messaging.md) | Apache Kafka producer/consumer. |
| [`s3`](../modules/s3.md) | S3-compatible object storage. |
| [`yaml`](../modules/yaml.md) | Parse YAML into Lua tables. |
| [`archetect`](../modules/archetect.md) | In-process Archetect rendering: `archetect.render{...}`, `archetect.verify{...}`. Shipped with the standalone `prova` binary. |

## Pages in this section

| Page | Description |
|---|---|
| [The `prova` global](./prova.md) | Every registration function, its options tables, resource constructors, and timing primitives. |
| [Contexts](./context.md) | `Context` (fixture factories), `TestContext` (test bodies), and the flow/group builders. |
| [Matchers](./matchers.md) | The complete `t:expect(...)` matcher surface, negation, labels, and soft assertions. |
