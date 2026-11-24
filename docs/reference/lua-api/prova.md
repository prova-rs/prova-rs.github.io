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
| `tags` | `string[]` | Free-form selection tags — what `prova --tags` selects (or, with `!tag`, excludes) from the command line. Tags on a **group** are inherited by every unit inside it. See [Selection semantics](../cli.md#selection-semantics). |
| `requires` | `string[]` | Capabilities this unit needs. An unavailable capability **skips** the unit (with a reason), never fails it. `"docker"` probes the daemon (`docker info`), `"github"` checks `GITHUB_TOKEN`, `"network"` is assumed present; a native-capability name (`"http"`, `"sqlite"`, `"grpc"`, `"graphql"`, `"yaml"`) is available iff that feature was compiled into the build; any other name checks for a tool of that name on `PATH` (so `requires = { "cargo" }` just works), optionally with a version constraint (`"dotnet >= 9"`, `"node ^20"`). See [capability gating](../../writing-tests/dependencies-and-scheduling.md#capability-gating-requires) for the full expression grammar. |
| `depends_on` | unit handles | Handles returned by `prova.test`/`flow`/`group`. This unit runs only after every dependency **passed**; if any failed or was skipped, this unit is skipped (transitively), not failed. A cycle is a collection-time error. |
| `locks` | lock refs | Locks this unit holds while running: [`prova.writes`](#lock-constructors), `prova.reads`, `prova.port`. The scheduler never co-schedules two units whose holds conflict, and the holds bind every prova instance at the same home. Inert at `--jobs 1` within one run. `resources` is the older spelling. |
| `switch` | `string` | An opt-in class: the unit is off unless a lane's `switches`, `[run] switches` or `-s` throws it. See [Lanes](../../quality/lanes.md#switches-keep-expensive-work-out-of-the-inner-loop). |
| `serial` | `boolean` | Run-wide exclusive: never runs concurrently with anything else in this run. A rule that must bind other prova instances is a lock. Default `false`. |
| `timeout` | `string` | Time budget as a duration string (e.g. `"30s"`, `"500ms"`). Enforced per **test** and per flow **step**; teardown still runs after a timeout. A timeout set on a flow or group itself is not currently enforced — set it on the steps. |

**Test- and flow-level only** (a validation error on a group or in `suite.config`):

| Key | Type | Description |
|---|---|---|
| `promises` | `string` | A proof authored ahead of its implementation, with the reason as the value (mandatory). Red reports as the distinct `PROMISED` outcome; green **fails**, demanding graduation to `proves`. See [Promises & Burndown](../../writing-tests/promises-and-burndown.md). |
| `proves` | `string` | The kept promise's context — runtime-inert (pass is pass, fail is fail); must be a non-empty string. Never shares a test with `promises`. |
| `covers` | `string` | Binds this proof to a prose claim: `"docs/design.md#claim-id"`, optionally text-pinned with `@<hash>` (written by `prova owed --pin`). Reconciled by `prova owed` / `prova evidence` / `prova attest`. |
| `idle_timeout` | `string` | A liveness bound: fails only when no assertion lands for that long. Defaults on under `prova tests falsify`. |
| `inputs` | `string[]` | Package-relative paths or globs this test depends on; `--reuse` carries a prior pass forward when they are byte-identical. |
| `falsified_by` | `fun(t)` | A mutation the body must catch. Applied only under `prova tests falsify`, which **inverts the verdict** — a body that survives its falsifier is reported vacuous and fails. Test-level only. |

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

:::note
Autouse fixtures (`{ autouse = true }`) are not yet implemented (see the
[Roadmap](../roadmap.md)). Parametrized fixtures (`{ params = {...} }` with
`ctx:param()`) were considered and **deliberately dropped** — parametrization
stays explicit Lua: `prova.test_each` for data-driven tests, a `for` loop
generating fixtures + groups per variant for matrices. See
[Decided against](../roadmap.md#decided-against).
:::

## `prova.topology`

```lua
prova.topology(name, factory)          -- Scope.File (the default)
prova.topology(name, scope, factory)   -- explicit Scope value
```

Declare a **topology**: a named, verb-agnostic bundle of wired resources. It is
a fixture (default `Scope.File` — provisioned once, shared across a file's
tests) that is *also* addressable by name from the command line: `prova up
<name>` and `prova start <name>` stand up the identical object outside any
test, printing each resource's `url`. In test mode use it exactly like any
fixture — `t:use(handle)`. One definition powers both your tests and your dev
environment, so they cannot drift.

```lua
local env = prova.topology("orders", function(ctx)
  local db = require("postgres").container(ctx)
  db.client:execute("create table orders (id int, sku text)")
  return { db = db }
end)
```

See [Topologies](../../writing-tests/topologies.md) for the guide and the
[CLI reference](../cli.md#topology-verbs-up-start-down-ps) for the verbs.

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
| `Scope.Run` | once per run, shared across every suite and worker | after the run. The value must be plain data (each reader gets a copy), and `ctx:defer` is unavailable. With `{ identity = { command, inputs } }` as the fixture's options, two fixtures with the same identity share one conduct. |

Each `Scope` value exposes a `scope` field with its name
(`"test"`, `"flow"`, `"file"`, `"suite"`, `"run"`).

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

:::note No lifecycle hooks
There are deliberately no `before_each` / `after_each` / `before_all` /
`after_all` hooks, on groups or anywhere else. Setup and teardown are one
thing in Prova: use a [fixture](#provafixture).
:::

## `prova.infra`

```lua
local ok, err = pcall(cargo.metadata)
if not ok then prova.infra("cargo cannot read the workspace: " .. tostring(err)) end
```

Fail this node for a cause in the environment, not in the code under proof: a build tool that
cannot read the workspace, a toolchain that cannot run. The node is **failed** as ever, and its
JSON `node_finished` event also says `"cause": "infra"`, with the message's first line as
`cause_line`, so a gate can tell an infra red from a real one and retry instead of blaming the
change.

The cause is the error's type, never its text: a proof's own `error()` that quotes the same words
is a plain red. Catching the error with `pcall` and re-raising the same value (`error(e, 0)`)
keeps the infra cause; re-raising its text (`error(tostring(e))`) does not.

## Lock constructors

Typed references for the `locks` option. A constructor validates its input and cannot be typo'd
into a wrong-but-valid token.

```lua
prova.writes(token, opts?)    -- exclusive hold; token is a string or another ref
prova.reads(token, opts?)     -- shared hold: readers overlap, a writer waits for them
prova.port(number)            -- exclusive hold on a host port (machine-scoped)
```

`opts.scope = "machine"` makes a hold span every repository on the machine; the default is the
package. Re-moding composes: `prova.reads(prova.port(5432))` widens a port to a shared hold.

```lua
prova.test("migrates the db", { locks = { prova.writes("db") } },   function(t) ... end)
prova.test("reads the db",    { locks = { prova.reads("db") } },    function(t) ... end)
prova.test("boots on 8080",   { locks = { prova.port(8080) } },     function(t) ... end)
```

`prova.resource(token)` and `prova.shared(x)` are the older spellings of `prova.writes` and
`prova.reads`, still accepted. The full model, including `prova lock` for tools outside prova, is
in [Locks, Flakes & Reruns](../../running-prova/locks-and-scale.md).

## Timing primitives

### `prova.sleep`

```lua
prova.sleep(millis)
```

Await `millis` milliseconds without blocking the worker (cooperative async). A
low-level primitive; prefer `http.wait_for` / `grpc.wait_for` for readiness
polls.

### `prova.barrier`

```lua
prova.barrier(token, parties, opts?)    -- → this participant's arrival position
```

Wait until `parties` participants have arrived at `token`, then release them together: the
concurrency assertion. `opts.timeout` defaults to `"30s"`; reaching it fails the test, naming how
many of how many arrived. The participants form one selection unit. See
[Proving concurrency](../../writing-tests/dependencies-and-scheduling.md#proving-concurrency-provabarrier).

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
local conn = prova.retry(function() return sqlite.client(url) end,
                         { timeout = "60s", every = "250ms", message = "db never came up" })
```

| Key | Type | Default | Description |
|---|---|---|---|
| `timeout` | `string` | `"30s"` | Overall deadline. |
| `every` | `string` | `"500ms"` | Interval between attempts. |
| `message` | `string` | — | Error message on timeout. |

## Introspection & paths

### `prova.help`

```lua
prova.help(filter?)   -- → { name, signature, summary }[]
```

Discover the prova API **from inside prova** — the in-Lua counterpart to the MCP [`introspect`](../cli.md#prova-mcp) tool, callable from `prova eval` and test bodies. `filter` is a case-insensitive substring matched across both name and summary; omit it for the whole surface.

```lua
prova.help("shell")        -- every entry whose name or summary mentions "shell"
prova.help("ShellResult")  -- a value-shape (class) lookup — the field shape it returns
prova.help()               -- everything
```

Each entry's `signature` is the typed shape — for a function, `(command: string, opts?: prova.ShellOpts) -> prova.ShellResult`; for a class, its fields. It is generated from the **same LuaCATS stubs** that drive editor completion, so what `prova.help` reports and what your IDE autocompletes cannot drift, and a Rust test enforces that every function is documented.

### `prova.root` and `prova.home`

| Value | Description |
|---|---|
| `prova.root` | The **project root** — the directory the manifest's home lives under (where `cargo build` or a repo-relative path resolves from). |
| `prova.home` | The **prova home** — the directory holding `prova.toml` (e.g. `./prova/`). |

Both are absolute paths, resolved against the project a run (or an MCP [`project`](../cli.md#prova-mcp)) targets — so a test reads the same files whether it is run from the repo root or a subdirectory.

## `prova.parse`

The exec-CLI output-parsing toolkit: turn the text a CLI prints (typically via
[`Container:run`](../modules/docker.md#containerruncommand-opts) or
[`shell.run`](../modules/shell.md)) into Lua values, so packages and tests never
hand-roll parsing. All four raise nothing except `json` (which raises on
malformed JSON).

| Function | Returns | Description |
|---|---|---|
| `prova.parse.lines(s)` | `string[]` | Non-empty, **trimmed** lines. |
| `prova.parse.rows(s, sep?)` | `string[][]` | Each non-empty line split on `sep` (default tab) into a list of columns. |
| `prova.parse.table(s, sep?)` | `table<string,string>[]` | The first non-empty line is a **header row**; each remaining row becomes a map keyed by header name (the shape TSV-emitting admin CLIs produce). Missing columns are `""`. |
| `prova.parse.json(s)` | `any` | Parse JSON into a Lua value. JSON `null` → `nil` (a top-level `null` returns `nil`). Raises on invalid JSON. |

```lua
local out = c:run({ "rabbitmqadmin", "list", "queues", "name", "messages" })
for _, q in ipairs(prova.parse.table(out)) do
  t:expect(tonumber(q.messages), q.name .. " backlog"):equals(0)
end

-- One-object-per-line `--json` streams: compose lines + json.
for _, line in ipairs(prova.parse.lines(out)) do
  local obj = prova.parse.json(line)
end
```

## `prova.containerized`

```lua
prova.containerized(spec)   -- → { client?, container }
```

Build a grammar-conformant resource namespace from a compact spec — the
scaffolding every containerized recipe/package is authored through, so
first-party and third-party resources come out the same shape. The generated
`container(ctx, opts?)` provisions via [`docker.run`](../modules/docker.md),
waits for readiness, ties teardown to the scope with `ctx:manage`, and returns
the standard resource shape:

```lua
{ url = ..., container = ..., host = "127.0.0.1", port = <mapped host port>, client = ...? }
```

`host`/`port` are the primary published port's mapping, so env wiring is
`DB_HOST = res.host, DB_PORT = res.port`. A managed `client` is attached (built
inside `prova.retry`, closed on teardown) **only** when the spec provides a
`client` factory — provisioning works black-box without one.

| Spec field | Type | Description |
|---|---|---|
| `name` | `string?` | Namespace name, used in error messages (default `"resource"`). |
| `image` | `string` | Required. Base image repo (e.g. `"redis"`). A caller's `opts.image` fully overrides. |
| `tag` | `string?` | Default tag; `opts.tag` overrides. |
| `port` | `integer?` | The **primary** published port — used for readiness and the `url`/`host`/`port` trio. |
| `ports` | list? | Ports to publish (integer → random host port; `{ container, host }` → fixed). Defaults to `{ port }`; without `port`, the first entry's container port becomes primary. One of `port`/`ports` is required. |
| `command` | `string?` | Optional container command. |
| `env` | table or `fun(opts) → table` | Container environment; a function may read the call-time `opts`. `opts.env` replaces it entirely. |
| `wait` | `{ port?, log? }?` | Readiness probe (default: TCP on the primary port). |
| `timeout` | `string?` | Readiness deadline (default `"60s"`); `opts.timeout` overrides. |
| `url` | `fun(host_port, opts) → string` | Required. Connection URL from the mapped host port. |
| `client` | `fun(url, opts, container) → any?` | Optional client factory — a native client uses `url`; a **docker-exec** client uses the `container` argument to drive a CLI via `container:run`. Omit for black-box provisioning. |
| `extra` | `fun(url, opts, container) → table?` | Additional resource fields beyond the standard ones (e.g. S3 credentials), merged into the result (`client`/`url`/`container` are protected). |

```lua
local redis = prova.containerized{
  name = "redis", image = "redis", tag = "7-alpine", port = 6379,
  url = function(p) return "redis://127.0.0.1:" .. p end,
  client = function(url, opts, c)
    return { get = function(_, k) return c:run({ "redis-cli", "GET", k }) end }
  end,
}
return redis   -- a package: consumers write require("redis").container(ctx)
```

This is the package author's entry point — the full authoring guide (facets,
namespacing grammar, `prova package lint`, publishing) lives in
[Authoring packages](../../packages/authoring-packages.md).

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
