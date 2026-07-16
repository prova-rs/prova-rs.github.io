---
sidebar_position: 3
sidebar_label: "Lua API"
---

# Lua API Reference

Prova **injects its entire built-in API as globals** into every test file — no
`require` is needed. Write `prova.test(...)` or `shell.run(...)` directly.
(`require("prova")` is still supported and returns the same table, for anyone who
prefers an explicit import.)

The LuaCATS stubs shipped in Prova's `library/` directory are the API contract:
they drive editor completion, hover, and type-checking via `lua-language-server`.
The stubs annotate a small aspirational subset ahead of the engine; the
[Roadmap](../roadmap.md) tracks exactly which members those are. Everything
documented in this section is implemented.

## Injected globals (built-in)

| Global | Description |
|---|---|
| [`prova`](./prova.md) | The registration DSL: `fixture`, `test`, `test_each`, `flow`, `group`, `describe`, resource constructors, `sleep`, `retry` — plus the plugin-facing [`prova.parse`](./prova.md#provaparse) toolkit and the [`prova.containerized`](./prova.md#provacontainerized) scaffolding helper. |
| [`suite`](./prova.md#suiteconfig) | Suite configuration — `suite.config{...}` in a `suite.lua` setup file. |
| [`Scope`](./prova.md#scope-constants) | Typed fixture-scope constants: `Scope.Test`, `Scope.Flow`, `Scope.File`, `Scope.Suite`. |
| [`fs`](../modules/fs.md) | Filesystem: read/write files, temp dirs, globbing. |
| [`shell`](../modules/shell.md) | Run commands (`shell.run`) and spawn managed processes (`shell.spawn`). |
| [`net`](../modules/index.md) | Network helpers (e.g. free-port allocation for locally spawned apps). |
| [`http`](../modules/http.md) | HTTP client: `get`/`post`/…, `:json()`, `http.client`, and the `wait_for` readiness probe. |
| [`docker`](../modules/docker.md) | Ephemeral containers: pull/run/port-map/logs/exec/run/stop — the substrate containerized resource plugins build on. |
| [`sqlite`](../modules/sqlite.md) | SQLite client (file or `sqlite::memory:`) — the one embedded, no-docker database bundled with Prova. |
| [`grpc`](../modules/grpc.md) | gRPC via server reflection: `client`, `call`, `call_status`, `wait_for`. |
| [`graphql`](../modules/graphql.md) | GraphQL client, same shape as `http`/`grpc`. |
| [`yaml`](../modules/yaml.md) | Parse YAML into Lua tables. |
| [`archetect`](../modules/archetect.md) | In-process Archetect rendering: `archetect.render{...}`, `archetect.verify{...}`. Shipped with the standalone `prova` binary. |

## Service resources are plugins

Databases, caches, brokers, object stores — every *containerized* resource
(`postgres`, `mysql`, `redis`, `kafka`, `pulsar`, `s3`, …) — are **not**
built-in globals. Since the 0.2 plugin revamp they are external plugins:
declare them under `[plugins]` in `prova.toml` (or ad-hoc with
`--plugin name=source`) and bring them in with `require("<name>")`:

```lua
local postgres = require("postgres")

local db = prova.fixture("db", Scope.Suite, function(ctx)
  return postgres.container(ctx)     -- → { url, container, host, port, client? }
end)
```

See [Using plugins](../../plugins/using-plugins.md) for declaring and consuming
plugins, and [Authoring plugins](../../plugins/authoring-plugins.md) for
building your own with `prova.containerized` + `Container:run` + `prova.parse`.

## Pages in this section

| Page | Description |
|---|---|
| [The `prova` global](./prova.md) | Every registration function, its options tables, resource constructors, timing primitives, `prova.parse`, and `prova.containerized`. |
| [Contexts](./context.md) | `Context` (fixture factories), `TestContext` (test bodies), and the flow/group builders. |
| [Matchers](./matchers.md) | The complete `t:expect(...)` matcher surface, negation, labels, and soft assertions. |
