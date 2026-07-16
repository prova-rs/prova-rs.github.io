---
sidebar_position: 1
---

# Tests & Grouping

A test file is plain Lua. The runtime injects the `prova` global (plus the [modules](../reference/modules/index.md) — `fs`, `shell`, `http`, and friends) into every file, so there is nothing to `require`. Any file matching `*_test.lua` or `*.test.lua` is discovered automatically.

## Declaring a test

`prova.test(name, fn)` declares an independent test. The body receives a test context, `t`, which carries [assertions](./assertions.md), [fixture access](./fixtures.md), and control flow:

```lua
prova.test("builds cleanly", function(t)
  local r = shell.run("cargo build", { cwd = "." })
  t:expect(r.code):equals(0)
end)
```

Test bodies run cooperatively on an async runtime — calls like `shell.run`, `http.get`, and `prova.sleep` yield the worker instead of blocking it, so I/O-bound tests overlap naturally when you raise [`--jobs`](../running-prova/command-line.md).

## Options

Pass an options table between the name and the body:

```lua
prova.test("compiles the rendered project", {
  timeout = "180s",
  tags = { "build" },
  requires = { "cargo" },
}, function(t)
  local r = shell.run("cargo build", { cwd = t:use(project).path, timeout = "180s" })
  t:expect(r.code):equals(0)
end)
```

| Option | Effect |
|---|---|
| `timeout` | Duration string (`"30s"`, `"500ms"`). The test fails with `timed out after ...`; teardown still runs. |
| `tags` | Free-form labels attached to the test — the handles `prova --tags` selects (or excludes) from the command line. A group's tags are inherited by everything inside it. |
| `requires` | Capabilities the test needs (`"docker"`, `"cargo"`, ...). Missing → the test is **skipped**, never failed. See [Dependencies & Scheduling](./dependencies-and-scheduling.md). |
| `depends_on` | Unit handles this test must wait for. See [Dependencies & Scheduling](./dependencies-and-scheduling.md). |
| `resources` / `serial` | Concurrency gating. See [Dependencies & Scheduling](./dependencies-and-scheduling.md). |

:::tip
Run a subset from the command line with `prova -k <pattern>` (name filtering), `prova --tags a,b` (with `!tag` excludes), `--node` for an exact path, or `--last-failed`. See [The Command Line](../running-prova/command-line.md#run-a-subset).
:::

:::note Planned
A `retries` option for automatically re-running flaky tests is on the [roadmap](../reference/roadmap.md). Today, wrap the flaky *operation* in `prova.retry(fn, { timeout = "30s" })` — retrying the unreliable call is usually the better fix anyway.
:::

## Table-driven tests: `prova.test_each`

`prova.test_each(name_template, cases, fn)` generates one test per case. `{key}` placeholders in the template are filled from each case table, so every row reports as a distinct test; the case reaches the body as its second argument and as `t.case`:

```lua
prova.test_each("renders for {lang}", {
  { lang = "rust", entry = "src/main.rs" },
  { lang = "java", entry = "src/main/java/App.java" },
}, function(t, case)
  local out = archetect.render{
    source = "examples/fixtures/rust-cli",
    answers = { language = case.lang },
    defaults = true,
    destination = t:tempdir(),
  }
  t:expect(out:file(case.entry)):exists()
end)
-- Reports as: "renders for rust" and "renders for java"
```

An unknown placeholder is left literally in the name rather than failing — the name is cosmetic. `test_each` returns the list of generated test handles, so a downstream unit can `depends_on` the whole set.

## Labeling with `prova.describe`

`describe` nests names in the report — it is organizational labeling, not a new fixture scope. Bare declarations inside its body register under the label:

```lua
prova.describe("rust-cli archetype", function()
  prova.test("produces the expected scaffold", function(t)
    t:expect(t:use(project):file("Cargo.toml")):exists()
  end)

  prova.test("has no leftover template markers anywhere", function(t)
    t:expect(t:use(project)):is_fully_rendered()
  end)
end)
-- Reports as: rust-cli archetype › produces the expected scaffold, ...
```

Because `describe` does not introduce a scope, fixtures behave exactly as they would at the top level — a `Scope.File` fixture used inside two `describe` blocks is still one instance.

## Explicit groups: `prova.group`

The file itself is an implicit group: bare `prova.test`, `prova.flow`, and `prova.group` at the top level register into it. An explicit `prova.group` gives you a named, schedulable unit whose children you declare through its builder, `g`:

```lua
prova.group("inventory gRPC service (Postgres)", { requires = { "docker", "cargo" } }, function(g)
  g:test("boots against real Postgres and serves its gRPC API", function(t)
    -- ...
  end)

  g:test("ran its migrations against that same Postgres", function(t)
    -- ...
  end)
end)
```

The `GroupBuilder` exposes `g:test`, `g:test_each`, `g:flow`, `g:group`, and `g:describe` — the same declarations, nested. Two things make groups worth reaching for:

- **Options apply to every child.** `requires`, `depends_on`, `resources`, and `serial` on the group are inherited by each contained test — declare the Docker requirement once, not per test.
- **The group is one unit.** `prova.group(...)` returns a handle, so another unit can `depends_on` the whole group; it passes only when its children do.

A group's contract is *independence*: children are isolated, unordered, and parallelizable. There is deliberately **no shared-state mechanism** on the builder — if you find yourself wanting ordered children that build up state, that is exactly what a [flow](./flows.md) is for. Do not rely on definition order within a group.

:::note Planned
`--shuffle`, which randomizes group-child order (printing a reproducible seed) to *prove* independence, is on the [roadmap](../reference/roadmap.md). Today the runner happens to iterate in a deterministic order — treat that as an implementation detail, not a contract.
:::

## Setup and teardown

Prova has no xUnit-style hook functions; setup and teardown live in [fixtures](./fixtures.md), which are lazier, composable, and scoped. A `Scope.Test` fixture is "before each + after each"; a `Scope.File` fixture is "before all + after all":

```lua
local workspace = prova.fixture("workspace", Scope.Test, function(ctx)
  local dir = ctx:tempdir()          -- fresh per test, removed after each test
  return dir
end)

prova.test("starts from a clean slate", function(t)
  local ws = t:use(workspace)
  -- ...
end)
```

:::note Planned
Convenience hooks (`before_each` / `after_each` / `before_all` / `after_all`) are on the [roadmap](../reference/roadmap.md) as sugar over fixtures. Today, declare a fixture at the matching scope and `use` it where needed.
:::

## Next

Fixtures are the mechanism behind almost everything on this page — continue with [Fixtures](./fixtures.md), or jump to the full [`prova` API reference](../reference/lua-api/prova.md).
