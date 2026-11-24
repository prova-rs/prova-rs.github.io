---
sidebar_position: 10
---

# Topologies

A **topology** is a named, wired bundle of resources — a seeded database, a cache, the app that connects them — declared once and consumed by *multiple verbs*. Your tests `use` it like any fixture; `prova up <name>` stands the identical environment up for you to develop against; `prova start`/`down`/`ps` manage it detached; and it is the same topology an [MCP client holds warm](../reference/cli.md#warm-topology-tools-mcp-only) so an agent's re-runs land in milliseconds. **One definition powers your tests, your dev environment, and warm MCP re-runs, so they cannot drift.**

That is the problem topologies exist to kill: today a compose file, a testcontainers setup, and your test fixtures are separate descriptions of "the same" environment that silently diverge. Prova collapses them to one.

## Declaring a topology

`prova.topology(name, [scope,] fn)` is `prova.fixture` with two differences: the default scope is `Scope.File` (provisioned once, shared across the file's tests), and the definition is **addressable by name** from the command line.

```lua
local postgres = require("postgres")
local redis = require("redis")

local orders = prova.topology("orders", function(ctx)
  -- Postgres, seeded, so `prova up orders` hands you a ready-to-use database.
  local db = postgres.container(ctx, { database = "orders" })
  db.client:execute("CREATE TABLE orders (id int primary key, sku text, qty int)")
  db.client:execute("INSERT INTO orders (id, sku, qty) VALUES (1, 'widget', 3)")

  -- Redis, wired to the same environment and seeded too.
  local cache = redis.container(ctx)
  cache.client:set("orders:1:sku", "widget")

  return { db = db, cache = cache } -- each is { client, url, container }; `up` prints their `url`s
end)
```

Nothing in the body knows which verb runs it. `ctx:manage` (inside the packages' `.container`) declares *"I own this resource's lifecycle"*; **when** teardown happens belongs to the scope, and the scope's lifetime is set by the verb — test-end for a run, Ctrl-C or `prova down` for a held environment. Same code, one teardown path.

## Registering it: two doors

A topology has two kinds of consumer, and they enter differently:

- **A test** builds one in-process with `prova.topology(...)`. That is a fixture, local to the file
  that declares it.
- **The inhabited verbs** (`up`, `start`, `down`, `ps`, and the MCP `up` tool) stand up a
  **registered** factory, resolved from the manifest's `[topologies]` table and nowhere else. They
  do not load or scan proof files.

So to get both, export the factory from a package and register it; a test then builds that same
factory as its fixture, and the two cannot drift:

```toml
[topologies]
orders = { package = "kitchen", topology = "orders", startup = "5m" }
vm     = { package = "parallels", topology = "vm", options = { image = "ubuntu-24.04" } }
```

```lua
local orders = prova.topology("orders", require("kitchen").orders)   -- the registered factory
```

`options` is passed to the factory as its second argument, and a registered topology inherits the
`requires` its package advertises, so it gates on the environment it needs.

**`startup = "15m"`** says how long the topology needs to come up. `prova start` relays the holder's
progress and waits that long (default 300 seconds; `--timeout` overrides it once). A kind cluster with
eight rollouts honestly takes minutes, and the definition should say so. When the budget expires, the
holder stops gracefully, as on Ctrl-C, and releases what it created.

**`scope = "run"`** shares one instance across the whole run. Without it, five files that each declare
an eleven-container stack build 55 containers to answer one question. With it, the run provisions the
topology once, holds it, and reaps it after the last file; a `prova start`ed holder still takes
precedence. It is opt-in per registration because of two trades: state accumulates across files, and
each file sees the topology as **data** (urls, hosts, ports), because a `client` object cannot cross
between Lua states.

`prova up <git-url>` stands up a topology a remote repository advertises, without cloning it by hand.

## Auto-networking and the two vantages

A topology **auto-creates a user-defined Docker network** and joins every resource to it, aliased by the resource's name. So containers reach each other **by name, container-to-container**, with no host round-trip — the app connects to `db:5432`, not to a mapped host port. You get container DNS for free, without calling [`docker.network`](../reference/modules/docker.md#dockernetworkopts) yourself.

That gives every resource **two addresses**, and the distinction matters the moment a containerized app is in the topology:

| Field | Who uses it | Example |
|---|---|---|
| `res.host` / `res.port` / `res.url` | the **test** process, over loopback | `127.0.0.1:54321` |
| `res.network` (`{ url, host, port }`) | a **sibling container** on the topology network | `db:5432` |

So when you wire a [containerized system under test](../reference/modules/docker.md#dockerbuildopts) (built with `docker.build`) to its database, you inject the **network** vantage — the app is a container, and a container reaches the db by its network alias:

```lua
local app = prova.topology("app", function(ctx)
  local db = postgres.container(ctx, { database = "orders" })
  local image = docker.build{ context = prova.root }        -- the SUT's own Dockerfile
  local sut = ctx:manage(docker.run{
    image = image, ports = { 8080 },
    env = { DB_URL = db.network.url },                       -- the SIBLING address, not loopback
    wait = { port = 8080, timeout = "60s" },
  })
  return { db = db, sut = sut }
end)
```

The test still probes `sut` over loopback (`sut:endpoint(8080)`); only the container-to-container wiring uses `.network`.

## Consuming it from tests

In test mode a topology is exactly a fixture — `t:use(handle)`:

```lua
prova.group("orders topology", { requires = { "docker" } }, function(g)
  g:test("the database comes up seeded", function(t)
    local e = t:use(orders)
    t:expect(e.db.client:query_value("select count(*) from orders")):equals(1)
  end)

  g:test("the cache is wired to the same environment", function(t)
    local e = t:use(orders) -- File-scoped: the same instance the sibling test used
    t:expect(e.cache.client:get("orders:1:sku")):equals("widget")
  end)
end)
```

## Consuming it from the command line

From the project directory, once the topology is [registered](#registering-it-two-doors) in the manifest:

```shell
prova                  # run the assertions against it (provision → assert → tear down)
prova up orders        # stand it up, print endpoints, hold until Ctrl-C
prova start orders     # stand it up detached; `prova ps` to list, `prova down orders` to stop
```

`prova up` provisions the named topology under a held scope, prints each resource's endpoint, and blocks until Ctrl-C, then runs the same `ctx:manage` teardown a test run would. The `url` field of the resource grammar pays off here: the printed endpoint *is* the connect string — `psql` or `redis-cli` straight into it.

```text
  orders — up:
    db     postgres://dev:dev@127.0.0.1:54321/orders
    cache  redis://127.0.0.1:54322

  holding — Ctrl-C to tear down
```

## Port modes

The definition is written once; the **verb** picks the port strategy:

- **Tests** and plain `prova up` use **random host ports** — parallel-safe, so suites and several held topologies coexist on one machine without collisions.
- **`--fixed`** (on `up` and `start`) pins each resource to its **canonical container port** on the host — postgres on `5432`, redis on `6379` — a predictable address for external tools, at the cost that only one fixed instance of a port runs at a time.

```shell
prova up orders --fixed      # postgres on 5432, redis on 6379
prova start orders --fixed   # the same, detached
```

## The detached lifecycle

`prova up` holds your terminal. When you want the environment to outlive the shell:

```shell
prova start orders     # spawns a detached holder, waits for it to come up, prints endpoints
prova ps               # name, status, pid, uptime, endpoints
prova down orders      # SIGTERM the holder — the same in-process teardown as Ctrl-C
```

`start` is a thin supervisor over attached `up`: it spawns `prova up orders` in its own process group with output going to a log file, waits for it to self-register, and returns. Every running topology records itself under `<home>/running/<name>.json` (pid + endpoints; the directory is self-gitignored) with its output in `<name>.log` alongside — that record is what `ps` lists and `down` signals. There is **one provisioning path and one teardown path**: `down` never re-implements cleanup, it just triggers the holder's own.

Standing up a topology that is already up is refused; stale records (the holder died) are cleaned up automatically by `ps`, `up`, and `down`.

## Run it

The full example ships in the Prova repository as [`examples/topology`](https://github.com/prova-rs/prova/tree/main/examples/topology) — the `orders` definition above, its tests, and a manifest declaring the postgres and redis packages. The verb-by-verb flag reference lives in the [CLI reference](../reference/cli.md#topology-verbs-up-start-down-ps).
