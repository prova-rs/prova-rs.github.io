---
sidebar_position: 6
---

# docker

Testcontainers-style ephemeral dependencies: spin up a real container as a scoped fixture, map a random host port, wait for readiness, drive it over its network interface, remove it on teardown. Backed by the typed **bollard** Docker daemon client (structured errors, streamed logs, exec) — not CLI shelling.

:::note Requires the Docker daemon
Tests using this module should declare `requires = { "docker" }` (on the test, group, or suite) so they **skip gracefully** where the daemon is absent — see [Dependencies & Scheduling](../../writing-tests/dependencies-and-scheduling.md). The [Postgres & MySQL](databases.md), [`redis`](redis.md), [Kafka & Pulsar](messaging.md), and [`s3`](s3.md) container recipes all build on `docker.run` and carry the same requirement.
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
| `c:exec(command)` | `→ integer, string, string` | Run a command inside the container via `sh -c`; returns `(code, stdout, stderr)`. Async. Needs a shell in the image — `FROM scratch` images have none. |
| `c:stop()` | | Force-remove the container. Idempotent. Async. |

```lua
local code, out = c:exec("psql -U prova -c 'select 1' -tA")
t:expect(code):equals(0)
t:expect(out):contains("1")
t:expect(c:logs()):contains("database system is ready")
```

## Cleanup

The blessed pattern is `ctx:manage(docker.run{...})` — the [context](../lua-api/context.md) calls `:stop()` during async teardown when the fixture's scope ends (`ctx:defer(function() c:stop() end)` is equivalent). If a test forgets, a last-resort backstop force-removes the container when the handle is garbage-collected, so containers do not leak — but rely on `ctx:manage`, not the backstop.
