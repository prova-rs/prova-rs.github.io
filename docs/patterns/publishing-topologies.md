---
sidebar_position: 5
---

# Publishing Topologies

Most packages hand out clients — `require("postgres").container(ctx)` and you have a database.
This pattern is one step up: a package that advertises a **whole environment**. The team that owns
"the orders stack" — its stores, its bus, their wiring — publishes it once, and every consuming
repo gets the same stack as a proof fixture, a `prova up` dev environment, and a transitive set of
pinned resources. The working example is public: the
[kitchen-sink reference](https://github.com/prova-rs/reference-kitchen-sink), which publishes an
`orders` topology and proves it against real daemons. This page extracts its shape.

## Advertise it in the package's manifest

The package exports the factory as an ordinary namespace function, and the manifest names it
under `[[package.topologies]]`:

```toml
[package]
name = "kitchen"

[[package.topologies]]
name     = "orders"
factory  = "orders"          # kitchen.orders(ctx, opts)
requires = ["docker"]        # gates both proofs and `prova up` on a bare machine
```

```lua
-- init.lua — the factory is deliberately heterogeneous (see below)
function kitchen.orders(ctx, opts)
  local database = (opts and opts.database) or "orders"
  return {
    orders      = require("postgres").container(ctx, { database = database }),
    fulfillment = require("mysql").container(ctx, { database = database }),
    bus         = require("pulsar").container(ctx),
    network     = ctx.network,   -- so a consumer's SUT container can join the stack
  }
end
```

## Register it in the consumer's manifest

A consumer pins the package and registers the advertised name in its
[`[topologies]` table](../reference/prova-toml.md#topologies--environments-addressable-by-name):

```toml
[dependencies]
kitchen = "prova-rs/reference-kitchen-sink@v1"

[topologies]
orders = { package = "kitchen", topology = "orders" }
```

**Transitive dependencies are the payoff here.** The consumer declares only `kitchen`; the
postgres, mysql, and pulsar packages are `kitchen`'s own `[dependencies]`, resolved transitively
and pinned by the topology's owner. Three daemons' worth of provisioning arrives as one line, and
the versions are a fact about the topology, not something every consumer restates.

## Two doors, one factory

The registration serves the inhabited verbs — `prova up orders`, `start`, `down`, `ps` — which
resolve topologies **only** from `[topologies]` and never scan proof files. A proof, meanwhile,
builds the *same exported factory* as a fixture:

```lua
local kitchen = require("kitchen")

local orders = prova.topology("orders", kitchen.orders)

prova.test("the composed stack comes up and every resource answers",
  { requires = { "docker" } }, function(t)
  local env = t:use(orders)
  t:expect(env.orders.client:query_value("SELECT 1"), "postgres answers"):equals(1)
  t:expect(env.fulfillment.client:query_value("SELECT 1"), "mysql answers"):equals(1)
  t:expect(env.bus.url, "pulsar advertises a broker url"):matches("pulsar://")
end)
```

Two doors, one factory: the proof and the held environment both name `kitchen.orders`, so **they
cannot drift**. That is the rule that makes the pattern work — the factory lives in the package
and is addressed twice, never copied. A `prova.topology(...)` whose body is written inline in a
test file is a private fixture; exporting it is what makes it publishable.

## The dual-vantage contract — proven, not assumed

Every resource in a topology is dual-homed
([auto-networking](../writing-tests/topologies.md#auto-networking-and-the-two-vantages)):
`res.url` is the host vantage — loopback plus a mapped port, what the test runner dials — and
`res.network.url` is the in-network vantage — a DNS alias plus the container port, what a
containerized consumer dials. Wiring an app container to `res.url` is the classic mistake, and it
is a quiet one: the suite still passes, because the *runner* really can reach that address.

A published topology should therefore prove each vantage **as the other's control**:

```lua
-- A throwaway container joined to the topology's network stands in for the SUT.
local sut = t:manage(docker.run{ image = "postgres:16-alpine",
                                 network = env.network, command = "sleep 300" })

-- Positive: the alias answers a real query from a sibling container.
local out = sut:run({ "env", "PGPASSWORD=prova",
  "psql", "-h", "postgres", "-U", "prova", "-d", "orders", "-tAc", "select 42" })
t:expect(out, "postgres answered a sibling container"):contains("42")

-- Negative: the host-mapped port is NOT reachable from inside the network —
-- 127.0.0.1 in there is the SUT itself. Proving this fails is what makes the
-- positive proof mean something.
local port = env.orders.url:match(":(%d+)/")
local ok = pcall(function() return sut:run({ "nc", "-z", "-w", "3", "127.0.0.1", port }) end)
t:expect(ok, "loopback inside the container does not reach the host-mapped port"):is_falsy()
```

The positive half proves the alias routes to a live service — a real query, not a DNS lookup.
The negative half proves the two vantages are genuinely different addresses, so a consumer wired
to the wrong one fails in *their* suite instead of in production.

## Compose deliberately heterogeneous resources

The kitchen-sink stack mixes Pulsar (tens of seconds to boot) with Postgres (about one) on
purpose. A single-resource topology proves almost nothing about composition — it cannot surface a
port collision, readiness interleaving between slow and fast starters, or a teardown that only
misbehaves when siblings exist. Those are the failures a *published* environment must be immune
to, because its consumers will hit them at scale. Composition is the point: pick resources with
different boot profiles, and let the topology's proofs hold the whole ensemble.

## Rules that make it work

- The factory is **exported from the package** and addressed by both doors; never duplicated.
- `requires` on the advertisement gates every verb the same way — a machine without Docker skips
  rather than fails, which keeps the package's own suite honest on a bare runner.
- Return `ctx.network` from the factory so consumers can join their system under test to the
  stack and be handed the in-network vantage.
- Prove both vantages, each as the other's control.
- Self-pin `{ path = "." }` in the package's manifest, but pin the *resource* packages to
  released tags — a topology package exists to exercise the ecosystem as shipped.
