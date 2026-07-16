---
sidebar_position: 9
---

# Topologies

A **topology** is a named, wired bundle of resources — a seeded database, a cache, the app that connects them — declared once and consumed by *multiple verbs*. Your tests `use` it like any fixture; `prova up <name>` stands the identical environment up for you to develop against; `prova watch` re-applies it as you edit; `prova start`/`down`/`ps` manage it detached. **One definition powers both your tests and your dev environment, so they cannot drift.**

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

Nothing in the body knows which verb runs it. `ctx:manage` (inside the plugins' `.container`) declares *"I own this resource's lifecycle"*; **when** teardown happens belongs to the scope, and the scope's lifetime is set by the verb — test-end for a run, Ctrl-C or `prova down` for a held environment. Same code, one teardown path.

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

From the project directory (the topology is discovered in the manifest's test files):

```shell
prova                  # run the assertions against it (provision → assert → tear down)
prova up orders        # stand it up, print endpoints, hold until Ctrl-C
prova watch orders     # stand it up and re-apply on every edit to the definition
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
- **`--fixed`** (on `up`, `watch`, and `start`) pins each resource to its **canonical container port** on the host — postgres on `5432`, redis on `6379` — a predictable address for external tools, at the cost that only one fixed instance of a port runs at a time.

```shell
prova up orders --fixed      # postgres on 5432, redis on 6379
prova watch orders --fixed   # endpoints stay put across re-applies
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

## `prova watch` — the live dev loop

`prova watch orders` stands the topology up and **re-provisions it whenever its definition files change** — edit the seed data, save, and the environment re-applies. A broken edit is reported and the loop waits for the fix rather than exiting. It is attached-only; pair it with `--fixed` so your app's connection strings survive re-applies.

## Run it

The full example ships in the Prova repository as [`examples/topology`](https://github.com/prova-rs/prova/tree/main/examples/topology) — the `orders` definition above, its tests, and a manifest declaring the postgres and redis plugins. The verb-by-verb flag reference lives in the [CLI reference](../reference/cli.md#topology-verbs-up-watch-start-down-ps).
