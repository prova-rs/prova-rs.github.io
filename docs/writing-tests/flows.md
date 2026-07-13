---
sidebar_position: 4
---

# Flows

Every test in Prova lives inside a **strategy container** that determines how its children run. There are exactly two. A *group* (including the file itself) is a bag of independent, unordered, parallelizable units. A **flow** is the other one: an ordered sequence of steps that run in declared order, on one worker, sharing state. You never configure execution with flags — you read the container and you know.

```lua
prova.flow("order lifecycle", function(f)
  local order                        -- shared by all steps (the flow context)

  f:step("create", function(t)
    order = { id = 42, qty = 2 }
    t:expect(order.id):is_truthy()
  end)

  f:step("read back", function(t)    -- runs only if "create" passed
    t:expect(order.qty):equals(2)
  end)

  f:step("cancel", function(t)
    t:expect(order.id):equals(42)
  end)
end)
```

The builder `f` exposes `step(name, fn)` — and deliberately nothing that would let you declare unordered children. Each step body receives the same `t` context a test does, so [assertions](./assertions.md), `t:use`, `t:skip`, and per-step teardown all work identically; a step is the flow's analog of a test for reporting.

## The contract: group vs. flow

| | `prova.group` (and the file) | `prova.flow` |
|---|---|---|
| Strategy | independent | sequence |
| Children | tests, flows, nested groups | ordered steps |
| Order | unspecified — do not rely on it | declared order, guaranteed |
| Parallelism | children may overlap | steps serial, one worker — never split |
| Shared state | **not representable** | closure upvalues + `Scope.Flow` fixtures |
| On child failure | siblings unaffected | remaining steps **cascade-skip** |

This is *make-invalid-states-unrepresentable* applied to execution. Shared mutable context is a flow-only capability; a group's builder simply has no mechanism for it, so "ordered tests quietly sharing state" is not a mistake you can express. Because the file defaults to the independent strategy, **the presence of a `flow` is always the visible signal that ordering and shared state are in play.**

## Sharing state across steps

Two blessed mechanisms, by lifetime:

**Closure upvalues** — a `local` declared in the flow body and captured by the steps. This is the flow context: cheap, direct, perfect for values produced by one step and consumed by the next (`order` in the example above).

**`Scope.Flow` fixtures** — for state that deserves setup and teardown. Built on first `use` inside any step, shared by every subsequent step, torn down after the flow's last step:

```lua
local ledger = prova.fixture("ledger", Scope.Flow, function(ctx)
  ctx:defer(function() ctx:log("ledger closed") end)
  return { entries = {} }
end)

prova.flow("order lifecycle", function(f)
  f:step("create", function(t)
    local l = t:use(ledger)                 -- built here
    table.insert(l.entries, "created 42")
  end)

  f:step("read back", function(t)
    t:expect(t:use(ledger).entries):contains("created 42")   -- SAME instance
  end)
end)
```

Inside a flow, `Scope.Test` means **per-step**: a test-scoped fixture is rebuilt (and torn down) for each step, while the flow-scoped one persists. `Scope.Flow` is only valid inside a flow — using it from an ordinary test is an error.

:::note Planned
A builder-level `f:use(fixture)`, binding a fixture for the flow's lifetime at declaration time, is on the [roadmap](../reference/roadmap.md). Today, `t:use` a `Scope.Flow` fixture from within a step — the caching gives you the same one-instance-per-flow semantics.
:::

## Failure: cascade-skip

Once a step fails, the remaining steps are **skipped, not failed**, each reporting which step broke the chain:

```lua
prova.flow("cascade on failure", function(f)
  f:step("first ok",    function(t) t:expect(1):equals(1) end)
  f:step("second fails", function(t) t:expect(1):equals(2) end)
  f:step("third is skipped", function(t)
    error("this step must never run")
  end)
end)
-- second fails; third reports: skipped: earlier step "second fails" failed
```

You get one failure to investigate instead of a cascade of spurious ones. A step that skips *itself* via `t:skip(reason)` does **not** cascade — skip is not failure, and the following steps still run. The flow's `Scope.Flow` teardown runs after the last step regardless of outcome.

## A flow is one scheduling unit

Internally serial, externally independent: a flow parallelizes with its sibling units like any other unit, and `--jobs` never changes its internal order. Flows accept the same scheduling options as tests — `tags`, `requires`, `depends_on`, `resources`, `serial` — applying to the whole flow, and `prova.flow(...)` returns a handle other units can depend on:

```lua
local login = prova.flow("login", function(f)
  f:step("authenticate", function(t) --[[ ... ]] end)
end)

prova.flow("checkout journey", { depends_on = { login } }, function(f)
  -- ...
end)
```

## Flow or `depends_on`?

Both express "this after that" — but they answer different questions:

- **Use a flow** when steps are one scenario: they share built-up state (an order id, a session), always run together, and a mid-scenario failure should abandon the rest. A flow is a single unit with a shared lifetime.
- **Use [`depends_on`](./dependencies-and-scheduling.md)** when independent units have a prerequisite relationship: "the journeys need login to have passed." Dependencies gate on outcome only — they never transfer state — and units that share upstreams but have no edge between each other still run in parallel.

A good smell test: if you are tempted to smuggle a value from one unit to another, either they belong in one flow, or the value belongs in a [fixture](./fixtures.md).

## Next

Continue with [Dependencies & Scheduling](./dependencies-and-scheduling.md) to see how flows, tests, and groups compose into a DAG.
