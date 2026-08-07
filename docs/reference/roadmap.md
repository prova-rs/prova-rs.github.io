---
sidebar_position: 5
sidebar_label: "Roadmap"
---

# Roadmap

Prova's reference documentation covers **only shipped behavior**; this page is
the single place that tracks what's next. Items here may appear in the editor's
completion (the LuaCATS stubs annotate a small aspirational subset) but are not
yet implemented by the engine — calling them either has no effect or errors.

## Planned

| Feature | Status | What to use today |
|---|---|---|
| Standalone interposing proxies (sit between the SUT and a *real* dependency without terminating the stream) | Designed | [Partial mocking](../writing-tests/mocking-and-proxies.md) — `http.mock(ctx, { target = ... })` passthrough/record/replay — covers observe-and-override for HTTP today; run toxiproxy as a resource for raw-TCP fault injection. |
| Formal verifiers (TLA+/TLC over a pinned image) as a deputed-verifier package | Designed | The `junit` seam covers test-framework deputies today. |
| TAP ingestion (a deputy that reports TAP instead of JUnit XML) | Planned | Most tools can emit JUnit XML; use that seam. |
| Per-case re-run translation for deputed cases (`--last-failed` → the deputy's own selector) | Planned | Re-run the deputy yourself with its native selection. |
| A burndown lane in CI (a scheduled job that *works* the open promise surface, not just reports it) | Designed | `prova burndown` locally; CI reports open promises without failing. |
| Placement: distributing units across machines (the broker `prova broker` scaffolds the spec for) | Design | `-j` concurrency on one machine; lanes to split the suite across CI jobs. |
| Failure bundles | Planned | Attach managed process/container output tails to failed-node results. Today: read `proc:output()` yourself and `ctx:log` what matters. |
| `net.mock` / `graphql.mock` | Planned | The [`mock` facet](../writing-tests/mocking-and-proxies.md) covers `http`, `grpc`, `socket`, `websocket`, `terminal`, and `shell` today; stub GraphQL over `http.mock`. |
| `--shuffle[=seed]` (prove group independence) | Planned | Groups already make no order guarantee; don't rely on definition order. |
| Autouse fixtures (`{ autouse = true }`) | Planned | `use` the fixture explicitly from a test or another fixture. |
| Lifecycle hooks (`before_each` / `after_each` / `before_all` / `after_all`) | Planned | Fixtures: a `Scope.Test` fixture is per-test setup; broader scopes plus `ctx:defer` cover the rest. |
| Test `retries` option | Planned | `prova.retry(fn, opts)` inside the test body for readiness-style retries. |
| Load-test executor over flows | Planned | — |
| Cross-worker `Scope.Suite` fixtures (parallel suites sharing one instance) | Planned | Suites sharing state run within one worker today. |

## Decided against

Formerly planned features dropped by design decision — **explicit Lua
parametrization is the idiom**, not a DSL:

- **Parametrized fixtures** (`{ params = ... }` with `ctx:param()`) — use
  `prova.test_each` for data-driven tests, and a plain `for` loop over a
  variants table generating fixtures + groups per variant for matrices;
  separate suites for divergent variants, profiles for environments.
- **A flow-builder fixture handle (`f:use`)** — call `t:use(fixture)` inside a
  step; a `Scope.Flow` fixture is built once per flow and shared across its
  steps, which is the same one-instance-per-flow semantics.
- **Promise-aware `depends_on`** (gating a unit on a promise's state) — parked:
  the promise surface is a reporting axis, not a scheduling one.
