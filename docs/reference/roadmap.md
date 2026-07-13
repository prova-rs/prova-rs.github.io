---
sidebar_position: 5
sidebar_label: "Roadmap"
---

# Roadmap

Prova's reference documentation covers **only shipped behavior**; this page is
the single place that tracks what's next. Items here may appear in the editor's
completion (the LuaCATS stubs annotate a small aspirational subset) but are not
yet implemented by the engine — calling them either has no effect or errors.

| Feature | Status | What to use today |
|---|---|---|
| `prova test` and other subcommands | Planned | The bare command: `prova [OPTIONS] [PATHS...]`. See the [CLI](./cli.md). |
| Name filtering (`-k`) and tag expressions (`--tags`) | Planned | Point `prova` at specific files/directories, or split subsets into [manifest profiles](./prova-toml.md). `tags` on a test are accepted and recorded but do not yet select anything. |
| `--last-failed`, sharding | Planned | Re-run the failing file directly. |
| `--shuffle[=seed]` (prove group independence) | Planned | Groups already make no order guarantee; don't rely on definition order. |
| Snapshot assertions (`:matches_snapshot()`, `--update-snapshots`) | Planned | Read files with `fs` and assert with `:equals()` / `:contains()` / `:matches()`. |
| Output formats: TAP, pretty, JUnit XML | Planned | `--format console` or `--format json` (JSONL events). |
| Parametrized fixtures (`{ params = ... }`, `ctx:param()`) | Planned | Table-driven tests via `prova.test_each`. |
| Autouse fixtures (`{ autouse = true }`) | Planned | `use` the fixture explicitly from a test or another fixture. |
| Lifecycle hooks (`before_each` / `after_each` / `before_all` / `after_all`) | Planned | Fixtures: a `Scope.Test` fixture is per-test setup; broader scopes plus `ctx:defer` cover the rest. |
| Flow-scoped fixture handle (`f:use`) on the flow builder | Planned | Call `t:use(fixture)` inside a step; a `Scope.Flow` fixture is built once per flow and shared across its steps. |
| Test `retries` option | Planned | `prova.retry(fn, opts)` inside the test body for readiness-style retries. |
| `prova ide setup` | Planned | Point your `.luarc.json` `workspace.library` at Prova's `library/` stubs by hand. See [IDE setup](../running-prova/ide-setup.md). |
| Binary releases | Planned | Build from source with `cargo`. See [Installation](../getting-started/installation.md). |
| Load-test executor over flows | Planned | — |
| Cross-worker `Scope.Suite` fixtures (parallel suites sharing one instance) | Planned | Suites sharing state run within one worker today. |
