---
sidebar_position: 2
sidebar_label: "Contexts"
---

# Contexts

Every body Prova invokes receives a context as its first argument:

| Where | Receives | Conventional name |
|---|---|---|
| Fixture factory (`prova.fixture`) | `Context` | `ctx` |
| Test body (`prova.test`, `test_each`) | `TestContext` | `t` |
| Flow step (`f:step`) | `TestContext` | `t` |

`TestContext` extends `Context` with assertions and control flow. Everything
callable is a **colon-method** (`t:expect`, `ctx:use`); the only dot member is
the plain data field `t.case`. The scope that `defer`/`manage`/`tempdir` target
is the receiver's own scope: the fixture's declared scope inside a factory, the
per-test (per-step) scope inside a test body.

## `Context` — fixture factories and tests

### `ctx:use`

```lua
ctx:use(handle)   -- handle from prova.fixture — the value's type flows through
ctx:use(name)     -- bare string name (cross-file lookup); untyped
```

Instantiate or fetch a fixture value. Lazy: the factory runs on first use, and
the value is cached for the fixture's scope instance. Fixture-to-fixture
dependencies use this too, subject to the scope rule: a fixture may only use
fixtures of **equal-or-broader** scope (violations are a runtime error naming
both scopes). An unknown name raises `no fixture named "..."`.

`use` is asynchronous under the hood, so fixture factories may themselves await
module calls (`shell.run`, `docker.run`, `http.wait_for`, ...).

### `ctx:defer`

```lua
ctx:defer(fn)
```

Register a teardown callback for the current scope. Callbacks run **LIFO** when
the scope ends, so a fixture's cleanups run before those of anything it depended
on. Teardown runs even when the test failed or timed out. Callbacks may perform
async work (e.g. stopping a container).

### `ctx:manage`

```lua
local pg = ctx:manage(docker.run{ image = "postgres:16" })
```

Tie a resource's lifecycle to the current scope: on teardown, its `stop()`
(containers, processes) or `close()` (connections) method is called — `stop`
wins when both exist. Returns the resource, so it composes inline. A value with
neither method is an immediate error. Sugar over `ctx:defer`; use `defer` for
custom teardown.

### `ctx:tempdir`

```lua
local dir = ctx:tempdir()    -- → path string
```

Create a scratch directory that is removed automatically when the current scope
ends.

### `ctx:log`

```lua
ctx:log("seeded 3 rows")
```

Attach a log line to the current test/fixture. (Currently written to stderr,
keeping stdout clean for the JSON protocol.)

:::note
`ctx:param()` and parametrized fixtures were considered and **deliberately
dropped** — parametrization stays explicit Lua: use `prova.test_each` for
table-driven cases. See [Decided against](../roadmap.md#decided-against).
:::

## `TestContext` — tests and flow steps

All `Context` members, plus:

### `t:expect`

```lua
t:expect(subject)          -- → Matcher
t:expect(subject, label)   -- label woven into the failure message
```

Start a fluent assertion. With a label, a failure reads
`order id: expected a truthy value, got nil` instead of pointing at an anonymous
value. See [Matchers](./matchers.md) for the full surface.

### `t:expect_all`

```lua
t:expect_all(function()
  t:expect(dir .. "/README.md"):exists()
  t:expect(dir .. "/LICENSE"):exists()
  t:expect(dir .. "/.gitignore"):exists()
end)
```

Soft assertions: every failed assertion inside the body is collected, and the
test then fails once with **all** of them (`N soft assertion(s) failed: ...`) —
it reports every missing file, not just the first. A real error (or a `skip`)
raised inside the body still propagates immediately.

### `t:skip`

```lua
t:skip("needs a live cluster")
```

Skip the current test (or flow step) at runtime with a reason. Aborts the rest
of the body; the result is **skipped**, not failed. A step skipping itself does
not cascade-skip the rest of its flow.

### `t.case`

The current `test_each` case table (also delivered as the body's second
argument). `nil` for ordinary tests.

## `FlowBuilder`

Passed to a `prova.flow` body (conventionally `f`). The flow body runs once at
**collection time**; its local variables are shared by all step closures — the
flow's context bag.

| Member | Description |
|---|---|
| `f:step(name, body)` / `f:step(name, opts, body)` | Declare an ordered step (`body : fun(t: TestContext)`). Steps run in declaration order on one worker; after a failure the remaining steps cascade-skip. `opts` are the [shared unit options](./prova.md#shared-unit-options-unitopts) — notably a per-step `timeout`. |

:::note
A builder-level `f:use(fixture)` was considered and **deliberately dropped**.
Call `t:use(fixture)` inside a step instead — a `Scope.Flow` fixture is built
once per flow and shared across its steps, which is the same
one-instance-per-flow semantics. See
[Decided against](../roadmap.md#decided-against).
:::

## `GroupBuilder`

Passed to a `prova.group` body (conventionally `g`). It exposes declaration
methods only — **no shared-state mechanism**, by design.

| Member | Description |
|---|---|
| `g:test(name, [opts], body)` | Declare an independent test in this group. Returns a unit handle. |
| `g:test_each(name_template, cases, body)` | Table-driven tests within this group. Returns the generated handles. |
| `g:flow(name, [opts], body)` | Declare a flow (ordered sequence) as a child unit. Returns a unit handle. |
| `g:group(name, [opts], body)` | Declare a nested group. Returns a unit handle. |
| `g:describe(label, body)` | Label-only subgrouping for reporting; `body` receives a `GroupBuilder`. |

Group-level options (`depends_on`, `resources`, `serial`, `requires`) are
inherited by every unit declared inside the group.
