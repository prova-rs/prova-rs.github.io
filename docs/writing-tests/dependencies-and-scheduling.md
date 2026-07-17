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

A **capability is a fact about the machine** — its OS, its hardware, the tools on its `PATH` — not a fact about your code. That split is the whole doctrine:

> A pass is a claim about the code. A skip is a claim about the environment.

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

This is what makes a suite honest across machines: on a laptop without Docker, the container-backed tests report as skipped with `requires "docker" (unavailable)` — and the rest of the suite still runs and still means something.

### The capability expression

A `requires` entry is a **string expression**: a name, optionally with a semver constraint.

```lua
requires = { "docker" }            -- the daemon answers AND runs Linux containers (not just any daemon)
requires = { "dotnet >= 9" }       -- present AND new enough; SDK 8 SKIPS instead of dying at build time
requires = { "node ^20" }          -- any semver operator; whitespace is not significant
requires = { "git >= 1.0, < 3.0" } -- ranges work
requires = { "unix" }              -- a platform predicate (no version — the OS has no number)
requires = { "windows" }
requires = { "kubectl" }           -- an unknown name → a binary-on-PATH probe, no registration needed
```

How they resolve, once per run:

| Capability | Available when |
|---|---|
| `"docker"` | the daemon is reachable **and serves Linux containers** — a Windows-container daemon is *not* `docker` for prova |
| `"unix"` / `"windows"` | the host platform matches |
| `"github"` | `GITHUB_TOKEN` is set in the environment |
| a name with a version (`"dotnet >= 9"`) | the tool is present and its reported version satisfies the constraint (probed via `--version`; docker reports its **server** version) |
| anything else | a binary of that name is on `PATH` — so `requires = { "cargo" }` or `{ "kubectl" }` just works |

An unmet requirement skips with a reason that says **which** of three things went wrong: **absent** (install it), **too old** (upgrade it), or a **malformed expression** — and that last one is an *error*, not a skip, because a constraint that can never parse would skip forever and read as green. A version-bearing gate is what lets a suite say "I need .NET 9" and *skip cleanly on 8* instead of failing three minutes into a build.

Also available at suite grain: `suite.config{ requires = {...} }` cascades the gate to every file in the suite.

### `must_run` — turning a skip into a failure

`requires` protects a test from an environment it can't run in. Sometimes you want the opposite: an environment where a capability had **better** be present, and its absence is a bug in the setup — not something to paper over with a green skip. That is `must_run`, declared in [`prova.toml`](../reference/prova-toml.md#must_run):

```toml
[run]
must_run = ["docker"]              # a run here that skips every docker test is a failure, not a pass

[profiles.ci]
must_run = ["docker", "dotnet >= 9"]   # CI guarantees these; an unmet one FAILS the run up front
```

It is the **other direction** of the exact same vocabulary — same expression grammar, same probes. Where `requires` skips, `must_run` **fails**, and it fails **fast**: as a precondition, before any test runs, with the probe's own answer in the message. `[run] must_run` and a profile's `must_run` are additive (a guarantee can't be relaxed by a laxer profile). The point is to stop "0 failed" from hiding "everything skipped" — the most dangerous green there is.

### Custom capabilities: the `prova.lua` companion

The built-ins cover OS, Docker, and anything on `PATH` with a `--version`. For a capability no name-and-version can express — a GPU, a `kind` cluster, a licence file — register your own in an optional **`prova.lua`** file beside `prova.toml`:

```lua
-- prova.lua — loaded WITH the manifest, project-wide
runtime.capability("gpu", function() return probe_cuda() end)          -- true / false
runtime.capability("kind-cluster", function() return #kind_clusters() > 0 end)
runtime.capability("gpu-driver", function() return driver_version() end)  -- a version string → "gpu-driver >= 2" works
```

The predicate returns `true` (available), a **version string** (comparable, so `requires = { "gpu-driver >= 2" }` works), or `false`/`nil` (unavailable). It is evaluated **once per run** at load. Once registered, the name works in **both directions** — `requires = { "gpu" }` to skip, `must_run = ["gpu"]` to fail.

The rules that keep it honest: `prova.lua` lives next to `prova.toml` (found by the same home-anchoring as the manifest, not the cwd); a broken one is a **config error**, not a silent skip; and you cannot shadow a built-in like `docker`. The division of labor mirrors Archetect's `archetype.yaml` + `archetype.lua`: **TOML declares, Lua computes.** The `runtime.*` namespace is available *only* in this companion — calling it from a test raises, because it configures the environment tests run *in*.

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
| "This environment must have Docker/.NET — fail if not" | [`must_run`](../reference/prova-toml.md#must_run) in `prova.toml` |
| "A capability no version string can express (GPU, kind)" | [`runtime.capability`](#custom-capabilities-the-provalua-companion) in `prova.lua` |
| Passing a value between units | a [fixture](./fixtures.md) — never a dependency |

## Next

Continue with [Suites & Shared State](./suites-and-shared-state.md) to share expensive infrastructure across files.
