---
sidebar_position: 3
---

# CI & Output

Prova's executor never prints — it emits a structured event stream, and output formats are just consumers of it. Today two consumers ship in the CLI: `console` for humans and `json` for machines. That, plus exit codes (`0` pass, `1` failures, `2` usage error), is everything CI needs.

## Console output

The default. One line per finished test, a failure message where there is one, and a summary:

```text
  PASS  orders api › creates an order  (12.4ms, 3 assert)
  FAIL  orders api › rejects an empty cart  (8.1ms, 1 assert)
          ↳ expected status 422, got 200
  SKIP  admin api › bulk import  (0.0ns, 0 assert)

1 passed, 1 failed, 1 skipped   in 21.0ms
```

Each line shows the node path (group names joined with `›`), the duration, and how many assertions the body executed — `0 assert` on a pass is your cue that a test isn't actually checking anything.

## `--format json` — the JSONL event stream

`prova --format json` (or `--json`) streams one JSON object per line to stdout, in order, as the run executes. This is the wire protocol a CI parser, dashboard, or IDE frontend consumes — line-delimited, so you can process it live without waiting for the run to finish.

An annotated run:

```json
{"type":"run_started"}
{"type":"node_started","path":"orders api › creates an order"}
{"type":"node_finished","path":"orders api › creates an order","outcome":"passed","durationMs":12.4,"assertions":3,"message":null}
{"type":"node_started","path":"orders api › rejects an empty cart"}
{"type":"node_finished","path":"orders api › rejects an empty cart","outcome":"failed","durationMs":8.1,"assertions":1,"message":"expected status 422, got 200"}
{"type":"run_finished","passed":1,"failed":1,"skipped":1,"durationMs":21.0}
```

Four event types:

| Event | Fields | Meaning |
|---|---|---|
| `run_started` | — | The run began |
| `node_started` | `path` | A test (or flow step) began executing |
| `node_finished` | `path`, `outcome`, `durationMs`, `assertions`, `message` | A test finished: `outcome` is `"passed"` / `"failed"` / `"skipped"`; `assertions` counts the assertions the body executed; `message` is the failure (or skip) reason, `null` otherwise |
| `run_finished` | `passed`, `failed`, `skipped`, `durationMs` | Totals for the whole run |

Consuming it in a pipeline is a `jq` one-liner away:

```shell
# every failure with its message
prova --json | jq -r 'select(.type == "node_finished" and .outcome == "failed") | "\(.path): \(.message)"'

# the summary line as a GitHub Actions notice
prova --json | jq -r 'select(.type == "run_finished") | "::notice::\(.passed) passed, \(.failed) failed, \(.skipped) skipped"'
```

The exit code still carries the verdict (`1` on any failure), so parsing is for *detail*, never for pass/fail.

:::note Planned
Additional reporter formats — TAP, a JUnit-style XML writer, and a richer `pretty` console — are on the [roadmap](../reference/roadmap.md). The reporter seam is designed for it: they'll be new consumers of the same event stream, and JSONL output will not change shape.
:::

## The GitHub Action

The composite action `prova-rs/run-action` installs a released `prova` binary (no Rust toolchain, no build step) and runs your suite. With a `prova.toml` checked in, the minimal job is:

```yaml
- uses: actions/checkout@v4
- uses: prova-rs/run-action@v1
  with:
    profile: ci
```

Inputs:

| Input | Default | Description |
|---|---|---|
| `version` | `v0.2.2` | The [Prova release](https://github.com/prova-rs/prova/releases) to install |
| `paths` | — | Files/dirs to run. Setting this bypasses the manifest. |
| `manifest` | `prova.toml` | Path to the suite manifest |
| `profile` | — | Manifest profile to run (`prova --profile <profile>`) |
| `jobs` | — | Run up to N suites concurrently |
| `format` | `console` | `console` or `json` |
| `working-directory` | `.` | Directory to run `prova` from |
| `args` | — | Extra arguments appended to the invocation |
| `plugins` | — | Ad-hoc plugins, one `name = source` per line, layered over the manifest |
| `cache-plugins` | `true` | Cache fetched git plugins across runs (`false` to disable) |

The action also puts `prova` on `PATH`, so later steps in the same job can invoke it directly. Runners: Linux (x86_64/arm64) and macOS (arm64).

### Plugins in CI

Nothing extra is needed for a suite that declares [plugins](/docs/plugins/using-plugins) in `prova.toml` — Prova fetches and pins them in CI exactly as it does locally. The action just makes that fast: by default it caches the plugin clone directory (`~/.cache/prova/plugins`), keyed on the manifest, so pinned plugins clone once and reuse across runs; a changed pin invalidates the key and only the changed plugins re-fetch. Disable with `cache-plugins: false`.

The `plugins:` input is an escape hatch (it expands to [`--plugin` flags](./command-line.md#--plugin--p)), not a second place to declare dependencies — reach for it only when the plugin is a fact about *this CI job* rather than the project, like a nightly-only load-test capability:

```yaml
- uses: prova-rs/run-action@v1
  with:
    profile: nightly
    plugins: |
      loadtest = acme/prova-loadtest@v2   # CI-only; not in prova.toml on purpose
```

### Example: suite against a CI-provided Postgres

This is the CI half of the [local-vs-CI profile pattern](./manifest-and-profiles.md#worked-example-local-containers-vs-ci-services): the workflow provides Postgres as a service container and exports `DATABASE_URL`; the tests read env and never know the difference from a locally-started container.

```yaml
name: acceptance
on: [push, pull_request]

jobs:
  prova:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: secret
          POSTGRES_DB: orders
        ports:
          - 5432:5432
        options: >-
          --health-cmd "pg_isready"
          --health-interval 5s
          --health-timeout 5s
          --health-retries 10
    env:
      DATABASE_URL: postgres://postgres:secret@localhost:5432/orders
    steps:
      - uses: actions/checkout@v4
      - uses: prova-rs/run-action@v1
        with:
          profile: ci
```

## Capability gating in constrained runners

Not every runner has everything. A test (or a whole suite, via `suite.config`) can declare `requires = { "docker" }` — when the capability is unavailable, the test is **skipped, not failed**, with a visible reason. The run still exits `0` if nothing failed, so a constrained runner degrades gracefully instead of going red.

Built-in detectors: `"docker"` probes that the daemon actually responds (not just that the client is installed), `"github"` checks for a `GITHUB_TOKEN`, and any other name is treated as "a binary of that name on `PATH`" — so `requires = { "kubectl" }` just works. Skips show up in both output formats (`"outcome":"skipped"` in JSONL), so a runner silently skipping half your suite is visible in the totals, not hidden.

```lua
prova.test("migrates a fresh database", { requires = { "docker" } }, function(t)
  -- skipped, with a reason, wherever the docker daemon is unreachable
end)
```

See [Dependencies & Scheduling](../writing-tests/dependencies-and-scheduling.md) for the authoring side, and the [CLI Reference](../reference/cli.md) for the flag details.
