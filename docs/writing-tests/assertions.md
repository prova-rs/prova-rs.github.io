---
sidebar_position: 3
---

# Assertions

Prova has a single fluent entry point for assertions: `t:expect(subject, label?)` returns a matcher, and every check is a method on it. Matchers are methods, not strings — `expect(x):equals(y)`, never `expect(x, "equals", y)` — so your editor completes them and a typo fails at edit time.

```lua
t:expect(r.code):equals(0)
t:expect(r.stdout):contains("Compiling")
t:expect(out:file("Cargo.toml")):exists()
```

By default a failed assertion **fails the test immediately** with a message built from the subject and the expectation. The optional second argument is a **label**, woven into the failure message so anonymous values still read clearly:

```lua
t:expect(order.id, "order id"):is_truthy()
-- on failure: "order id: expected a truthy value, got nil"
```

## A tour of the matchers

### Equality

```lua
t:expect(res:json().name):equals("orders")   -- deep structural equality (recurses into tables)
t:expect(count):eq(3)                        -- alias for equals
t:expect(a):is(b)                            -- identity: the SAME table/userdata, not just equal
```

`equals` compares tables structurally — same keys, recursively equal values. Reach for `is` when you mean "this is that same object": it compares by reference (`rawequal` semantics), which also handles tables with function fields that deep equality cannot compare.

### Truthiness and nil

```lua
t:expect(order.id):is_truthy()     -- anything but nil/false
t:expect(err):is_falsy()
t:expect(proc:running()):is_true() -- strictly boolean true
t:expect(flag):is_false()
t:expect(value):is_nil()
```

### Strings and patterns

```lua
t:expect(cargo):contains('name = "widget"')        -- substring
t:expect(r.stdout):matches("Finished .+ in %d")    -- Lua pattern, not regex
```

`matches` uses Lua patterns (`%d`, `%s`, character classes) — the same dialect as `string.find`.

### Comparisons and membership

```lua
t:expect(res.status):is_one_of({ 200, 204 })
t:expect(svc.proc.pid):gt(0)
t:expect(migrations):gte(1)
t:expect(latency_ms):lt(500)
t:expect(qty):lte(10)
```

### Collections

```lua
t:expect(l.entries):contains("created 42")   -- membership for tables
t:expect(list):has_length(3)                 -- sequence length; byte length for strings
```

### Filesystem

Filesystem matchers accept a path string or any handle with a `path` field — the tree/file handles returned by `archetect.render` work directly:

```lua
t:expect(out:file("src/main.rs")):exists()
t:expect(ws .. "/config.toml"):is_file()
t:expect(out:dir("src")):is_dir()
t:expect(out:dir("target")):never():exists()
t:expect(scratch):is_empty()                 -- empty dir, or zero-byte file
```

### The archetype check: `is_fully_rendered`

One call scans an entire rendered tree — every file's contents *and* every path segment — for leftover template markers (`{{`, `{%`, `{#`). GitHub Actions `${{ ... }}` expressions are recognized as legitimate and excluded. This is the signature assertion for [archetype](../reference/modules/archetect.md) output, and it is tedious enough to hand-roll that it earns its own matcher:

```lua
prova.test("has no leftover template markers anywhere", function(t)
  t:expect(t:use(project)):is_fully_rendered()
end)
```

On failure it lists each offender as `relpath:line: snippet`, so you go straight to the unrendered template.

### Snapshots

:::note Planned
Snapshot matching (`matches_snapshot()`, with a `--update-snapshots` flag to rewrite stored snapshots, in the spirit of Rust's `insta`) is on the [roadmap](../reference/roadmap.md). Today, read the file and assert directly — `t:expect(out:file("src/main.rs"):read()):contains(...)` — or use `is_fully_rendered()` for whole-tree checks.
:::

## Negation: `:never()`

Any matcher can be negated by inserting `:never()` in the chain:

```lua
t:expect(r.stderr):never():contains("error[")
t:expect(out:dir("target")):never():exists()
```

## Soft assertions: `t:expect_all`

Sometimes you want *every* failure, not just the first — asserting on a whole scaffold, for instance. Inside `t:expect_all(fn)`, failed assertions are collected instead of aborting, and the test fails once with all of them:

```lua
prova.test("produces the expected scaffold", function(t)
  local p = t:use(project)
  t:expect_all(function()
    t:expect(p:file("Cargo.toml")):exists()
    t:expect(p:file("src/main.rs")):exists()
    t:expect(p:file("README.md")):exists()
    t:expect(p:file(".gitignore")):exists()
  end)  -- reports every missing file, not just the first
end)
```

A real error (or a skip) raised inside the block still propagates immediately — softness applies only to matcher failures.

## Skipping at runtime: `t:skip`

`t:skip(reason)` ends the current test immediately and reports it as skipped, with the reason:

```lua
prova.test("exercises the staging environment", function(t)
  if os.getenv("STAGING_URL") == nil then
    t:skip("STAGING_URL not set")
  end
  -- ...
end)
```

Skips are first-class outcomes, distinct from failures — the same principle that drives [`requires` capability gating and `depends_on` cascade-skips](./dependencies-and-scheduling.md). Prefer declarative gating (`requires = { "docker" }`) when the condition is a host capability; reach for `t:skip` when the decision needs runtime information.

## Next

The full matcher table lives in the [matcher reference](../reference/lua-api/matchers.md). Next in the learning path: [Flows](./flows.md).
