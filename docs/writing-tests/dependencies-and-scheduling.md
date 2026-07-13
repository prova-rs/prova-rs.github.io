---
sidebar_position: 5
---

# Dependencies & Scheduling

The atom of scheduling in Prova is the **unit**: a top-level test, a [flow](./flows.md), or a [group](./tests-and-grouping.md). One uniform rule governs how units relate:

> Units with no dependency edge between them are mutually isolated and may run in parallel (subject to resources). A dependency edge orders them and gates on success.

Everything on this page — `depends_on`, `resources`, `serial`, `requires` — is declared *in the test code*, next to what it protects. The CLI cannot change what your tests mean.

## The dependency DAG: `depends_on`

`prova.test`, `prova.flow`, and `prova.group` all return handles. Pass them to `depends_on`:

```lua
local login = prova.flow("login", function(f)
  f:step("authenticate", function(t) t:expect(true):is_true() end)
end)

local populate = prova.flow("populate account", { depends_on = { login } }, function(f)
  f:step("seed profile", function(t) --[[ ... ]] end)
  f:step("seed billing", function(t) --[[ ... ]] end)
end)

-- Same upstreams, no edge between them → these two run in parallel.
prova.flow("checkout journey", { depends_on = { login, populate } }, function(f) --[[ ... ]] end)
prova.test("settings journey", { depends_on = { login, populate } }, function(t) --[[ ... ]] end)
```

The semantics, precisely:

- **Upstream failure or skip → downstream is SKIPPED, not failed** — transitively, with the blocking unit named in the reason. A failed `login` skips `populate`, `checkout`, and `settings`; you investigate one failure, not four.
- **A group is a unit too.** Depending on a group means depending on all its leaves; `depends_on` (like `resources`, `serial`, and `requires`) declared *on* a group is inherited by every child.
- **A cycle is a collection-time error** — the run refuses to start rather than deadlock.
- **Gating, never data.** `depends_on` answers "did it pass?" and nothing else. Data flows through a [fixture](./fixtures.md) or, within one scenario, a flow's own context. Keeping "did it pass?" separate from "give me its value" is deliberate — conflating them is how brittle implicit ordering creeps in.

## Resources: co-scheduling around external constraints

Parallel tests are isolated through the framework's surface, but they can still collide in the outside world — a fixed port, a shared database. Declare those constraints and the scheduler co-schedules safely:

```lua
-- Two services that both bind :8080 — the scheduler will never overlap them.
prova.test("service A boots on :8080", { resources = { prova.port(8080) } }, function(t) --[[ ... ]] end)
prova.test("service B boots on :8080", { resources = { prova.port(8080) } }, function(t) --[[ ... ]] end)

-- Read-only tests against a shared database may overlap each other...
prova.test("report reads the db",    { resources = { prova.shared("db") } }, function(t) --[[ ... ]] end)
prova.test("dashboard reads the db", { resources = { prova.shared("db") } }, function(t) --[[ ... ]] end)

-- ...but a writer against the same token excludes all of them.
prova.test("migration writes the db", { resources = { prova.resource("db") } }, function(t) --[[ ... ]] end)
```

The semantics are readers-writer:

| Declaration | Meaning |
|---|---|
| `prova.port(8080)` | Exclusive hold on the typed token for that port |
| `prova.resource("db")` | Exclusive hold on an arbitrary named token |
| `prova.shared(x)` | Concurrent reader — readers overlap; a writer waits for all readers |
| `"db"` (bare string) | Accepted for ad-hoc tokens; **exclusive** by default |
| `serial = true` | Process-wide exclusive — never concurrent with anything |

Prefer the typed constructors over magic-format strings: `"port:8080"` hides a `prefix:value` convention you can typo silently, while `prova.port(8080)` validates its number and cannot be. Acquisition is all-or-nothing per unit — no unit ever holds one resource while waiting for another, so the scheduler cannot deadlock.

:::tip
Resource declarations are inert at `--jobs 1` and enforced above it. Declare them once, when you write the test, and the suite scales out later without touching test code.
:::

## Capability gating: `requires`

`requires` lists what a unit needs from the host. A missing capability **skips** the unit — visibly, with a reason — rather than failing it:

```lua
prova.group("inventory gRPC service (Postgres)", { requires = { "docker", "cargo" } }, function(g)
  -- every test in the group inherits the gate
end)

prova.test("compiles cleanly", { timeout = "180s", requires = { "cargo" } }, function(t)
  local r = shell.run("cargo build", { cwd = t:use(project).path, timeout = "180s" })
  t:expect(r.code):equals(0)
end)
```

How capabilities resolve, once per run:

| Capability | Available when |
|---|---|
| `"docker"` | the Docker daemon is actually reachable (`docker info`), not merely installed |
| `"github"` | `GITHUB_TOKEN` is set in the environment |
| `"network"` / `"internet"` | currently assumed present |
| anything else | a binary of that name is on `PATH` — so `requires = { "cargo" }` or `{ "kubectl" }` just works |

This is what makes a suite honest across machines: on a laptop without Docker, the container-backed tests report as skipped with `requires "docker" (unavailable)` — and the rest of the suite still runs and still means something.

## `--jobs` changes throughput, never meaning

Because strategy lives in the code — flows are serial by construction, groups are independent by construction, edges and resources gate explicitly — the [`--jobs`](../running-prova/command-line.md) flag sets only *how many workers may run*. A flow is serial at `--jobs 100`; an independent group is parallelizable at `--jobs 1` (it just won't actually overlap); a dependency edge orders its units at any job count. The CLI cannot change semantics, so it cannot surprise you.

One nuance worth knowing: `--jobs` counts concurrent [suites](./suites-and-shared-state.md) (an ungrouped file is its own singleton suite). Within a suite, I/O-bound units still overlap cooperatively on one worker.

## Choosing the right tool

| You need | Reach for |
|---|---|
| Ordered steps sharing built-up state | a [flow](./flows.md) |
| "B is meaningless unless A passed" | `depends_on` |
| "These can't share a port/db/account" | `resources` |
| "This test must own the whole machine" | `serial = true` |
| "Skip cleanly where Docker/cargo is absent" | `requires` |
| Passing a value between units | a [fixture](./fixtures.md) — never a dependency |

## Next

Continue with [Suites & Shared State](./suites-and-shared-state.md) to share expensive infrastructure across files.
