---
sidebar_position: 7
---

# Testing Real Systems

This is the test Prova was built for. In one Lua file we will render a gRPC service from an archetype, compile it, provision an ephemeral Postgres in Docker, boot the service wired to that database, drive its gRPC API, and then cross-check the service's own database — the tier of acceptance testing that a declarative harness structurally cannot express. The full example ships in the Prova repository as `examples/service-grpc-postgres/`; this page walks it section by section and explains *why* each piece is shaped the way it is.

The pattern generalizes far beyond archetypes: **bring a system into existence, gate on real readiness, probe it from the outside, and verify its effects where they actually land.**

## Step 0 — Declare the infrastructure package

The database recipe is not built into the runtime — it is the external `postgres` [package](/docs/packages/), declared once in the example directory's `prova.toml`:

```toml
[run]
proofs = ["."]

[dependencies]
postgres = "prova-rs/prova-postgres@v1"
```

Prova fetches the package by its pinned ref and caches it; the official packages release `v1` tags, and `@v1` is the pin to use. The test file then attaches it with an ordinary `require`:

```lua
local postgres = require("postgres")
```

That one line is the entire integration surface — and your editor completes `postgres.*` too, because Prova [syncs each package's annotations automatically](../running-prova/ide-setup.md). See [Using Packages](/docs/packages/using-packages) for sources, pinning, and caching.

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

The second fixture is the heart of the file. It stands up everything the service needs, boots it, and hands tests exactly two things: the gRPC address and a client on the service's database.

```lua
local service = prova.fixture("service", Scope.File, function(ctx)
  local dir = ctx:use(project):dir("inventory-service").path

  -- One line: container, readiness (a connection that HOLDS, not just an open port), managed
  -- teardown. `pg.url` is what we inject into the service; `pg.client` is ours to cross-check with.
  local pg = postgres.container(ctx, { user = "dev", password = "dev", database = "inventory_service" })
  local db_url = pg.url
```

- **`ctx:use(project)`** — a fixture-to-fixture dependency. The service fixture doesn't know or care how the project came to exist; it just asks for it.
- **`postgres.container`** is doing a lot in one line: it starts `postgres:16-alpine` published on a **random host port** (two suites can each run their own Postgres without colliding), gates readiness on a **real query that holds** — not just an open socket, which matters because Postgres restarts once during first-boot initialization — and ties both the client and the container to the fixture's scope, so teardown is automatic pass or fail. What comes back is the standard package resource shape `{ client, url, container, host, port }`: `pg.url` (or the `host`/`port` pair) is what we inject into the service under test, and `pg.client` is an already-managed handle on the very same database — it execs `psql` inside the container, so cross-checking needs no native driver at all.

That's the whole provisioning story — one line, no ceremony. Want to see exactly what that one line is doing — or need a dependency no package covers? → [Building from Primitives](./building-from-primitives.md).

## Step 3 — Build and boot the service

```lua
  shell.run("cargo build", { cwd = dir, timeout = "600s", check = true })

  -- Boot the built binary wired to Postgres via the service's own env config (figment APP_* / __).
  local port = net.free_port()
  ctx:manage(shell.spawn(dir .. "/target/debug/inventory-service", {
    cwd = dir,
    env = {
      APP_PERSISTENCE__URL = db_url,
      APP_SERVER__PORT = port,
      APP_SERVER__MANAGEMENT_PORT = port + 1,
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
- **The return value hands tests `pg.client` directly** as `db` — a ready-made client on the database the service is wired to, with its lifecycle already managed by the package.

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
    -- The package's docker-exec client execs `psql` inside the very container the service is wired to —
    -- cross-service state assertion with no extra connection ceremony.
    t:expect(svc.db:query_value("SELECT count(*) FROM _sqlx_migrations WHERE success")):gte(1)
  end)
end)
```

- **`requires = { "docker", "cargo" }` on the group** gates every test at once: on a machine without a Docker daemon or a Rust toolchain, both tests skip with a reason — they never fail spuriously. See [Dependencies & Scheduling](./dependencies-and-scheduling.md).
- **The first test probes from the outside**, exactly like a client would: [`grpc.client`](../reference/modules/grpc.md) builds a reflection-based client and calls a real method. The archetype under test is currently a scaffold whose methods return `Unimplemented` — and asserting that is the point: running the service exposed that "renders + compiles" was hiding a hollow service. As real CRUD lands, this assertion graduates to real persisted state.
- **The second test verifies effects where they land.** `svc.db` is the package's managed client on the *same* database the service uses — it runs `psql` inside the container, so there is no second connection to open and nothing to tear down. One `query_value` asserts the migrations table shows a successful run. Probing the API and inspecting the store are two halves of one acceptance claim.

Note what the tests do *not* contain: no setup, no cleanup, no sleeps, no port numbers. Each test is two or three lines of intent; the fixture owns the machinery.

## Run it

The example directory carries its own manifest, so run it from there:

```shell
cd examples/service-grpc-postgres && prova
```

```text
· service_grpc_postgres › inventory gRPC service (Postgres) › boots against real Postgres and serves its gRPC API
· service_grpc_postgres › inventory gRPC service (Postgres) › ran its migrations against that same Postgres
```

First run fetches the package, clones the archetype, and downloads crates, so give it time; teardown then stops the service, closes the clients, removes the container, and deletes the temp dirs — in exactly the reverse of the order they were created.

## The pattern, portable

Swap the pieces and the shape holds for any system:

1. **Bring it into existence** — `archetect.render`, a `git clone`, or your checked-out repo; build with `shell.run` (pass `check = true` so a failed build aborts with its own stderr).
2. **Provision dependencies** — the [official packages](/docs/packages/official-packages) (`postgres.container`, `mysql.container`, `pulsar.container`, …), one line each; for anything without a package, [build it from primitives](./building-from-primitives.md).
3. **Gate on real readiness** — `wait` options, `prova.retry`, [`http.wait_for`](../reference/modules/http.md) or `grpc.wait_for`; never `sleep`.
4. **Boot on dynamic ports** — `net.free_port()` plus `shell.spawn` under `ctx:manage`. When a boot goes wrong, `proc:output()` hands you everything the process said — no blind failures.
5. **Probe from the outside** — [`http`](../reference/modules/http.md), [`grpc`](../reference/modules/grpc.md), [`graphql`](../reference/modules/graphql.md), or the CLI itself via `shell.run`.
6. **Cross-check state where it lands** — each package's `client` (`query_value`, `execute`) against the very store the service is wired to.

When several files need the same expensive stack, promote the fixtures into a [suite](./suites-and-shared-state.md) and provision once for all of them.

## Choosing a driver

The rule: **drive the contract under proof with the protocol of that contract**. A gRPC API through
a gRPC client, a CLI through its argv, a file effect through the filesystem. Green must mean that a
real caller would succeed. `prova learn drivers` carries the same table in the binary.

| Contract under proof | Driver |
|---|---|
| HTTP/REST | `http.get` / `http.post`, `http.client{ base_url }`, `http.wait_for` |
| gRPC | `grpc.client(addr)` → `:call`, `:call_status` (needs server reflection), `grpc.wait_for` |
| GraphQL | `graphql.client{ url }` → `:query`, `:execute` |
| WebSocket | `websocket.connect(ctx, { url })` → `:send`, `:recv` |
| A CLI or process | `shell.run(argv, { cwd, env, timeout, check })`, `shell.spawn` for long-running ones |
| A stdio conversation (MCP, LSP, a REPL) | `stdio.spawn(ctx, { cmd, framing, codec })` → `:send`, `:recv{ where }`, `:expect` |
| A byte stream (tcp, unix) | `socket.connect(ctx, { addr, framing, codec })` |
| An interactive TUI | `terminal.spawn(ctx, { cmd, cols, rows })` → `:send`, `:expect`, `:screen()` |
| State where it lands | a resource package's `client`, `sqlite.client`, `fs` |

Reach for `stdio.spawn` whenever the next thing you send depends on what came back.
`shell.run{ stdin = … }` writes one string before the program starts, so it cannot express an
exchange:

```lua
local s = stdio.spawn(t, { cmd = { "./my-mcp-server" }, framing = "line", codec = "json" })
s:send({ jsonrpc = "2.0", id = 1, method = "initialize", params = {} })
local reply = s:recv({ where = { id = 1 } })   -- reads past notifications to the matching turn
t:expect(reply.result.serverInfo.name):equals("my-mcp-server")
```

Every stream driver shares one turn model: `framing` cuts bytes into turns (`"line"`,
`"content_length"`, a delimiter, a length prefix), `codec = "json"` decodes them, and `recv{ where }`
reads on until a turn matches, using the same structural subset match as `:matches`. Use
`terminal.spawn` only when the program needs a real pty; a pty mangles a byte protocol through line
discipline and column wrapping.

### TLS, the same way everywhere

Every network driver reaches a TLS endpoint the same way: an `https://` or `wss://` URL, plus at
most one of two options.

| Option | Means |
|---|---|
| `insecure = true` | accept any certificate: no chain, hostname or expiry check. Right for a service you just booted with a self-signed certificate; the connection is still encrypted, only identity goes unchecked. |
| `ca_cert = "<path>"` | a PEM whose certificates are **added** to the default trust anchors, for an endpoint behind a private CA |

```lua
http.get("https://127.0.0.1:" .. port .. "/health", { insecure = true })
local api = http.client{ base_url = "https://api.internal", ca_cert = "certs/internal-ca.pem" }
local rpc = grpc.client("api.internal:443", { tls = true, ca_cert = "certs/internal-ca.pem" })
```

Setting both is an error at every call site, because together the CA would go unchecked while the
proof still reads as pinned. gRPC addresses usually have no scheme, so `tls = true` promotes a bare
`host:port`; `insecure` and `ca_cert` imply TLS on their own, and pairing either with an `http://`
address is refused.

## The pattern, in the wild

Production suites read even quieter than the walkthrough. This fixture is from a real archetype acceptance suite (a .NET REST service, rendered per database variant and proven against Postgres *and* MySQL from one loop) — note `check = true` on the build instead of an assert dance, and the package resource's `host`/`port` wired straight into env as plain scalars, numbers included:

```lua
  local service = prova.fixture(label .. ":service", Scope.File, function(ctx)
    local root = ctx:use(project):dir("example-service")
    local db = v.db.container(ctx)

    shell.run("dotnet build ExampleService.sln -c Release", {
      cwd = root.path, timeout = "600s", check = true,
    })

    local port, mgmt = net.free_port(), net.free_port()
    ctx:manage(shell.spawn("dotnet ExampleService.dll", {
      cwd = root.path .. "/ExampleService/bin/Release/net9.0",
      env = {
        Port           = port,
        ManagementPort = mgmt,
        DbHost         = db.host,
        DbPort         = db.port,
        DbUsername     = "prova",
        DbPassword     = "prova",
        DbDbname       = "prova",
      },
    }))

    local api = http.client{ base_url = "http://127.0.0.1:" .. port }
    -- Readiness proves the chain: the app only serves after EnsureCreated succeeded against the DB.
    api:wait_for("/health/readiness", { timeout = "60s" })
    return { api = api, db = db.client }
  end)
```

`shell.run`'s `check = true` raises on a non-zero exit with the command's own stderr — use it whenever a failure should simply abort the fixture. And env values coerce from the scalars tests naturally hold (ports are numbers), so there is never a `tostring()` around the wiring. Tests then drive REST CRUD through `svc.api` and prove every row in `svc.db` — same two halves, any stack.
