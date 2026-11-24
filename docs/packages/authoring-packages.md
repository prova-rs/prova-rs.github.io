---
sidebar_position: 2
---

# Authoring Packages

A Prova package is a Lua module that builds a namespace and `return`s it. There is no native code, no FFI, no build step: a resource package provisions an ephemeral container through `prova.containerized`, and its "client" is a thin wrapper that drives the **CLI already inside the image** via `container:run`, parsing the output with `prova.parse.*`. This page covers the full authoring surface, then walks the real [prova-postgres](https://github.com/prova-rs/prova-postgres) package end to end.

## Scaffold it: `prova init package`

Don't start from a blank file — render the package archetype:

```bash
prova init package --headless -a name=redis
```

One archetype, two shapes, decided by **where** you run it:

- **Inside an existing package** it scaffolds a *local* package into the project's `packages` directory (core files only) — `require("redis")` works with zero declaration.
- **Outside a package** — or with `-s standalone` anywhere — it scaffolds a repo-ready *standalone* package (core plus LICENSE and CI) that consumers pin as a git dependency.

The core is the same either way, so graduating local → standalone is a directory move.

## Package anatomy — one manifest, two hats

Every package is itself a prova package: its manifest is a `prova.toml` with a `[package]` section, and it self-tests with its own proofs.

```
prova-<name>/
├── prova.toml            # dual-role: run manifest + package declaration
├── init.lua              # the namespace table (entry point)
├── library/<name>.lua    # LuaCATS ---@meta stub — what makes your API visible to editors and prova.help()
├── proofs/
│   └── <name>.prova.lua  # the package's own acceptance proofs, run with `prova`
├── README.md
└── LICENSE
```

```toml
[package]
name        = "postgres"                 # canonical name — namespaces intra-package require()s
entry       = "init.lua"                 # resolution: consumer module= → entry → init.lua → <name>.lua
description = "PostgreSQL — docker-exec over psql, zero native code"
license     = "MIT"

# The range of prova versions this package is built against; consumers are checked at resolve time.
[requires]
prova = ">= 0.17"

# Resolve THIS package from its own directory, so the self-tests `require("postgres")` exactly as
# a consumer would. A consumer instead pins it by source — a released tag.
[dependencies]
postgres = { path = "." }
```

- `entry` decouples resolution from the consumer's alias: `mq = "acme/prova-rabbitmq@v1"` still finds the right file. Without it, resolution falls back to `init.lua`, then `<alias>.lua` — which breaks under any other alias.
- A package may advertise **topologies** by name — `[[package.topologies]]` with `name`, `factory`, and the `requires` the environment needs — so a consumer's `[topologies]` table (and `prova up`) can address them. See [Topologies](../writing-tests/topologies.md).
- **Private dependencies:** a `[dependencies]` table in the package's own `prova.toml` is isolated from consumers — packages compose without a resolver and without version bleed.

## The contract

- Return **one namespace table**. Calls are context-first: `postgres.container(ctx, opts)`.
- Resource packages follow the **facet grammar** — `client` / `container` / `wait_for` / `mock` — so consumers already know your shape before reading your README.
- Lifecycle goes through the context: `ctx:manage(handle)` for anything with `:stop()`/`:close()`; never leak a process or container past the scope.
- A verb that changes provisioned state returns only when the change is observable **through the seam the consumer will use** — the provisioner's exit code is not that seam. `prova.retry` the consumer-visible check; a CLI that "completed" may have handed off to a store that syncs later.
- Ship `library/<name>.lua` (`---@meta <name>`) — it is what makes your API answerable in editors and to `prova.help()`; `prova package lint` warns without it.

## `prova.containerized`

The keystone. `prova.containerized(spec)` turns a compact spec into a grammar-conformant namespace — first-party recipes and third-party packages are authored the same way and come out the same shape:

```lua
local myresource = prova.containerized{
  name = "myresource", image = "vendor/image", tag = "1.2", port = 5432, timeout = "60s",
  env = function(opts) return { USER = opts.user or "prova" } end,
  url = function(host_port, opts) return "scheme://127.0.0.1:" .. host_port end,
  client = function(url, opts, container) return make_client(container) end,
}
return myresource
```

### Spec fields

| Field | Type | Description |
|---|---|---|
| `name` | `string?` | Namespace name, used in error messages (default `"resource"`). |
| `image` | `string` | **Required.** Base image repo (e.g. `"postgres"`). A caller's `opts.image` fully overrides (including tag). |
| `tag` | `string?` | Default image tag; a caller's `opts.tag` overrides. |
| `port` | `integer?` | The primary published container port — used for the readiness probe and passed to `url`. Required unless `ports` is given. |
| `ports` | `integer` \| list | Ports to publish. Each entry is a number (mapped to a **random** host port) or `{ container = N, host = M }` for a **fixed** host port (e.g. Kafka's advertised listener). The first entry is the primary when `port` is absent. |
| `command` | `string?` | Optional container command. |
| `env` | table \| `fun(opts) → table` | Container environment. As a function it receives the caller's `opts`, so defaults like `opts.user or "prova"` live in one place. |
| `wait` | `{ port?, log? }` | Readiness probe; default `{ port = <primary> }`. `log` waits for a log line instead. |
| `timeout` | `string?` | Readiness deadline, default `"60s"`; a caller's `opts.timeout` overrides. |
| `url` | `fun(host_port, opts) → string` | **Required.** Builds the connection URL from the mapped host port — the string handed to the app under test. |
| `client` | `fun(url, opts, container) → handle?` | Optional client factory. Receives the **container** too, so a docker-exec client can exec into it (a native client would just use `url`). Omit it and the resource is provision-only (black-box). |
| `extra` | `fun(url, opts, container) → table?` | Additional resource fields beyond the standard shape (e.g. S3 credentials). Merged into the result; `client`/`url`/`container`/`host`/`port` are reserved. |

### What it generates

The returned namespace is `{ client = spec.client, container = <generated> }`. The generated `container(ctx, opts?)`:

1. resolves image/tag/env/timeout (caller `opts` win over the spec),
2. provisions via `docker.run` with the published ports and the readiness `wait`,
3. **ties teardown to the scope** with `ctx:manage` — the container is removed when the fixture's scope ends,
4. builds `url` from the primary port's mapped host port, and
5. if the spec has a `client` factory, wraps it in `prova.retry` (raising factories retry until the deadline — this is where "the port is open but the service isn't really ready" is absorbed) and manages the handle with `ctx:manage`.

It returns the **standard resource shape**:

| Member | Type | Description |
|---|---|---|
| `client` | handle | The managed client — only present when the spec has a `client` factory. |
| `url` | `string` | The connection URL that reaches the instance — inject it into the app under test's environment. |
| `container` | `Container` | The managed [container handle](../reference/modules/docker.md#container). |
| `host` | `string` | Always `"127.0.0.1"` — the primary endpoint's host, split out so env wiring is `DB_HOST = res.host`. |
| `port` | `integer` | The primary endpoint's mapped **host** port — `DB_PORT = res.port`, no `host_port()` ceremony. |

Plus any fields the spec's `extra` returned.

## The docker-exec toolkit

### `container:run(cmd, opts?)`

The exec-CLI SDK entry point: run a command inside the provisioned container, raise on a non-zero exit, return stdout.

```lua
container:run({ "psql", "-U", "prova", "-tAc", sql })              -- argv: no shell, no quoting
container:run("redis-cli ping")                                    -- string: via `sh -c`
container:run({ "mc", "pipe", "local/bucket/key" }, { stdin = content })  -- pipe stdin
```

Prefer the **argv table** form — arguments pass verbatim with no shell interpolation, so SQL with quotes and spaces just works. `opts.stdin` feeds standard input (how the Kafka console producer and `mc pipe` are driven) without hand-rolled `printf | ...` piping. For the low-level variant that never raises, `container:exec(cmd)` returns `(exit_code, stdout, stderr)`.

### `prova.parse.*`

A CLI gives you text back; these turn the common shapes into Lua values so packages never hand-roll parsing:

| Function | Returns |
|---|---|
| `prova.parse.lines(s)` | Non-empty, trimmed lines — line-oriented CLIs. |
| `prova.parse.rows(s, sep?)` | A list of rows, each a list of columns split on `sep` (default tab) — TSV, psql's `\|`, CSV. |
| `prova.parse.table(s, sep?)` | First non-empty line is a header row; each remaining row becomes a map keyed by header name (e.g. `rabbitmqadmin`'s TSV). |

For the one-object-per-line `--json` streams many CLIs emit, combine `prova.parse.lines` with `json.decode`.

## Self-testing

**Packages are self-testing.** The self-pin in the manifest above resolves the package from its own directory, and `proofs/` runs against it — CI for a package is just `prova`:

```lua
-- proofs/postgres.prova.lua — provision, then round-trip through the docker-exec client
local db = prova.fixture("postgres", Scope.File, function(ctx)
  return require("postgres").container(ctx, { database = "orders" })
end)

prova.group("postgres", { requires = { "docker" } }, function(g)
  g:test("ddl + insert + scalar + rows round-trip", function(t)
    local c = t:use(db).client
    c:execute("CREATE TABLE items (id int, name text)")
    c:execute("INSERT INTO items VALUES (1, 'alpha'), (2, 'beta')")
    t:expect(c:query_value("SELECT count(*) FROM items")):equals(2)
  end)
end)
```

(A *local* package under a project's `packages` directory is a nested-package boundary — its proofs stay out of the owning project's suite; run them from inside its directory.)

Two more pieces round out a published package:

- **`prova package lint <file>`** checks the module against the namespacing grammar (is it a resource with `client`/`container` facets, or a helper library?) and advises when a `library/` LuaCATS stub is missing.
- **Releases.** Tag versions so consumers can pin (`@v1`); once released, the [package registry](https://github.com/prova-rs/package-registry) can index it for `prova packages` discovery.

## Worked example: the Postgres package

[prova-postgres](https://github.com/prova-rs/prova-postgres) is about a hundred lines and exercises every part of the surface. The "database" container shape has one signature quirk: Postgres restarts once during first-boot init, so an open port is a **false positive** — the readiness gate must retry a real query.

The client is a docker-exec wrapper over `psql` — tuples-only, unaligned output (`-tA`) so stdout is just data:

```lua
-- Run one SQL statement via psql inside the container. PGPASSWORD passes via `env`
-- in the argv form of container:run — no shell, no quoting.
local function psql(container, conn, sql, params)
  return container:run({
    "env", "PGPASSWORD=" .. conn.password,
    "psql", "-U", conn.user, "-d", conn.database, "-tAc", bind(sql, params),
  })
end

local function make_client(container, conn)
  local client = {}
  function client:execute(sql, params)
    psql(container, conn, sql, params)
    return self
  end
  function client:query(sql, params)      -- psql -tA: rows newline-separated, columns |-separated
    return prova.parse.rows(psql(container, conn, sql, params), "|")
  end
  function client:query_value(sql, params)
    local rows = self:query(sql, params)
    return coerce(rows[1] and rows[1][1] or nil)
  end
  function client:close() end
  return client
end
```

(`bind` substitutes `$1`, `$2`, … with SQL-escaped params client-side — the psql CLI has no server-side prepared statements — and `coerce` turns canonical numeric strings back into numbers so `count(*)` reads as `5`, not `"5"`.)

The spec ties it together:

```lua
local postgres = prova.containerized{
  name = "postgres", image = "postgres", tag = "16-alpine", port = 5432, timeout = "60s",
  env = function(opts)
    return {
      POSTGRES_USER     = opts.user or "prova",
      POSTGRES_PASSWORD = opts.password or "prova",
      POSTGRES_DB       = opts.database or "prova",
    }
  end,
  url = function(hp, opts)
    return string.format("postgres://%s:%s@127.0.0.1:%d/%s",
      opts.user or "prova", opts.password or "prova", hp, opts.database or "prova")
  end,
  -- The factory execs into the container; `SELECT 1` is the readiness gate. It raises until
  -- a real query succeeds — prova.retry (inside the generated container) loops until it holds.
  client = function(_url, opts, container)
    local conn = {
      user     = opts.user or "prova",
      password = opts.password or "prova",
      database = opts.database or "prova",
    }
    local client = make_client(container, conn)
    client:query_value("SELECT 1")
    return client
  end,
}

return postgres
```

Note what the package **didn't** have to write: no `docker.run` call, no port mapping, no retry loop, no teardown registration, no URL plumbing — `prova.containerized` supplies all of it. The package contributes exactly the domain knowledge: the image, the env contract, the URL format, the client verbs, and the one readiness quirk.

Consumers then write:

```lua
local db = require("postgres").container(ctx, { database = "orders" })
db.client:execute("CREATE TABLE t (id int, name text)")
db.client:query_value("SELECT count(*) FROM t")     -- 0
-- db.url / db.host / db.port → the app under test's environment
```

For more shapes, read the other [official packages](./official-packages.md): Kafka (stdin-piped console producer, tools not on PATH), Pulsar (log-line readiness is also a false positive — retry a real produce), RabbitMQ (`prova.parse.table` over `rabbitmqadmin` TSV), S3/MinIO (multi-step client config, `--json` output, `extra` fields for credentials), and kind/Parallels (packages that advertise **topologies**).

:::tip[In the binary]
`prova learn package-authoring` carries this page's material in one screen, with your own package's facts filled in. It always matches the binary you are running.
:::
