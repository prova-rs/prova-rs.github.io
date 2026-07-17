---
sidebar_position: 11
---

# Building from Primitives

Everything a [plugin](/docs/plugins/) recipe like `postgres.container` does is a few primitives you already have: [`docker.run`](../reference/modules/docker.md) (with its `wait` gates), `container:run` (drive the CLI already inside the image), [`prova.retry`](../reference/lua-api/prova.md#provaretry), and [`ctx:manage`](../reference/lua-api/context.md#ctxmanage). This page rebuilds the postgres recipe by hand so you can construct the same integration for anything: a technology with no plugin, a custom image, a dependency with unusual readiness semantics.

The vehicle is the primitives companion to the [Testing Real Systems](./testing-real-systems.md) capstone — the same gRPC-service-plus-Postgres integration, with the database built from scratch instead of via `require("postgres")`. It ships in the Prova repository as `examples/service_grpc_postgres_primitives_test.lua`; no plugin means no `prova.toml`, so it runs directly. Only the provisioning differs from the idiomatic version, so that is what we walk through here.

## 1. Start the container, tied to the scope

```lua
  -- 1. Start the container. `ports = { 5432 }` publishes to a RANDOM host port (parallel runs never
  --    collide); `wait = { port = ... }` gates on a listening socket. `ctx:manage` ties removal to
  --    this fixture's teardown — pass or fail, nothing leaks.
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

`pg:host_port(5432)` asks the [container handle](../reference/modules/docker.md#container) which host port Docker actually assigned. The URL you assemble from it plays the role of the plugin resource's `url` field: it is the one string the app under test needs — injected through its own configuration surface (an environment variable, a flag, a config file).

## 3. A client from the CLI in the image: `container:run`

The plugin's `client` is not a native database driver — it execs `psql` *inside the container*, where the CLI already ships. A hand-rolled version is a four-line helper:

```lua
-- A tiny docker-exec psql helper — what the postgres plugin wraps. Runs a query inside the container
-- (no shell, no quoting) and returns the trimmed scalar.
local function psql(container, sql)
  return (container:run({
    "env", "PGPASSWORD=dev", "psql", "-U", "dev", "-d", "inventory_service", "-tAc", sql,
  }):gsub("%s+$", ""))
end
```

`container:run(argv)` executes the argv inside the running container and returns its output. Passing an **argv table, not a command string**, means no shell and no quoting bugs — the SQL arrives at `psql` exactly as written. This is the black-box trick that makes the whole approach language-free: every serious data store ships its own CLI in its own image, so you never need a native driver in the test runner.

## 4. Gate on real readiness, not a socket

```lua
  -- 3. Gate on REAL readiness, not a socket. Postgres restarts once during first-boot init, so a
  --    listening port is not yet a database. Retry a real query (via `container:run`) until it HOLDS —
  --    the service we boot next connects exactly once and exits on failure.
  prova.retry(function() psql(pg, "SELECT 1"); return true end,
    { timeout = "30s", message = "postgres did not accept connections in time" })
```

This gate is the heart of every recipe, and the reason a `wait = { port = ... }` gate alone would be a bug:

- **A socket is not a database.** Postgres restarts once during first-boot initialization — the port opens, closes, and opens again. A test that treated the first open socket as "ready" would race that restart and fail intermittently. `prova.retry` runs a real query until it *holds*.
- **The app under test gets one attempt.** The service this fixture is about to boot connects to its database exactly once at startup and exits on failure. The retry loop belongs in the harness, where flakiness can be absorbed and reported — not in the system under test, where it would be masked.

From here the primitives file is identical to the idiomatic one: build with `shell.run`, boot on a `net.free_port()` under `ctx:manage`, gate with `grpc.wait_for`, and return `{ addr = addr, container = pg }` so tests can probe the API — and cross-check the database with the same `psql` helper:

```lua
  g:test("ran its migrations against that same Postgres", function(t)
    local svc = t:use(service)
    -- Cross-check the very database the service is wired to, by execing psql in its container.
    t:expect(psql(svc.container, "SELECT count(*) FROM _sqlx_migrations WHERE success")):gte(1)
  end)
```

## The recipe, generalized

Wrap those steps in a local function and you have a recipe of your own. Match the shape the plugins return — `{ container, url, host, port }`, plus a client helper — and your home-grown provisioner is indistinguishable from an installed plugin:

```lua
local function widgetdb_container(ctx, opts)
  opts = opts or {}
  local container = ctx:manage(docker.run{
    image = opts.image or "widgetdb:latest",
    env = { ... },                                   -- credentials, database name, ...
    ports = { 7777 },                                -- random host port
    wait = { port = 7777, timeout = "60s" },         -- cheap gate: something is listening
  })
  local port = container:host_port(7777)
  local url = "widgetdb://127.0.0.1:" .. port .. "/mydb"
  prova.retry(function()                             -- real gate: a client operation that HOLDS
    container:run({ "widgetdb-cli", "ping" }); return true
  end, { timeout = "60s", message = "widgetdb did not become ready in time" })
  return { container = container, url = url, host = "127.0.0.1", port = port }
end
```

The checklist, in order:

1. **`ctx:manage(docker.run{...})`** — image, env, `ports` for a random host port, a `wait` gate, all tied to the scope.
2. **`container:host_port(N)`** → assemble the `url` (and `host`/`port`) the app under test will be handed.
3. **`prova.retry(function() ... end, {...})`** around a real client operation — via `container:run` on the CLI in the image — so readiness means *the dependency actually works*, not *a port is open*.
4. **Return the standard resource shape** — `{ container, url, host, port }`, plus any helpers or extras callers need.

When the wrapper stabilizes, promote it: a Prova plugin is exactly this function in a package, and [Authoring Plugins](/docs/plugins/authoring-plugins) shows how to publish it so the next project gets it as a one-line `[plugins]` entry.

### Real-world wrinkles

The kitchen-sink primitives file (`examples/kitchen_sink_primitives_test.lua`) provisions three dependencies by hand precisely because each needs a *different* readiness shape:

- **A longer horizon (MySQL).** Same shape as Postgres — socket gate, then retry a real query via the image's `mysql` CLI — but first-boot initialization takes tens of seconds and it also restarts, so only the retry horizon changes (`timeout = "90s"`). Readiness *shape* and readiness *budget* are independent knobs.
- **Log-gated readiness (Pulsar).** Some containers announce readiness in their logs long before — or regardless of — any port semantics. `docker.run` supports `wait = { log = "..." }`: Pulsar standalone gates on `wait = { log = "messaging service is ready" }` because it opens its ports well before its broker can serve. Use a log gate when the image tells you it is ready in words — the log line *is* the readiness signal, no client probe needed.
- **Fixed-port constraints (Kafka-style).** Kafka advertises a listener address that clients must be able to reach, so the broker has to know its host port *before* it starts — a randomly assigned port arrives too late. In that case bind a **fixed** host port (`ports = { { container = 9092, host = port } }`), at the cost that only one instance runs per host at a time. If your dependency embeds its own address in a handshake, you have the same constraint; make the port an option so callers can at least choose which fixed port.

## Run it

No plugin, so no manifest — point Prova at the file from the repo root:

```shell
prova examples/service_grpc_postgres_primitives_test.lua
```

The primitives groups are tagged `"primitives"`, so `prova --tags primitives` selects the hand-rolled variants as a group — and `prova --tags '!primitives'` excludes them.

When a plugin exists for your dependency, prefer it — the one-liner in [Testing Real Systems](./testing-real-systems.md) is the idiomatic shape, and everything on this page is exactly what it expands to.
