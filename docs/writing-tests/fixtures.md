---
sidebar_position: 2
---

# Fixtures

Fixtures are the heart of Prova: named factories that produce a value, cache it for a declared scope, and tear themselves down deterministically. They are how you express "render this project once, share it across every test" or "give each test a fresh connection" without a line of manual bookkeeping. If you know pytest fixtures, you know the concept — Prova adapts it to honest Lua idioms: no decorators, no parameter-name reflection, explicit and typed.

## Declaring a fixture

`prova.fixture(name, scope, factory)` registers a factory and returns a **handle**:

```lua
local workspace = prova.fixture("workspace", Scope.File, function(ctx)
  return ctx:tempdir()               -- the fixture's value
end)
```

- `name` identifies the fixture (used for string-form lookup and in reports).
- `scope` is a typed constant — `Scope.Test`, `Scope.Flow`, `Scope.File`, or `Scope.Suite`. Omit it for `Scope.Test`.
- `factory(ctx)` builds the value. It receives a context for declaring teardown and depending on other fixtures.

The scope argument is a `Scope` value, not a string — your editor autocompletes the four options, and anything else is rejected with a clear error at collection time.

## Requesting a fixture: `ctx:use`

Injection is **explicit and lazy** via `use`. Pass the handle:

```lua
prova.test("renders into a clean workspace", function(t)
  local ws = t:use(workspace)        -- ws : string — the factory's return type flows through
  t:expect(ws):is_dir()
end)
```

Handle-based `use` is a deliberate, LSP-driven decision: `prova.fixture(...)` returns `prova.Fixture<T>`, and `ctx:use(handle)` recovers `T` at the call site — full completion and type-checking on fixture values once your editor is [set up](../running-prova/ide-setup.md). A bare string also works — `t:use("workspace")` — but it is untyped (`any`). The string form exists for cross-file lookup, and it is the standard contract inside [suites](./suites-and-shared-state.md), where a `suite.lua` defines named fixtures that sibling files consume by name.

Explicit `use` buys three things that parameter-name magic hides:

1. **Laziness** — a fixture is only built when something actually asks for it.
2. **Traceability** — grep for the handle or name to find every dependent.
3. **No collisions** between fixture names and local variables.

## Scopes, caching, and teardown

| Scope | Built | Cached for | Torn down |
|---|---|---|---|
| `Scope.Test` | first `use` in a test | that one test (per-**step** inside a flow) | immediately after the test/step |
| `Scope.Flow` | first `use` in a flow's steps | every step of that flow | after the flow's last step |
| `Scope.File` | first `use` in a file | every test in that file | at the end of the run — after the file's tests, before suite teardown |
| `Scope.Suite` | first `use` in the run | the whole run (or [suite](./suites-and-shared-state.md)) | last, after everything else |

Caching is **per scope instance**: two tests that both `use` a `Scope.File` fixture share one value and pay its cost once. A `Scope.Test` fixture is rebuilt fresh for every test. `Scope.Flow` is only valid inside a [flow](./flows.md) — using it elsewhere is an error.

Teardown is **LIFO within a scope**, and scopes tear down inner to outer (test, then flow, then file, then suite) — so dependencies always outlive their dependents. Teardown runs even when the test failed or timed out.

This example from the Prova repository proves all three scopes at once:

```lua
-- suite-scoped: constructed once for the whole run, torn down last.
local suite_dir = prova.fixture("suite_dir", Scope.Suite, function(ctx)
  local dir = ctx:tempdir()
  ctx:defer(function() ctx:log("suite_dir torn down") end)
  return dir
end)

-- file-scoped: one instance per test file; depends on the suite fixture.
local db = prova.fixture("db", Scope.File, function(ctx)
  local root = ctx:use(suite_dir)              -- fixture-to-fixture dependency
  ctx:defer(function() ctx:log("db closed") end)
  return { root = root, open_connections = 0 }
end)

-- test-scoped (default): fresh for every test.
local conn = prova.fixture("conn", Scope.Test, function(ctx)
  local database = ctx:use(db)                 -- same instance across this file's tests
  database.open_connections = database.open_connections + 1
  ctx:defer(function() database.open_connections = database.open_connections - 1 end)
  return database.open_connections
end)

prova.test("first test acquires connection #1", function(t)
  t:expect(t:use(conn)):equals(1)
end)

prova.test("second test also sees #1 — conn was torn down and rebuilt", function(t)
  t:expect(t:use(conn)):equals(1)
end)
```

## Fixture-to-fixture dependencies

Fixtures depend on other fixtures the same way tests do — capture the handle, `use` it:

```lua
local project = prova.fixture("project", Scope.File, function(ctx)
  return archetect.render{
    source = "examples/fixtures/rust-cli",
    answers = { project_name = "widget", description = "a demo cli" },
    destination = ctx:use(workspace),          -- typed, lazy, cached
    defaults = true,
  }
end)
```

One rule keeps the graph coherent: **a fixture may only use fixtures of equal or broader scope.** A `Scope.File` fixture can use a `Scope.Suite` one; the reverse is rejected with a scope-mismatch error, because a suite-lifetime value must never capture something that is torn down per file.

## Teardown tools

Three context members cover teardown, from most general to most convenient:

### `ctx:defer(fn)` — arbitrary cleanup, LIFO

Go-style: register any callback; it runs when the fixture's scope ends. Multiple `defer`s per fixture are fine and run last-registered-first. Deferred callbacks may perform async work (stopping a process, closing a connection) — teardown is driven asynchronously.

```lua
local server = prova.fixture("server", Scope.File, function(ctx)
  local proc = shell.spawn("./target/debug/app")
  ctx:defer(function() proc:stop() end)
  return proc
end)
```

### `ctx:manage(resource)` — lifecycle in one line

Most resources you provision expose `stop()` (containers, processes) or `close()` (connections). `manage` registers the right one for you and returns the resource, so provisioning and cleanup compose into a single expression:

```lua
local pg = ctx:manage(docker.run{ image = "postgres:16-alpine", ports = { 5432 } })
local conn = ctx:manage(postgres.client(url))
```

It is pure sugar over `defer`; a resource with neither method is an error, and `defer` remains for anything custom.

### `ctx:tempdir()` — scoped scratch space

Creates a directory that is removed automatically when the scope ends. This is *the* sanctioned scratch space — there is no implicit working directory to pollute:

```lua
local ws = ctx:tempdir()
fs.write(ws .. "/health", "ok")
```

All three target the **fixture's own scope**: a `Scope.File` fixture's `defer` runs at file teardown, its `tempdir` lives as long as the file. In a test body, `t:defer`, `t:manage`, and `t:tempdir` target the test's scope the same way.

:::tip
`ctx:log(msg)` attaches a log line to the current test or fixture — use it to make lifecycle events (built, torn down, retried) visible in the run output without polluting assertions.
:::

## Parametrization and autouse

:::note Planned
Parametrized fixtures (`opts.params` with `ctx:param()`, multiplying every dependent test across variants) and `autouse` fixtures (ambient setup that runs without being named) are on the [roadmap](../reference/roadmap.md) — the LuaCATS stubs already sketch both. Today, express variants with [`prova.test_each`](./tests-and-grouping.md) and request ambient fixtures explicitly with `use`.
:::

## Next

Fixtures carry state *within* a scope; when you need ordered steps that build state across a scenario, read [Flows](./flows.md). For sharing one live fixture across many files, read [Suites & Shared State](./suites-and-shared-state.md). The full context API is in the [reference](../reference/lua-api/context.md).
