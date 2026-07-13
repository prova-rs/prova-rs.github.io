---
sidebar_position: 2
---

# Manifest & Profiles

A `prova.toml` at your repo root turns "how do I run the tests here?" into `prova` — no arguments, no wrapper script, no README archaeology. The manifest names *what* to run and *how*, profiles adapt the same suite to different environments, and CI becomes a one-liner. Explicit path arguments always bypass the manifest; command-line flags always override its values.

## `[run]` — the default profile

The `[run]` table is what `prova` with no arguments executes:

```toml
[run]                       # the default profile
paths  = ["tests"]          # files/dirs to discover (*_test.lua / *.test.lua)
jobs   = 4                  # concurrency — throughput only, never changes meaning
format = "console"          # "console" (human) | "json" (JSONL event protocol)

[run.env]                   # environment variables set for the whole run
LOG_LEVEL = "info"
```

Every field is optional:

- **`paths`** — files and directories to discover tests in.
- **`jobs`** — how many suites may run concurrently (default `1`).
- **`format`** — `"console"` or `"json"` (see [CI & Output](./ci-and-output.md)).
- **`env`** — environment variables applied to the process before any test runs. This is the channel your tests read connection details from.

A manifest that declares no `paths` and no `[suites.*]` is an error — there's nothing to run.

## `[profiles.<name>]` — overlays selected with `--profile`

A profile is a partial `[run]` that overlays the base when you pass `--profile <name>`:

```toml
[profiles.ci]
jobs   = 8
format = "json"
[profiles.ci.env]
CI = "true"

[profiles.smoke]
paths = ["tests/smoke"]
```

The merge semantics are simple and field-wise — **base first, then profile**:

- `paths` — the profile's paths replace the base's *if the profile sets any*; otherwise inherited.
- `jobs` and `format` — the profile's value if set, otherwise the base's.
- `env` — **merged**: base entries first, profile entries added on top (the profile wins on a key both define).

So `prova --profile ci` on the manifest above runs the base `tests` paths with `jobs = 8`, `format = "json"`, and an environment of both `LOG_LEVEL=info` and `CI=true`. `prova --profile smoke` runs only `tests/smoke` but inherits `jobs = 4` from `[run]`. Naming a profile that doesn't exist is an error.

Command-line flags sit on top of all of this: `prova --profile ci --jobs 2` runs the `ci` profile with `jobs` forced to `2`.

## `[suites.<name>]` — explicit suite declarations

By default, a directory's own `suite.lua` groups its subtree into a suite (see [The Command Line](./command-line.md#discovery-rules)). When the grouping you want doesn't match the directory tree, declare it in the manifest:

```toml
[suites.grpc]
paths = ["services/grpc"]           # discovered into ONE suite: files share one state
setup = "services/grpc/suite.lua"   # optional setup file (suite-scoped fixtures live here)

[suites.rest]
paths = ["services/rest"]
```

Each `[suites.<name>]` collects the test files under its `paths` into a single named suite: the files share one Lua state (so `Scope.Suite` fixtures are built once for all of them), and the optional `setup` file runs first. Declared suites run *in addition to* the profile's `paths`, and `--jobs` parallelizes across all suites together. Anything environment- or capability-related belongs in the setup file (`suite.config`) or `[run.env]`, not the suite declaration.

## Worked example: local containers vs. CI services

The payoff of profiles is running the *same suite* against different worlds. Locally you want ephemeral Docker containers your tests start themselves; in CI, the pipeline provides services and hands you a URL. The tests only ever read env — the profile decides what's in it.

```toml
[run]
paths = ["tests/acceptance"]
jobs  = 4
# No DATABASE_URL here: tests that need Postgres start their own container
# via the docker module and derive the URL from it.

[profiles.ci]
jobs   = 8
format = "json"
[profiles.ci.env]
CI = "true"
# DATABASE_URL comes from the CI job itself (a service container), not the manifest.

[profiles.dev]
[profiles.dev.env]
TARGET_BASE_URL = "https://orders.dev.example.com"
```

And the fixture that adapts:

```lua
local pg = prova.fixture("pg", Scope.Suite, function(ctx)
  local url = os.getenv("DATABASE_URL")
  if url then return url end                    -- CI: use the provided service
  local c = ctx:manage(docker.run {             -- local: ephemeral container
    image = "postgres:16",
    env = { POSTGRES_PASSWORD = "secret", POSTGRES_DB = "orders" },
    ports = { 5432 },
    wait = { port = 5432 },
  })
  return "postgres://postgres:secret@127.0.0.1:" .. c:host_port(5432) .. "/orders"
end)
```

- **Laptop:** `prova` — no `DATABASE_URL`, so the fixture starts a container, scoped to the suite and torn down automatically.
- **CI:** the pipeline exports `DATABASE_URL` from a service container and runs `prova --profile ci` — same tests, no Docker-in-Docker, JSONL output for tooling. The matching workflow is shown in [CI & Output](./ci-and-output.md).
- **Dev cluster:** `prova --profile dev` points the suite at a live environment via `TARGET_BASE_URL`.

:::tip
Keep the manifest boring: paths, jobs, format, env. Behavior — which fixtures exist, what they require, how they tear down — belongs in Lua, where it's typed, testable, and visible next to the tests. See [Testing Real Systems](../writing-tests/testing-real-systems.md).
:::

For the complete schema — every table, field, and default — see the [prova.toml reference](../reference/prova-toml.md).
