---
sidebar_position: 5
sidebar_label: "Roadmap"
---

# Roadmap

Prova's reference documentation covers **only shipped behavior**; this page is
the single place that tracks what's next. Items here may appear in the editor's
completion (the LuaCATS stubs annotate a small aspirational subset) but are not
yet implemented by the engine — calling them either has no effect or errors.

## Shipped since 0.2.3

- **Snapshot assertions** — `matches_snapshot{ level = "layout"|"content" }`,
  `-u`/`--update-snapshots`, the reviewable `.snap`/`.snap.new` flow, and
  `--unreferenced ignore|warn|delete` reconciliation. See
  [Matchers](./lua-api/matchers.md#matches_snapshot).
- **TAP and JUnit reporters** — `--format tap` on stdout, `--junit PATH` as a
  composing XML file sink. See [CI & Output](../running-prova/ci-and-output.md).
- **Topologies** — `prova.topology(name, [scope,] fn)`: one named environment
  definition consumed by tests *and* the inhabited verbs `prova up` (attached,
  `--fixed` for canonical ports), `prova watch` (re-apply on edit), and the
  detached lifecycle `prova start`/`down`/`ps`. See
  [Topologies](../writing-tests/topologies.md).
- **Profile-scoped plugins** — `[profiles.<name>.plugins]` overlays the
  project-wide `[plugins]` set: the in-repo home for CI-only capabilities. See
  [prova.toml](./prova-toml.md#profile-scoped-plugins).
- **`prova eval`** — one-shot Lua snippets in the full environment (modules,
  plugins, a real transient `ctx` with guaranteed teardown), text or JSON
  output, `-` for stdin. See the [CLI](./cli.md#prova-eval).
- **`prova skill`** — prints the embedded agent skill; `--install` writes
  `.claude/skills/prova/SKILL.md`. See the [CLI](./cli.md#prova-skill).

## Shipped in 0.2

- **Test selection** (0.2.3) — `-k` keyword substrings, `--tags` (with `!` excludes), `--node` exact paths, and `--last-failed`; dependency-aware, flow-atomic, with a `deselected` count in every summary.

Formerly on this page, now documented as regular reference material:

- **The plugin system** — `[plugins]` in `prova.toml`, `--plugin/-P`,
  `require("<name>")`, `prova plugin lint`, and the `prova.containerized` +
  `Container:run` + `prova.parse` authoring surface. See
  [Using plugins](../plugins/using-plugins.md) and
  [Authoring plugins](../plugins/authoring-plugins.md).
- **`prova init`** — scaffolds `prova.toml` and the LuaLS IDE integration
  (replaces the previously planned `prova ide setup`). See the [CLI](./cli.md#prova-init).
- **`shell.spawn` output capture** — combined stdout+stderr kept (last 64 KB)
  and readable via [`Process:output()`](./modules/shell.md#process).
- **Containerized resource `host`/`port` fields** — resources expose the
  primary published port's mapping directly. See
  [docker](./modules/docker.md#containerized-resources-host-and-port).
- **Binary releases** — tag-driven GitHub releases and a Homebrew tap. See
  [Installation](../getting-started/installation.md).

## Planned

| Feature | Status | What to use today |
|---|---|---|
| **MCP mode** (`prova mcp`) | Designed | An MCP server whose tools mirror the CLI one-to-one (`run`, `list`, `eval`, `up`/`down`/`status`), serving the agent skill as its instructions — and holding **warm topologies** so a re-run resolves a held environment in milliseconds instead of re-provisioning. Today: the CLI verbs plus `prova skill`. |
| Failure bundles | Planned | Attach managed process/container output tails to failed-node results. Today: read `proc:output()` yourself and `ctx:log` what matters. |
| Versioned capability requirements (e.g. `requires = { "dotnet>=9" }`) | Planned | Capability gating is **name-only** today (`requires = { "dotnet" }` checks the tool is on `PATH`). Probe the version yourself in a fixture/test — e.g. `shell.run("dotnet --version")` — and `t:skip(...)` when it's too old. |
| `prova test` and other run subcommands | Planned | The bare command: `prova [OPTIONS] [PATHS...]`. See the [CLI](./cli.md). |
| `--shuffle[=seed]` (prove group independence) | Planned | Groups already make no order guarantee; don't rely on definition order. |
| Autouse fixtures (`{ autouse = true }`) | Planned | `use` the fixture explicitly from a test or another fixture. |
| Lifecycle hooks (`before_each` / `after_each` / `before_all` / `after_all`) | Planned | Fixtures: a `Scope.Test` fixture is per-test setup; broader scopes plus `ctx:defer` cover the rest. |
| Test `retries` option | Planned | `prova.retry(fn, opts)` inside the test body for readiness-style retries. |
| Load-test executor over flows | Planned | — |
| Cross-worker `Scope.Suite` fixtures (parallel suites sharing one instance) | Planned | Suites sharing state run within one worker today. |

## Decided against

Two formerly planned features were dropped by design decision — **explicit Lua
parametrization is the idiom**, not a DSL:

- **Parametrized fixtures** (`{ params = ... }` with `ctx:param()`) — use
  `prova.test_each` for data-driven tests, and a plain `for` loop over a
  variants table generating fixtures + groups per variant for matrices;
  separate suites for divergent variants, profiles for environments.
- **A flow-builder fixture handle (`f:use`)** — call `t:use(fixture)` inside a
  step; a `Scope.Flow` fixture is built once per flow and shared across its
  steps, which is the same one-instance-per-flow semantics.
