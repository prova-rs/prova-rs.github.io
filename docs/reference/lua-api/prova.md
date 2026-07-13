---
sidebar_position: 1
sidebar_label: "prova"
---

# The `prova` Global

The registration DSL. Everything here runs at **collection time** — the file is
loaded, declarations register into the plan, and execution happens afterward.
Top-level `prova.test`/`test_each`/`flow`/`group` register into the file's
implicit group (the independent strategy); inside an explicit group use the
[`GroupBuilder`](./context.md#groupbuilder) methods instead.

## Shared unit options (`UnitOpts`)

`prova.test`, `prova.flow`, and `prova.group` (and their builder equivalents)
all accept an optional options table between the name and the body. These keys
are shared by every schedulable unit; options set on a **group** are inherited
by every unit inside it.

| Key | Type | Description |
|---|---|---|
| `tags` | `string[]` | Free-form selection tags. Accepted and recorded; tag-based filtering is not yet implemented (see the [Roadmap](../roadmap.md)). |
| `requires` | `string[]` | Capabilities this unit needs. An unavailable capability **skips** the unit (with a reason), never fails it. `"docker"` probes the daemon (`docker info`), `"github"` checks `GITHUB_TOKEN`, `"network"` is assumed present; any other name checks for a tool of that name on `PATH` (so `requires = { "cargo" }` just works). |
| `depends_on` | unit handles | Handles returned by `prova.test`/`flow`/`group`. This unit runs only after every dependency **passed**; if any failed or was skipped, this unit is skipped (transitively), not failed. A cycle is a collection-time error. |
| `resources` | resource refs | Resources this unit holds while running — [`prova.port`](#provaport)/[`prova.resource`](#provaresource)/[`prova.shared`](#provashared) refs, or bare string tokens (exclusive by default). The scheduler never co-schedules two units whose holds conflict. Inert at `--jobs 1`. |
| `serial` | `boolean` | Process-wide exclusive: never runs concurrently with anything. Default `false`. |
| `timeout` | `string` | Time budget as a duration string (e.g. `"30s"`, `"500ms"`). Enforced per **test** and per flow **step**; teardown still runs after a timeout. A timeout set on a flow or group itself is not currently enforced — set it on the steps. |

## `prova.fixture`

```lua
prova.fixture(name, factory)          -- Scope.Test (the default)
prova.fixture(name, scope, factory)   -- explicit Scope value
```

Declare a fixture: a named factory producing a value, with scoped caching and
teardown. Returns an opaque, typed handle — pass it to
[`ctx:use(handle)`](./context.md#ctxuse) so the value's type flows through to the
call site. Fixtures are **lazy**: the factory runs on first `use` and the value
is cached for its scope; fixture-to-fixture dependencies also go through
`ctx:use`. A fixture may only `use` fixtures of equal-or-broader scope
(a `Scope.File` fixture cannot use a `Scope.Test` one — that is a runtime error).

```lua
local workspace = prova.fixture("workspace", Scope.File, function(ctx)
  return ctx:tempdir()                     -- auto-removed when the file scope ends
end)

prova.test("renders into a clean workspace", function(t)
  local ws = t:use(workspace)              -- built once, shared by the file's tests
  t:expect(ws):is_dir()
end)
```

:::note Planned
Fixture options (`{ autouse = true }`, `{ params = {...} }` with `ctx:param()`)
are not yet implemented. See the [Roadmap](../roadmap.md).
:::

## Scope constants

The `Scope` global holds the typed fixture-scope values — the only way to name a
scope (typo-safe; a non-`Scope` value is a collection-time error). Scopes tear
down inner→outer (test before flow before file before suite), and teardowns
within a scope run LIFO.

| Constant | Built | Torn down |
|---|---|---|
| `Scope.Test` | fresh for each test (per **step**, inside a flow) | after that test/step |
| `Scope.Flow` | once per `prova.flow`, on first use in any step | after the flow's last step. Only valid inside a flow. |
| `Scope.File` | once per file, on first use | after all of the file's tests |
| `Scope.Suite` | once per suite, on first use | after the whole suite |

Each `Scope` value exposes a `scope` field with its name
(`"test"`, `"flow"`, `"file"`, `"suite"`).

## `prova.test`

```lua
prova.test(name, body)          -- body : fun(t: TestContext)
prova.test(name, opts, body)    -- opts : TestOpts
```

Declare an independent test. Returns a unit handle usable in `depends_on`.
`TestOpts` is exactly the [shared unit options](#shared-unit-options-unitopts).
(The stubs also annotate a `retries` key; it is not yet implemented — see the
[Roadmap](../roadmap.md).)

```lua
prova.test("health endpoint answers", { tags = { "net" }, timeout = "30s" }, function(t)
  local res = http.get("http://localhost:8080/health")
  t:expect(res.status):equals(200)
end)
```

## `prova.test_each`

```lua
prova.test_each(name_template, cases, body)   -- body : fun(t: TestContext, case: table)
```

Table-driven tests: registers one test per entry in `cases` (a sequence of case
tables), all sharing one body. `{key}` placeholders in `name_template` are
filled from each case (an unknown key or non-table case leaves the `{key}`
literal in place). The case reaches the body as its second argument **and** as
`t.case`. Returns the list of generated unit handles (each usable in
`depends_on`).

```lua
prova.test_each("renders for {lang}", {
  { lang = "rust", entry = "src/main.rs" },
  { lang = "java", entry = "src/main/java/App.java" },
}, function(t, case)
  t:expect(project_dir .. "/" .. case.entry):is_file()
end)
-- Reports as "renders for rust" and "renders for java".
```

## `prova.flow`

```lua
prova.flow(name, body)          -- body : fun(f: FlowBuilder)
prova.flow(name, opts, body)    -- opts : FlowOpts (the shared unit options)
```

Declare a flow: an **ordered sequence** of steps forming one scheduling unit.
Steps run serially, in declaration order, on one worker; once a step fails, the
remaining steps **cascade-skip** (skip, not fail) with the failing step named. A
step that skips itself does not cascade. Shared mutable state lives in the flow
body's local variables (closure upvalues) — the flow is the *only* construct
that grants cross-step shared state. Returns a unit handle.

```lua
prova.flow("order lifecycle", function(f)
  local order                                  -- shared by all steps

  f:step("create", function(t)
    order = http.post(api .. "/orders", { json = { sku = "widget" } }):json()
    t:expect(order.id):is_truthy()
  end)

  f:step("read back", function(t)              -- skipped if "create" failed
    t:expect(http.get(api .. "/orders/" .. order.id).status):equals(200)
  end)
end)
```

The builder's only method is [`f:step(name, [opts], body)`](./context.md#flowbuilder).
`Scope.Flow` fixtures are built once per flow and shared across its steps via
`t:use` inside a step.

## `prova.group`

```lua
prova.group(name, body)         -- body : fun(g: GroupBuilder)
prova.group(name, opts, body)   -- opts : GroupOpts (the shared unit options)
```

Declare an independent group: an isolated, unordered, parallelizable bag of
child units. The [`GroupBuilder`](./context.md#groupbuilder) exposes
`test`/`test_each`/`flow`/`group`/`describe` — and deliberately **no
shared-state mechanism**; if you need ordering plus built-up state, use a
`flow`. Options on the group (`depends_on`, `resources`, `serial`, `requires`)
are inherited by every unit inside it; `depends_on = { group_handle }` gates on
all of the group's leaves. Returns a unit handle.

```lua
prova.group("http surface", function(g)
  g:test("GET /health",  function(t) ... end)
  g:test("GET /version", function(t) ... end)   -- may run concurrently with the above
end)
```

## `prova.describe`

```lua
prova.describe(label, body)     -- body : fun()
```

Labeling-only grouping for reports: bare `prova.test`/`test_each`/`flow`/`group`
declarations inside `body` nest under `label` in reported paths. Introduces no
new fixture scope and takes no options. Nesting is supported; the ambient parent
is restored even if the body errors.

```lua
prova.describe("rust cli archetype", function()
  prova.test("has a Cargo.toml", function(t) ... end)
  prova.test("compiles",         function(t) ... end)
end)
-- Reports as "rust cli archetype › has a Cargo.toml", etc.
```

:::note Planned
Lifecycle hooks (`prova.before_each` / `after_each` / `before_all` /
`after_all`) appear in the editor stubs but are not yet implemented; use
fixtures instead. See the [Roadmap](../roadmap.md).
:::

## Resource constructors

Typed references for the `resources` option. Prefer these over magic-format
strings — a constructor validates its input and cannot be typo'd into a
wrong-but-valid token. A bare string in a `resources` list is also accepted as
an ad-hoc **exclusive** token.

### `prova.port`

```lua
prova.port(number)    -- → ResourceRef (exclusive)
```

An exclusive resource for a TCP port: `prova.port(8080)` is the typed form of
`"port:8080"`.

### `prova.resource`

```lua
prova.resource(token)    -- → ResourceRef (exclusive)
```

An exclusive resource for an arbitrary named token (a database, an account, a
path).

### `prova.shared`

```lua
prova.shared(resource)    -- ResourceRef or string → ResourceRef (shared)
```

Mark a resource as a **concurrent reader** (readers–writer semantics): readers
run together; an exclusive holder waits for all readers to release, and vice
versa.

```lua
prova.test("writes the db", { resources = { prova.resource("db") } },        function(t) ... end)
prova.test("reads the db",  { resources = { prova.shared("db") } },          function(t) ... end)
prova.test("boots on 8080", { resources = { prova.port(8080) } },            function(t) ... end)
```

## Timing primitives

### `prova.sleep`

```lua
prova.sleep(millis)
```

Await `millis` milliseconds without blocking the worker (cooperative async). A
low-level primitive; prefer `http.wait_for` / `grpc.wait_for` for readiness
polls.

### `prova.retry`

```lua
prova.retry(fn)          -- defaults: timeout "30s", every "500ms"
prova.retry(fn, opts)    -- → the truthy value fn returned
```

Call `fn` repeatedly until it returns a truthy value, or the deadline elapses. A
raised error inside `fn` counts as "not ready yet", not a failure. On timeout,
raises with `message` (or a default) plus the last error seen. The readiness
primitive:

```lua
local conn = prova.retry(function() return db.connect(url) end,
                         { timeout = "60s", every = "250ms", message = "postgres never came up" })
```

| Key | Type | Default | Description |
|---|---|---|---|
| `timeout` | `string` | `"30s"` | Overall deadline. |
| `every` | `string` | `"500ms"` | Interval between attempts. |
| `message` | `string` | — | Error message on timeout. |

## `suite.config`

```lua
suite.config{ name = "grpc services", requires = { "docker" } }
```

Configure the current suite — call it in a `suite.lua` setup file (a directory's
`suite.lua` groups its test files into one suite sharing a Lua state, so
`Scope.Suite` fixtures are built once across them).

| Key | Type | Description |
|---|---|---|
| `name` | `string` | Display name for the suite (default: derived from the directory/file name). |
| `requires` | `string[]` | Capabilities gating the **whole suite** — folded into the root, so every contained test inherits them; unmet capabilities skip all the suite's files (skip, not fail). |
