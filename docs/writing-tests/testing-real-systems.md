---
sidebar_position: 7
---

# Testing Real Systems

This is the test Prova was built for. In one Lua file we will render a gRPC service from an archetype, compile it, provision an ephemeral Postgres in Docker, boot the service wired to that database, drive its gRPC API, and then cross-check the service's own database — the tier of acceptance testing that a declarative harness structurally cannot express. The full file ships in the Prova repository as `examples/service_grpc_postgres_test.lua`; this page walks it section by section and explains *why* each piece is shaped the way it is.

The pattern generalizes far beyond archetypes: **bring a system into existence, gate on real readiness, probe it from the outside, and verify its effects where they actually land.**

## Step 1 — Render the system under test

```lua
local ANSWERS = {
  author_name = "Test Author", author_email = "test@example.com",
  org_name = "acme", solution_name = "platform",
  prefix_name = "inventory", suffix_name = "Service", image_registry = "ghcr.io/acme",
  persistence = "PostgreSQL",
}

-- Render once (headless), shared across the file.
local project = prova.fixture("project", Scope.File, function(ctx)
  return archetect.render{
    source = "https://github.com/p6m-archetypes/rust-grpc-service-archetype.git#dev",
    answers = ANSWERS,
    destination = ctx:tempdir(),
    defaults = true,
  }
end)
```

Three decisions here, each earning its keep:

- **A `Scope.File` fixture.** Rendering (and later, building) is expensive. Declaring it as a [fixture](./fixtures.md) means it happens once, lazily, and every test shares the result.
- **[`archetect.render`](../reference/modules/archetect.md) runs in-process** — answers are passed as data, not marshaled into CLI strings, and errors surface as real diagnostics.
- **`ctx:tempdir()` as the destination.** Scratch space is scoped: when the file's tests finish, the rendered project vanishes with them.

## Step 2 — Provision real infrastructure

The second fixture is the heart of the file. It stands up everything the service needs, boots it, and hands tests exactly two things: the gRPC address and the database URL.

```lua
local service = prova.fixture("service", Scope.File, function(ctx)
  local dir = ctx:use(project):dir("inventory-service").path

  local pg = ctx:manage(docker.run{
    image = "postgres:16-alpine",
    env = { POSTGRES_USER = "dev", POSTGRES_PASSWORD = "dev", POSTGRES_DB = "inventory_service" },
    ports = { 5432 },
    wait = { port = 5432, timeout = "60s" },
  })
  local db_url = "postgres://dev:dev@127.0.0.1:" .. pg:host_port(5432) .. "/inventory_service"

  -- Postgres restarts once at first-boot init; wait for a real connection to hold
  -- before the service (which connects once and exits on failure) tries.
  ctx:manage(prova.retry(function() return db.connect(db_url) end, { timeout = "30s" }))
```

- **`ctx:use(project)`** — a fixture-to-fixture dependency. The service fixture doesn't know or care how the project came to exist; it just asks for it.
- **`ctx:manage(docker.run{...})`** ties the container's lifecycle to the fixture's scope: when the file's tests finish, the container is stopped — pass or fail, no leaked containers. [`docker.run`](../reference/modules/docker.md) publishes port 5432 to an ephemeral host port (`pg:host_port(5432)` recovers it), so two suites can each run their own Postgres without colliding.
- **Two readiness gates, deliberately.** The `wait = { port = 5432 }` option gets us a listening socket — but Postgres famously restarts once during first-boot initialization, so a socket is not a database. `prova.retry` polls until [`db.connect`](../reference/modules/db.md) *holds*, because the service we are about to boot connects exactly once and exits on failure. Gating on real readiness — not sleeps — is what makes this test fast when things are healthy and honest when they are not. The connection itself is `ctx:manage`d too, so it closes at teardown.

## Step 3 — Build and boot the service

```lua
  local build = shell.run("cargo build", { cwd = dir, timeout = "600s" })
  assert(build:ok(), "service failed to build:\n" .. build.stderr)

  -- Boot the built binary wired to Postgres via the service's own env config.
  local port = net.free_port()
  ctx:manage(shell.spawn(dir .. "/target/debug/inventory-service", {
    cwd = dir,
    env = {
      APP_PERSISTENCE__URL = db_url,
      APP_SERVER__PORT = tostring(port),
      APP_SERVER__MANAGEMENT_PORT = tostring(port + 1),
    },
  }))

  local addr = "127.0.0.1:" .. port
  grpc.wait_for(addr, { timeout = "30s" })  -- the service only answers if it connected to Postgres
  return { addr = addr, db_url = db_url }
end)
```

