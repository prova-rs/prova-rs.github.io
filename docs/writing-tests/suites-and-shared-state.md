---
sidebar_position: 6
---

# Suites & Shared State

A **suite** is a named group of test files that share **one Lua state**. That single sentence buys you the thing acceptance suites need most: a `Scope.Suite` fixture — a live database connection, a running container handle — provisioned *once* and shared across every file in the suite, with zero serialization. Suites are also the unit of parallelism and isolation: suites run in parallel, each in its own state, so a file in one suite can never see another suite's infrastructure.

By default, nothing changes: **a file not assigned to any suite is its own one-file suite.** Files parallelize as before, and within a singleton suite `Scope.Suite` and `Scope.File` coincide — which is correct, not a lie: the suite *is* the file.

## Declaring a suite: the `suite.lua` marker

Drop a `suite.lua` into a directory and that directory becomes one suite owning every `*_test.lua` in its subtree. The marker file runs **once, first, in the suite's shared state** — it is where suite-scoped fixtures and suite config live, colocated with the files that use them:

```lua
-- examples/suite/suite.lua — runs once for the whole suite, before any test file
suite.config{ name = "orders", requires = { "docker" } }

-- ONE Postgres for the whole suite — provisioned once, torn down once, shared by every file below.
prova.fixture("db", Scope.Suite, function(ctx)
  return require("postgres").container(ctx, { database = "orders" }).client
end)
```

The `postgres` here is a [plugin](/docs/plugins/), declared in the directory's own `prova.toml` and attached with `require`:

```toml
[run]
paths = ["."]

[plugins]
postgres = "prova-rs/prova-postgres@main"
```

`suite.config` takes two fields:

| Field | Effect |
|---|---|
| `name` | Display name for the suite (defaults to the directory name) |
| `requires` | [Capabilities](./dependencies-and-scheduling.md) gating the **whole suite** — unmet, every file skips, reported once |

## Consuming suite fixtures: the string form of `use`

Fixture handles are per-state Lua values, so a handle defined in `suite.lua` cannot be imported across file boundaries — but a *name* can, and the value behind it is one shared instance in the suite state. Test files reference suite fixtures **by name**:

```lua
-- examples/suite/a_create_test.lua
prova.test("creates the schema and inserts a row", function(t)
  local c = t:use("db")            -- the suite's shared client (built once, reused)
  c:execute("CREATE TABLE IF NOT EXISTS orders (id BIGINT PRIMARY KEY, sku TEXT, qty INT)")
  c:execute("INSERT INTO orders (id, sku, qty) VALUES ($1, $2, $3)", { 1, "widget", 3 })
  t:expect(c:query_value("SELECT count(*) FROM orders")):equals(1)  -- query_value coerces numerics
end)
```

```lua
-- examples/suite/b_read_test.lua — a DIFFERENT file, the SAME Postgres
prova.test("reads the row inserted by the other file in the suite", function(t)
  local c = t:use("db")
  t:expect(c:query_value("SELECT sku FROM orders WHERE id = $1", { 1 })):equals("widget")
  t:expect(c:query_value("SELECT qty FROM orders WHERE id = $1", { 1 })):equals(3)
end)
```

The second file sees the row the first inserted — one container for the suite, one teardown at the end. That cross-file shared state is exactly what a suite is for. The clean contract: `suite.lua` *defines* named fixtures; test files *consume* them by name. (Within a single file, keep preferring the [typed handle form](./fixtures.md) — the string form is the cross-file escape hatch.)

Files within a suite load and run in sorted order, which is why the example files are prefixed `a_` and `b_`. Lean on that only for genuinely sequential data setup; for explicit prerequisites within a file, use [`depends_on`](./dependencies-and-scheduling.md).

## Scope semantics inside a suite

Every scope stays meaningful — the suite just widens the outermost ring:

| Scope | Lifetime within a suite |
|---|---|
| `Scope.Test` | rebuilt per test, torn down per test |
| `Scope.Flow` | once per flow, shared across its steps |
| `Scope.File` | once per **file** — each file gets its own instance, even though all files share one state |
| `Scope.Suite` | once for the whole suite — a live cached value, torn down once at suite end |

File scopes tear down after the suite's tests finish, before the suite scope — inner to outer, as always, so a `Scope.File` fixture can safely depend on a `Scope.Suite` one.

## Parallelism and lifecycle

- [`--jobs`](../running-prova/command-line.md) is the number of **concurrent suites**. Each worker gets its own Lua state; within a suite, I/O-bound tests still overlap cooperatively.
- Suite teardown runs once, after the suite's last test: containers stopped, connections closed — no leaks, no double-provisioning.
- Isolation falls out of the model: two suites never share a state, so they cannot share (or corrupt) each other's fixtures.

Run a suite by pointing Prova at its directory (or, when the suite ships its own manifest like this example does, from inside it):

```shell
cd examples/suite && prova
```

## Manifest suites: `[suites.*]`

When the grouping does not match the directory tree — cross-cutting collections, a shared setup file living elsewhere — declare the suite explicitly in `prova.toml`:

```toml
[suites.grpc]
paths = ["services/grpc"]
setup = "services/grpc/suite.lua"   # optional; where the suite's fixtures + config live
```

The declared `paths` are discovered into one suite sharing the optional `setup` file. See [Manifest & Profiles](../running-prova/manifest-and-profiles.md) for the full manifest surface.

:::tip
Reach for a suite when a fixture is *expensive* (a container, a compiled service) and *reused across files*. If only one file needs it, `Scope.File` in that file is simpler — and if every file provisions its own cheap copy anyway, singleton files parallelize better.
:::

## Next

You now have every building block. The capstone, [Testing Real Systems](./testing-real-systems.md), assembles them into a full acceptance test against real infrastructure.
