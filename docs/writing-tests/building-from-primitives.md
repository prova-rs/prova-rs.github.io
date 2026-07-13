---
sidebar_position: 9
---

# Building from Primitives

Every `X.container` recipe — `postgres.container`, `redis.container`, `kafka.container`, and the rest — is sugar over four primitives you already have: [`docker.run`](../reference/modules/docker.md) (with its `wait` gates), [`prova.retry`](../reference/lua-api/prova.md#provaretry), `X.client`, and [`ctx:manage`](../reference/lua-api/context.md#ctxmanage). This page rebuilds `postgres.container` by hand so you can construct the same integration for anything: a technology Prova has no recipe for, a custom image, a dependency with unusual readiness semantics.

The vehicle is the primitives companion to the [Testing Real Systems](./testing-real-systems.md) capstone — the same gRPC-service-plus-Postgres integration, with the database built from scratch. It ships in the Prova repository as `examples/service_grpc_postgres_primitives_test.lua`; only the provisioning block differs from the idiomatic version, so that block is what we walk through here.

## 1. Start the container, tied to the scope

```lua
  -- 1. Start the container. `ports = { 5432 }` publishes to a RANDOM host port (parallel runs
  --    never collide); `wait = { port = ... }` gates on a listening socket. `ctx:manage` ties the
  --    container's removal to this fixture's teardown — pass or fail, nothing leaks.
  local pg = ctx:manage(docker.run{
    image = "postgres:16-alpine",
    env = { POSTGRES_USER = "dev", POSTGRES_PASSWORD = "dev", POSTGRES_DB = "inventory_service" },
    ports = { 5432 },
    wait = { port = 5432, timeout = "60s" },
  })
```

Three choices carry all the weight:

- **`ports = { 5432 }` publishes to a random host port.** Never hardcode a host port unless the technology forces you to (see [the wrinkles](#real-world-wrinkles) below) — random ports are what let two suites, or two CI jobs on one machine, each run their own instance without colliding.
- **`wait = { port = 5432 }`** blocks `docker.run` until something is listening. This is a cheap first gate — necessary, and as we're about to see, not sufficient.
- **`ctx:manage(...)`** registers the container with the fixture's scope. When the scope ends — tests passed, failed, or errored — the container is stopped and removed. No leaked containers, ever, and no cleanup code in any test.

## 2. Recover the port, build the URL

```lua
  -- 2. Recover the mapped port and build the URL the app under test will be given.
  local db_url = "postgres://dev:dev@127.0.0.1:" .. pg:host_port(5432) .. "/inventory_service"
```

`pg:host_port(5432)` asks the [container handle](../reference/modules/docker.md#container) which host port Docker actually assigned. The URL you assemble from it plays the role of the recipe's `url` field: it is the one string the app under test needs — injected through its own configuration surface (an environment variable, a flag, a config file).

## 3. Gate on real readiness, not a socket

```lua
  -- 3. Gate on REAL readiness, not a socket. Postgres restarts once during first-boot init, so a
  --    listening port is not yet a database. Retry until a client connection HOLDS — the service we
  --    are about to boot connects exactly once and exits on failure. The connection is managed too,
  --    so it closes at teardown (in LIFO order, before the container it points at).
  local db = ctx:manage(prova.retry(function() return postgres.client(db_url) end, { timeout = "30s" }))
```

This line is the heart of every recipe, and the reason a `wait = { port = ... }` gate alone would be a bug:

- **A socket is not a database.** Postgres restarts once during first-boot initialization — the port opens, closes, and opens again. A test that treated the first open socket as "ready" would race that restart and fail intermittently. `prova.retry` polls until [`postgres.client`](../reference/modules/databases.md) returns a connection that *holds*.
- **The app under test gets one attempt.** The service this fixture is about to boot connects to its database exactly once at startup and exits on failure. The retry loop belongs in the harness, where flakiness can be absorbed and reported — not in the system under test, where it would be masked.
- **Teardown is LIFO.** Managed resources are released in reverse creation order, so the client closes *before* the container it points at is stopped. You get correct ordering for free by managing things in the order you create them.

From here the primitives file is identical to the idiomatic one: build with `shell.run`, boot on a `net.free_port()` under `ctx:manage`, gate with `grpc.wait_for`, and return `{ addr = addr, db = db }` so tests can probe the API and cross-check the database.

## The recipe, generalized

Wrap those three steps in a local function and you have a recipe of your own. Match the grammar of the [first-party modules](../reference/modules/index.md#the-grammar) — return `{ client, url, container }` — and your home-grown recipe is indistinguishable from a shipped one:

```lua
local function widgetdb_container(ctx, opts)
  opts = opts or {}
  local container = ctx:manage(docker.run{
    image = opts.image or "widgetdb:latest",
    env = { ... },                                   -- credentials, database name, ...
    ports = { 7777 },                                -- random host port
    wait = { port = 7777, timeout = "60s" },         -- cheap gate: something is listening
  })
  local url = "widgetdb://127.0.0.1:" .. container:host_port(7777) .. "/mydb"
  local client = ctx:manage(prova.retry(function()   -- real gate: a connection that HOLDS
    return widgetdb_connect(url)
  end, { timeout = "60s" }))
  return { client = client, url = url, container = container }
end
```

The checklist, in order:

1. **`ctx:manage(docker.run{...})`** — image, env, `ports` for a random host port, a `wait` gate, all tied to the scope.
2. **`container:host_port(N)`** → assemble the `url` the app under test will be handed.
3. **`ctx:manage(prova.retry(function() return X.client(url) end, {...}))`** — readiness defined as *a real client operation succeeding*, and the client itself managed so it closes before its container stops.
4. **Return `{ client = client, url = url, container = container }`** — plus any extras callers need (as `s3.container` returns `access_key`/`secret_key`).

### Real-world wrinkles

Two patterns from the shipped recipes worth stealing:

- **Log-gated readiness (Pulsar-style).** Some containers announce readiness in their logs long before — or regardless of — any port semantics. `docker.run` supports `wait = { log = "..." }`: the shipped `pulsar.container` gates on `wait = { log = "messaging service is ready" }` because Pulsar standalone opens ports well before its broker can serve. Use a log gate when the image tells you it is ready in words.
- **Fixed-port constraints (Kafka-style).** Kafka advertises a listener address that clients must be able to reach, so the broker has to know its host port *before* it starts — a randomly assigned port arrives too late. The shipped `kafka.container` therefore binds a **fixed** host port (`ports = { { container = 9092, host = port } }`, default 9092), at the cost that only one instance runs per host at a time. If your dependency embeds its own address in a handshake, you have the same constraint; make the port an option so callers can at least choose which fixed port.
- **Readiness that does double duty (MinIO-style).** The shipped `s3.container` connects with `create = true`, so the retry loop both proves readiness and creates the test bucket. If your client's first operation can perform required setup, fold it into the gate.

## Run it

```shell
prova examples/service_grpc_postgres_primitives_test.lua
```

The primitives group is tagged `"primitives"`, so once tag filtering lands you will be able to select or exclude the hand-rolled variants as a group.

When a recipe exists for your dependency, prefer it — the one-liner in [Testing Real Systems](./testing-real-systems.md) is the idiomatic shape, and everything on this page is exactly what it expands to.
