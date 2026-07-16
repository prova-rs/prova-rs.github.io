---
sidebar_position: 5
sidebar_label: "Roadmap"
---

# Roadmap

Prova's reference documentation covers **only shipped behavior**; this page is
the single place that tracks what's next. Items here may appear in the editor's
completion (the LuaCATS stubs annotate a small aspirational subset) but are not
yet implemented by the engine — calling them either has no effect or errors.

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
| `prova test` and other run subcommands | Planned | The bare command: `prova [OPTIONS] [PATHS...]`. See the [CLI](./cli.md). |
| `--shuffle[=seed]` (prove group independence) | Planned | Groups already make no order guarantee; don't rely on definition order. |
| Snapshot assertions (`:matches_snapshot()`, `--update-snapshots`) | Planned | Read files with `fs` and assert with `:equals()` / `:contains()` / `:matches()`. |
| Output formats: TAP, pretty, JUnit XML | Planned | `--format console` or `--format json` (JSONL events). |
| Parametrized fixtures (`{ params = ... }`, `ctx:param()`) | Planned | Table-driven tests via `prova.test_each`. |
| Autouse fixtures (`{ autouse = true }`) | Planned | `use` the fixture explicitly from a test or another fixture. |
| Versioned capability requirements (e.g. `requires = { "dotnet>=9" }`) | Planned | Capability gating is **name-only** today (`requires = { "dotnet" }` checks the tool is on `PATH`). Probe the version yourself in a fixture/test — e.g. `shell.run("dotnet --version")` — and `t:skip(...)` when it's too old. |
| Lifecycle hooks (`before_each` / `after_each` / `before_all` / `after_all`) | Planned | Fixtures: a `Scope.Test` fixture is per-test setup; broader scopes plus `ctx:defer` cover the rest. |
| Flow-scoped fixture handle (`f:use`) on the flow builder | Planned | Call `t:use(fixture)` inside a step; a `Scope.Flow` fixture is built once per flow and shared across its steps. |
| Test `retries` option | Planned | `prova.retry(fn, opts)` inside the test body for readiness-style retries. |
| Load-test executor over flows | Planned | — |
| Cross-worker `Scope.Suite` fixtures (parallel suites sharing one instance) | Planned | Suites sharing state run within one worker today. |
