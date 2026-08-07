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
| [`prova`](./prova.md) | The registration DSL: `fixture`, `topology`, `test`, `test_each`, `flow`, `group`, `describe`, resource constructors, `sleep`, `retry` — plus the package-facing [`prova.parse`](./prova.md#provaparse) toolkit and the [`prova.containerized`](./prova.md#provacontainerized) scaffolding helper. |
| [`suite`](./prova.md#suiteconfig) | Suite configuration — `suite.config{...}` in a `suite.lua` setup file. |
| [`Scope`](./prova.md#scope-constants) | Typed fixture-scope constants: `Scope.Test`, `Scope.Flow`, `Scope.File`, `Scope.Suite`. |
| [`fs`](../modules/fs.md) | Filesystem: read/write files, temp dirs, globbing. |
| [`shell`](../modules/shell.md) | Run commands (`shell.run`) and spawn managed processes (`shell.spawn`). |
| [`net`](../modules/index.md) | Network helpers (e.g. free-port allocation for locally spawned apps). |
| [`http`](../modules/http.md) | HTTP client: `get`/`post`/…, `:json()`, `http.client`, and the `wait_for` readiness probe. |
| [`grpc`](../modules/grpc.md) | gRPC via server reflection: `client`, `call`, `call_status`, `wait_for`. |
| [`graphql`](../modules/graphql.md) | GraphQL client, same shape as `http`/`grpc`. |
| [`docker`](../modules/docker.md) | Ephemeral containers: pull/run/port-map/logs/exec/run/stop — the substrate containerized resource packages build on. |
| [`sqlite`](../modules/sqlite.md) | SQLite client (file or `sqlite::memory:`) — the one embedded, no-docker database bundled with Prova. |
| [`archetect`](../modules/archetect.md) | In-process Archetect rendering: `archetect.render{...}`, `archetect.verify{...}`. Shipped with the standalone `prova` binary. |
| [`json`](../modules/data.md#json) | Encode/decode JSON; `json.null` and `json.array` for the shapes Lua cannot express. |
| [`yaml`](../modules/yaml.md) | Parse YAML into Lua tables. |
| [`toml`](../modules/data.md#toml) | Encode/decode TOML. |
| [`csv`](../modules/data.md#csv) | Header-aware CSV, same row shape as `prova.parse.table`. |
| [`base64`](../modules/data.md#base64) | Base64 encode/decode, binary-safe. |
| [`hash`](../modules/data.md#hash) | `sha256` and `hmac_sha256` as lowercase hex. |
| [`uuid`](../modules/data.md#uuid) | `uuid.v4()` — a fresh RFC 4122 id per call. |
| [`url`](../modules/data.md#url) | Parse a URL into parts; percent-encode a component. |
| `junit` | JUnit XML result files: `junit.load` parses a report, `junit.verify` runs another harness and adopts its verdict. |
| [`socket`](../../writing-tests/mocking-and-proxies.md#sockets) | TCP/Unix: connect, listen, mock framed turns, or interpose a wiretap with fault injection. |
| [`terminal`](../../writing-tests/mocking-and-proxies.md#terminals) | Drive a program on a real pty, or shadow an interactive CLI on `PATH`. |
| [`websocket`](../../writing-tests/mocking-and-proxies.md#websockets) | WebSocket: connect, a real in-process server (including unprompted push), or a direction-tagged proxy. |

## Service resources are packages

Databases, caches, brokers, object stores — every *containerized* resource
(`postgres`, `mysql`, `redis`, `kafka`, `pulsar`, `s3`, …) — are **not**
built-in globals. They are external packages:
declare them under `[dependencies]` in `prova.toml` (or ad-hoc with
`-P, --package name=source`) and bring them in with `require("<name>")`:

```lua
local postgres = require("postgres")

local db = prova.fixture("db", Scope.Suite, function(ctx)
  return postgres.container(ctx)     -- → { url, container, host, port, client? }
end)
```

See [Using packages](../../packages/using-packages.md) for declaring and consuming
packages, and [Authoring packages](../../packages/authoring-packages.md) for
building your own with `prova.containerized` + `Container:run` + `prova.parse`.

## Pages in this section

| Page | Description |
|---|---|
| [The `prova` global](./prova.md) | Every registration function, its options tables, resource constructors, timing primitives, `prova.parse`, and `prova.containerized`. |
| [Contexts](./context.md) | `Context` (fixture factories), `TestContext` (test bodies), and the flow/group builders. |
| [Matchers](./matchers.md) | The complete `t:expect(...)` matcher surface, negation, labels, and soft assertions. |
