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
prova.test("service A boots on :8080", { locks = { prova.port(8080) } }, function(t) --[[ ... ]] end)
prova.test("service B boots on :8080", { locks = { prova.port(8080) } }, function(t) --[[ ... ]] end)

-- Read-only tests against a shared database may overlap each other...
prova.test("report reads the db",    { locks = { prova.reads("db") } }, function(t) --[[ ... ]] end)
prova.test("dashboard reads the db", { locks = { prova.reads("db") } }, function(t) --[[ ... ]] end)

-- ...but a writer against the same token excludes all of them.
prova.test("migration writes the db", { locks = { prova.writes("db") } }, function(t) --[[ ... ]] end)
```

The semantics are readers-writer:

| Declaration | Meaning |
|---|---|
| `prova.writes("db")` | Exclusive hold on a named token |
| `prova.reads("db")` | Concurrent reader: readers overlap; a writer waits for all readers |
| `prova.port(8080)` | Exclusive hold on a host port, machine-scoped |
| `prova.writes("gpu", { scope = "machine" })` | A hold that spans every repository on the machine |
| `serial = true` | Exclusive within this run: never concurrent with anything else in it |

Acquisition is all-or-nothing per unit: no unit ever holds one lock while waiting for another, so
the scheduler cannot deadlock. Locks are also file locks, so they bind every prova instance at the
same home, not just this run; see [Locks, Flakes & Reruns](../running-prova/locks-and-scale.md).
The older spellings (`resources = { … }`, `prova.resource`, `prova.shared`) still work, with a
warning, and retire at 1.0.

:::tip
Lock declarations are inert at `--jobs 1` and enforced above it. Declare them once, when you write the test, and the suite scales out later without touching test code.
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

### Custom capabilities: `[capabilities]`

The built-ins cover the OS, Docker, and anything on `PATH` with a `--version`. For anything else,
declare it in the manifest's `[capabilities]` table: a `command` with its own version arguments and
pattern, or a `package` predicate for a fact no name and version can express (a GPU, a `kind`
cluster, a licence file). Once declared, the name works in both directions: `requires` to skip,
`must_run` to fail. The full grammar is on [Capabilities](../running-prova/capabilities.md).

## Proving concurrency: `prova.barrier`

When concurrency is the property under proof ("two writers really do run at once and neither loses
an update"), a sleep cannot prove it: it fails on a loaded host and passes when a serialized system
happens to overlap. `prova.barrier(token, parties)` waits until `parties` participants have arrived,
then releases them together, so reaching the far side is the proof they were in flight at once:

```lua
for i = 1, 2 do
  prova.test("writer " .. i .. " commits beside the other", function(t)
    local tx = begin_transaction(t)
    prova.barrier("both-in-flight", 2)      -- neither passes until both are here
    t:expect(tx:commit()):equals("ok")
  end)
end
```

The wait is bounded (`timeout` defaults to 30s), and reaching it fails the test, naming how many of
how many arrived. The participants become one selection unit: a `-k`, `--node` or `--last-failed`
that picks some of them would leave the rest waiting. Reach for it when concurrency is what you are
proving, not as general coordination.

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
| "A capability no version string can express (GPU, kind)" | a [`[capabilities]`](../running-prova/capabilities.md) entry backed by a package predicate |
| Passing a value between units | a [fixture](./fixtures.md) — never a dependency |

## Next

Continue with [Suites & Shared State](./suites-and-shared-state.md) to share expensive infrastructure across files.
