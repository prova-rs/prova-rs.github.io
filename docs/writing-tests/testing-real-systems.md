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

-- Render once (headless), shared across the suite.
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

The second fixture is the heart of the file. It stands up everything the service needs, boots it, and hands tests exactly two things: the gRPC address and a live connection to the service's database.

```lua
local service = prova.fixture("service", Scope.File, function(ctx)
  local dir = ctx:use(project):dir("inventory-service").path

  -- One line: container, readiness (a connection that HOLDS, not just an open port), managed
  -- teardown. `pg.url` is what we inject into the service; `pg.client` is ours to cross-check with.
  local pg = postgres.container(ctx, { user = "dev", password = "dev", database = "inventory_service" })
  local db_url = pg.url
```

- **`ctx:use(project)`** — a fixture-to-fixture dependency. The service fixture doesn't know or care how the project came to exist; it just asks for it.
- **[`postgres.container`](../reference/modules/databases.md)** is doing a lot in one line: it starts `postgres:16-alpine` published on a **random host port** (two suites can each run their own Postgres without colliding), gates readiness on a **real connection that holds** — not just an open socket, which matters because Postgres restarts once during first-boot initialization — and ties both the connection and the container to the fixture's scope, so teardown is automatic pass or fail. What comes back is the [standard resource shape](../reference/modules/index.md#the-grammar) `{ client, url, container }`: `pg.url` is what we inject into the service under test, and `pg.client` is an already-managed connection to the very same database, ready for cross-checking.

That's the whole provisioning story — one line, no ceremony. Want to see exactly what that one line is doing — or need a dependency Prova has no recipe for? → [Building from Primitives](./building-from-primitives.md).

## Step 3 — Build and boot the service

```lua
  local build = shell.run("cargo build", { cwd = dir, timeout = "600s" })
  assert(build:ok(), "service failed to build:\n" .. build.stderr)

  -- Boot the built binary wired to Postgres via the service's own env config (figment APP_* / __).
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
  return { addr = addr, db = pg.client }
end)
```

- **[`shell.run`](../reference/modules/shell.md)** compiles the rendered project — `cwd` is explicit (there is no ambient working directory to mutate), and a failed build aborts with the compiler's own stderr.
- **`net.free_port()`** allocates a port the OS says is free, then passes it to the service through its *own* configuration surface (environment variables). No hardcoded ports means parallel runs don't fight.
- **`shell.spawn` + `ctx:manage`** starts the binary in the background and guarantees it is killed at teardown. This is the boot-then-probe shape: spawn, gate, probe.
- **[`grpc.wait_for`](../reference/modules/grpc.md)** is the final readiness gate — and it is doing double duty. This service connects to Postgres before it serves, so a gRPC endpoint that answers *proves* the whole chain: container up, database ready, migrations run, service configured correctly.
- **The return value hands tests `pg.client` directly** as `db` — a live connection to the database the service is wired to, with its lifecycle already managed by the recipe.

## Step 4 — Probe the API, cross-check the database

```lua
prova.group("inventory gRPC service (Postgres)", { requires = { "docker", "cargo" } }, function(g)
  g:test("boots against real Postgres and serves its gRPC API", function(t)
    local svc = t:use(service)
    local client = grpc.client(svc.addr)
    -- Reaching a reflection-built client at all proves the service booted — which required a live
    -- Postgres connection. The method is reachable; today the scaffold answers Unimplemented.
    local res = client:call_status("inventory_service.InventoryService/CreateInventory",
                                   { display_name = "widget" })
    t:expect(res.code):equals("Unimplemented")  -- becomes "Ok" as real CRUD lands in the archetype
  end)

  g:test("ran its migrations against that same Postgres", function(t)
    local svc = t:use(service)
    -- The recipe's managed client points at the very database the service is wired to —
    -- cross-service state assertion with no extra connection ceremony.
    t:expect(svc.db:query_value("SELECT count(*) FROM _sqlx_migrations WHERE success")):gte(1)
  end)
end)
```

- **`requires = { "docker", "cargo" }` on the group** gates every test at once: on a machine without a Docker daemon or a Rust toolchain, both tests skip with a reason — they never fail spuriously. See [Dependencies & Scheduling](./dependencies-and-scheduling.md).
- **The first test probes from the outside**, exactly like a client would: [`grpc.client`](../reference/modules/grpc.md) builds a reflection-based client and calls a real method. The archetype under test is currently a scaffold whose methods return `Unimplemented` — and asserting that is the point: running the service exposed that "renders + compiles" was hiding a hollow service. As real CRUD lands, this assertion graduates to real persisted state.
- **The second test verifies effects where they land.** `svc.db` is the recipe's managed connection to the *same* database the service uses — no second connection to open, nothing to tear down. One `query_value` asserts the migrations table shows a successful run. Probing the API and inspecting the store are two halves of one acceptance claim.

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
2. **Provision dependencies** — the [container recipes](../reference/modules/index.md#the-grammar) (`postgres.container`, `redis.container`, `kafka.container`, …), one line each; for anything without a recipe, [build it from primitives](./building-from-primitives.md).
3. **Gate on real readiness** — `wait` options, `prova.retry`, [`http.wait_for`](../reference/modules/http.md) or `grpc.wait_for`; never `sleep`.
4. **Boot on dynamic ports** — `net.free_port()` plus `shell.spawn` under `ctx:manage`.
5. **Probe from the outside** — [`http`](../reference/modules/http.md), [`grpc`](../reference/modules/grpc.md), [`graphql`](../reference/modules/graphql.md), or the CLI itself via `shell.run`.
6. **Cross-check state where it lands** — [`postgres`/`mysql`/`sqlite`](../reference/modules/databases.md), [`redis`](../reference/modules/redis.md), [`s3`](../reference/modules/s3.md).

When several files need the same expensive stack, promote the fixtures into a [suite](./suites-and-shared-state.md) and provision once for all of them.