- **[`shell.run`](../reference/modules/shell.md)** compiles the rendered project — `cwd` is explicit (there is no ambient working directory to mutate), and a failed build aborts with the compiler's own stderr.
- **`net.free_port()`** allocates a port the OS says is free, then passes it to the service through its *own* configuration surface (environment variables). No hardcoded ports means parallel runs don't fight.
- **`shell.spawn` + `ctx:manage`** starts the binary in the background and guarantees it is killed at teardown. This is the boot-then-probe shape: spawn, gate, probe.
- **[`grpc.wait_for`](../reference/modules/grpc.md)** is the final readiness gate — and it is doing double duty. This service connects to Postgres before it serves, so a gRPC endpoint that answers *proves* the whole chain: container up, database ready, migrations run, service configured correctly.

## Step 4 — Probe the API, cross-check the database

```lua
prova.group("inventory gRPC service (Postgres)", { requires = { "docker", "cargo" } }, function(g)
  g:test("boots against real Postgres and serves its gRPC API", function(t)
    local svc = t:use(service)
    local client = grpc.connect(svc.addr)
    local res = client:call_status("inventory_service.InventoryService/CreateInventory",
                                   { display_name = "widget" })
    t:expect(res.code):equals("Unimplemented")  -- becomes "Ok" as real CRUD lands in the archetype
  end)

  g:test("ran its migrations against that same Postgres", function(t)
    local svc = t:use(service)
    local conn = t:manage(db.connect(svc.db_url))
    -- prova queries the very database the service is wired to — cross-service state assertion.
    t:expect(conn:query_value("SELECT count(*) FROM _sqlx_migrations WHERE success")):gte(1)
  end)
end)
```

- **`requires = { "docker", "cargo" }` on the group** gates every test at once: on a machine without a Docker daemon or a Rust toolchain, both tests skip with a reason — they never fail spuriously. See [Dependencies & Scheduling](./dependencies-and-scheduling.md).
- **The first test probes from the outside**, exactly like a client would: [`grpc.connect`](../reference/modules/grpc.md) builds a reflection-based client and calls a real method. The archetype under test is currently a scaffold whose methods return `Unimplemented` — and asserting that is the point: running the service exposed that "renders + compiles" was hiding a hollow service. As real CRUD lands, this assertion graduates to real persisted state.
- **The second test verifies effects where they land.** It opens its own connection to the *same* database the service uses (the fixture returned `db_url` precisely for this) and asserts the migrations table shows a successful run. Probing the API and inspecting the store are two halves of one acceptance claim.

Note what the tests do *not* contain: no setup, no cleanup, no sleeps, no port numbers. Each test is two or three lines of intent; the fixture owns the machinery.

## Run it

```shell
prova examples/service_grpc_postgres_test.lua
```

```text
· service_grpc_postgres_test › inventory gRPC service (Postgres) › boots against real Postgres and serves its gRPC API
· service_grpc_postgres_test › inventory gRPC service (Postgres) › ran its migrations against that same Postgres
```

First run clones the archetype and downloads crates, so give it time; teardown then stops the service, closes the connections, removes the container, and deletes the temp dirs — in exactly the reverse of the order they were created.

## The pattern, portable

Swap the pieces and the shape holds for any system:

1. **Bring it into existence** — `archetect.render`, a `git clone`, or your checked-out repo; build with `shell.run`.
2. **Provision dependencies** — [`docker.run`](../reference/modules/docker.md) for Postgres/Redis/Kafka, always through `ctx:manage`.
3. **Gate on real readiness** — `wait` options, `prova.retry`, [`http.wait_for`](../reference/modules/http.md) or `grpc.wait_for`; never `sleep`.
4. **Boot on dynamic ports** — `net.free_port()` plus `shell.spawn` under `ctx:manage`.
5. **Probe from the outside** — [`http`](../reference/modules/http.md), [`grpc`](../reference/modules/grpc.md), [`graphql`](../reference/modules/graphql.md), or the CLI itself via `shell.run`.
6. **Cross-check state where it lands** — [`db`](../reference/modules/db.md), [`redis`](../reference/modules/redis.md), [`s3`](../reference/modules/s3.md).

When several files need the same expensive stack, promote the fixtures into a [suite](./suites-and-shared-state.md) and provision once for all of them.
