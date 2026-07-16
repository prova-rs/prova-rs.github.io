---
sidebar_position: 2
---

# Authoring Plugins

A Prova plugin is a Lua file that builds a resource namespace and `return`s it. There is no native code, no FFI, no build step: the plugin provisions an ephemeral container through `prova.containerized`, and its "client" is a thin wrapper that drives the **CLI already inside the image** via `container:run`, parsing the output with `prova.parse.*`. This page covers the full authoring surface, then walks the real [prova-postgres](https://github.com/prova-rs/prova-postgres) plugin end to end.

## `prova.containerized`

The keystone. `prova.containerized(spec)` turns a compact spec into a grammar-conformant namespace — first-party recipes and third-party plugins are authored the same way and come out the same shape:

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

A CLI gives you text back; these turn the common shapes into Lua values so plugins never hand-roll parsing:

| Function | Returns |
|---|---|
| `prova.parse.lines(s)` | Non-empty, trimmed lines — line-oriented CLIs. |
| `prova.parse.rows(s, sep?)` | A list of rows, each a list of columns split on `sep` (default tab) — TSV, psql's `\|`, CSV. |
| `prova.parse.table(s, sep?)` | First non-empty line is a header row; each remaining row becomes a map keyed by header name (e.g. `rabbitmqadmin`'s TSV). |
| `prova.parse.json(s)` | A real JSON parse to Lua values (`null` → `nil`). Combine with `lines` for the one-object-per-line `--json` streams many CLIs emit. |

## `prova-plugin.toml` — the plugin manifest

The analogue of Archetect's `archetype.yaml`, at the plugin repo root. All fields are optional (a manifest-less plugin falls back to filename conventions), but a published plugin should declare at least `entry`:

```toml
[plugin]
name        = "postgres"                                        # canonical name — namespaces intra-plugin require()s
entry       = "postgres.lua"                                    # entry file, relative to the plugin root
description = "PostgreSQL — docker-exec over psql, zero native code"
license     = "MIT"

[requires]
prova = ">=0.2, <0.3"                                           # semver range the running prova must satisfy
```

- `entry` decouples resolution from the consumer's alias: `mq = "acme/prova-rabbitmq@v1"` still finds `rabbitmq.lua`. Without it, resolution falls back to `init.lua`, then `<alias>.lua` — which breaks under any other alias.
- `requires.prova` is a compatibility gate checked at resolve time. On 0.x the minor is the breaking axis, so `>=0.2, <0.3` means "any prova 0.2".
- Plugins are self-contained: they depend on Prova and its primitives, nothing else. There is no dependency resolver.

## Plugin repo anatomy

```
prova-<name>/
├── <name>.lua              # the plugin module — prova.containerized spec + docker-exec client
├── prova-plugin.toml       # manifest: name, entry, requires.prova, metadata
├── prova.toml              # self-test manifest (below)
├── tests/
│   └── <name>_test.lua     # the plugin's own acceptance tests, run with prova
├── library/                # optional but advised for a published plugin:
│   └── <name>.lua          #   LuaCATS ---@meta stub — synced into consumers' annotations/ for IDE completion
├── README.md
└── LICENSE
```

**Plugins are self-testing.** The repo's own `prova.toml` resolves the plugin from its directory and runs `tests/` against it — CI for a plugin is just `prova`:

```toml
[run]
paths = ["tests"]

[plugins]
postgres = { path = "." }        # a consumer would write "prova-rs/prova-postgres@v1" instead
```

```lua
-- tests/postgres_test.lua — provision, then round-trip through the docker-exec client
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

Two more pieces round out a published plugin:

- **`prova plugin lint <file>`** checks the module against the namespacing grammar (is it a resource with `client`/`container` facets, or a helper library?) and advises when a `library/` LuaCATS stub is missing.
- **The `library/<name>.lua` stub** (a `---@meta` file describing the namespace) is what Prova [syncs into consumers' `annotations/` folder](./using-plugins.md#ide-annotations), so `require("postgres")` autocompletes in their editors.

## Quickstart: `prova-plugin-archetype`

Don't start from a blank file — generate the whole repo:

```bash
archetect render https://github.com/prova-rs/prova-plugin-archetype.git
```

You'll be prompted for the plugin name, description, Docker image/tag, port, URL scheme, and the client CLI in the image. The result is a ready-to-author `prova-<name>/` with the module skeleton (a `prova.containerized` spec), manifest, self-test, starter test, license, and CI workflows to **test** (self-test + `prova plugin lint` on every push) and **release** (tag a version so consumers can pin `@vX.Y.Z`). Implement the client methods, then publish:

```bash
cd prova-<name>
git init && git add -A && git commit -m "Initial plugin"
gh repo create <org>/prova-<name> --public --source=. --push
```

## Worked example: the Postgres plugin

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

Note what the plugin **didn't** have to write: no `docker.run` call, no port mapping, no retry loop, no teardown registration, no URL plumbing — `prova.containerized` supplies all of it. The plugin contributes exactly the domain knowledge: the image, the env contract, the URL format, the client verbs, and the one readiness quirk.

Consumers then write:

```lua
local db = require("postgres").container(ctx, { database = "orders" })
db.client:execute("CREATE TABLE t (id int, name text)")
db.client:query_value("SELECT count(*) FROM t")     -- 0
-- db.url / db.host / db.port → the app under test's environment
```

For more shapes, read the other [official plugins](./official-plugins.md): Kafka (stdin-piped console producer, tools not on PATH), Pulsar (log-line readiness is also a false positive — retry a real produce), RabbitMQ (`prova.parse.table` over `rabbitmqadmin` TSV), and S3/MinIO (multi-step client config, `--json` output, `extra` fields for credentials).
