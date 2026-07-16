---
sidebar_position: 6
---

# docker

Testcontainers-style ephemeral dependencies: spin up a real container as a scoped fixture, map a random host port, wait for readiness, drive it over its network interface, remove it on teardown. Backed by the typed **bollard** Docker daemon client (structured errors, streamed logs, exec) — not CLI shelling.

This module is also the substrate the plugin ecosystem stands on: every containerized resource plugin (`postgres`, `redis`, `kafka`, …) is authored through [`prova.containerized`](../lua-api/prova.md#provacontainerized) over `docker.run`, and drives its CLI through [`Container:run`](#containerruncommand-opts). See [Using plugins](../../plugins/using-plugins.md) and [Authoring plugins](../../plugins/authoring-plugins.md).

:::note Requires the Docker daemon
Tests using this module should declare `requires = { "docker" }` (on the test, group, or suite) so they **skip gracefully** where the daemon is absent — see [Dependencies & Scheduling](../../writing-tests/dependencies-and-scheduling.md). Containerized resource plugins carry the same requirement.
:::

## `docker.run(opts)`

```lua
docker.run(opts) --> Container
```

Pulls the image if needed, starts a detached container with the requested ports published on `127.0.0.1`, waits for the readiness gate, and returns a handle. Async — call inside a fixture factory or test body.

| Option | Type | Description |
|---|---|---|
| `image` | `string` | Required. Image ref, e.g. `"postgres:16-alpine"` |
| `command` | `string \| string[]?` | Override the image CMD — `"bin/pulsar standalone"` (whitespace-split) or `{ "bin/pulsar", "standalone" }` |
| `ports` | list | Ports to publish — see below |
| `env` | `table<string,string>?` | Environment variables |
| `wait` | `table?` | Readiness gate — see below |

**Ports.** Each entry is either an integer container port (published to a **random** host port) or a table `{ container = N, host = M }` (a **fixed** host port — needed by e.g. Kafka's advertised listener; a bare `{ N, M }` pair works too):

```lua
ports = { 5432 }                            -- container 5432 → random host port
ports = { { container = 9092, host = 9092 } }  -- fixed mapping
```

**Wait.** The `wait` table gates the return of `docker.run` until the container is actually ready:

| Field | Type | Description |
|---|---|---|
| `port` | `integer?` | Ready when this container port accepts a TCP connection |
| `log` | `string?` | Ready when the container logs contain this substring |
| `timeout` | `string?` | Deadline (default `"30s"`) — raises if not ready in time |
| `every` | `string?` | Poll interval (default `"250ms"`) |

**Returns:** a `Container`. Raises if the image cannot be pulled, the container cannot start, or the wait gate times out.

```lua
local service = prova.fixture("service", Scope.File, function(ctx)
  local c = ctx:manage(docker.run{
    image = "traefik/whoami",              -- tiny public HTTP echo on :80
    ports = { 80 },                        -- published to a random host port
    wait = { port = 80, timeout = "60s" }, -- ready when the port accepts connections
  })
  return c
end)

prova.group("containerized whoami", { requires = { "docker" } }, function(g)
  g:test("responds over the mapped port", function(t)
    local res = http.get("http://" .. t:use(service):endpoint(80) .. "/")
    t:expect(res.status):equals(200)
  end)
end)
```

## `Container`

| Member | Type | Description |
|---|---|---|
| `id` | `string` | The container id |
| `c:host_port(container_port)` | `→ integer` | The host port a published container port maps to (raises if the port was not published) |
| `c:endpoint(container_port)` | `→ string` | Convenience: `"127.0.0.1:<host_port>"` |
| `c:logs()` | `→ string` | The container's combined stdout+stderr logs. Async. |
| `c:run(command, opts?)` | `→ string` | Run a command inside the container; **raises on a non-zero exit** (with the failing stream's trimmed output), returns **stdout**. Async. See below. |
| `c:exec(command)` | `→ integer, string, string` | Low-level, non-raising: run a command inside the container via `sh -c`; returns `(code, stdout, stderr)`. Async. Prefer `c:run` for driving a CLI. |
| `c:stop()` | | Force-remove the container. Idempotent. Async. |

### `Container:run(command, opts)`

The exec-CLI entry point — the primitive every **docker-exec plugin** drives its
resource's CLI through, with no shell-quoting or `printf | …` piping by hand:

- Pass an **argv table** (`{ "psql", "-U", "prova", "-tA", "-c", sql }`) to run
  the program **directly — no shell, no quoting**. This is the form plugins
  should use.
- Pass a **string** to run it under `sh -c` (when you genuinely want pipes,
  globs, or redirects; needs a shell in the image — `FROM scratch` images have
  none).
- `opts.stdin` (`string?`) is piped to the process and the input closed (EOF)
  before output is drained — suited to non-interactive tools that read stdin to
  completion then emit, not to large streaming input.

On a non-zero exit it raises `container:run exited <code>: <detail>` where
`<detail>` is the trimmed stderr (or stdout, if stderr was empty).

```lua
-- Drive the resource's own CLI and parse what it prints — the docker-exec plugin pattern.
local out = c:run({ "psql", "-U", "prova", "-tA", "-F", "\t",
                    "-c", "select id, status from orders" })
local rows = prova.parse.rows(out)          -- see prova.parse
t:expect(rows[1][2]):equals("shipped")

-- String form: a shell when you actually need one.
c:run("redis-cli set greeting hello && redis-cli get greeting")

-- Feed stdin.
c:run({ "psql", "-U", "prova", "-f", "-" }, { stdin = schema_sql })
```

Pair `Container:run` output with [`prova.parse`](../lua-api/prova.md#provaparse)
(`lines` / `rows` / `table` / `json`) to turn CLI text into Lua values.

```lua
local code, out = c:exec("psql -U prova -c 'select 1' -tA")
t:expect(code):equals(0)
t:expect(out):contains("1")
t:expect(c:logs()):contains("database system is ready")
```

## Containerized resources: `host` and `port`

Resources built with [`prova.containerized`](../lua-api/prova.md#provacontainerized)
(first-party recipes and plugins alike) return the standard shape
`{ url, container, host, port, client? }`. Their `host` is `"127.0.0.1"` and
`port` is the **mapped host port of the primary published port** (the spec's
`port`, or the first `ports` entry) — so wiring an app's environment is
`DB_HOST = res.host, DB_PORT = res.port`, with no `host_port()` ceremony.

## Cleanup

The blessed pattern is `ctx:manage(docker.run{...})` — the [context](../lua-api/context.md) calls `:stop()` during async teardown when the fixture's scope ends (`ctx:defer(function() c:stop() end)` is equivalent). If a test forgets, a last-resort backstop force-removes the container when the handle is garbage-collected, so containers do not leak — but rely on `ctx:manage`, not the backstop.
