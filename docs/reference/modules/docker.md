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
| `network` | `Network \| string?` | A [user-defined network](#dockernetworkopts) to join at create time (a handle or a name) |
| `alias` | `string?` | DNS alias to answer to on `network` (requires `network`) — siblings resolve it by name |
| `extra_hosts` | `string[]?` | `"name:ip"` entries added to the container's `/etc/hosts` — e.g. `"host.docker.internal:host-gateway"` on Linux, so the container can reach a [host-bound mock](http.md#reaching-a-mock-from-a-container-the-network-vantage) |

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

## `docker.build(opts)`

```lua
docker.build(opts) --> string   -- an image ref, ready for docker.run{ image = ... }
```

Builds a local image from a Dockerfile and returns its ref. This is what turns the **system under test itself** into a container: build the project's own image, then `docker.run` it beside its dependencies — the suite needs only Docker, no host toolchain.

| Option | Type | Description |
|---|---|---|
| `context` | `string` | Required. The build-context directory |
| `dockerfile` | `string?` | Relative to `context` (default `"Dockerfile"`); `COPY` still resolves against the context root |
| `tag` | `string?` | Default: a **stable** tag derived from `context`, so a rebuild replaces it and the layer cache hits |
| `buildargs` | `table?` | `--build-arg` values |
| `target` | `string?` | Multi-stage build target |
| `pull` | `boolean?` | Always re-pull the base image (default `false`) |
| `nocache` | `boolean?` | Ignore the build cache (default `false`) |

```lua
local sut = prova.fixture("app", Scope.Suite, function(ctx)
  local image = docker.build{ context = prova.root }   -- the project's own Dockerfile
  return ctx:manage(docker.run{
    image = image,
    ports = { 8080 },
    env = { DB_URL = t:use(db).url },
    wait = { port = 8080, timeout = "60s" },
  })
end)
```

## `docker.network(opts)`

```lua
docker.network(opts?) --> Network
```

Creates a **user-defined bridge network** with Docker's embedded DNS, so containers joined to it resolve each other by name or `alias`. Manage it with `ctx:manage(net)` so it is removed on teardown. Most suites never call this directly — a [topology](../../writing-tests/topologies.md) auto-creates one and joins every resource to it.

| `DockerNetworkOpts` field | Type | Description |
|---|---|---|
| `name` | `string?` | Override the generated unique `"prova-net-<…>"` name |

```lua
local net = ctx:manage(docker.network())
local db  = docker.run{ image = "postgres:16", network = net, alias = "db",  ports = { 5432 } }
local app = docker.run{ image = image,         network = net, alias = "app", ports = { 8080 },
                        env = { DB_HOST = "db" } }   -- resolves "db" by DNS, container-to-container
```

A `Network` carries its `name` and a `net:remove()` (idempotent, called for you by `ctx:manage`). A container's [`c:network_alias()`](#container) returns the alias it answers to (or `nil`).

## `Container`

| Member | Type | Description |
|---|---|---|
| `id` | `string` | The container id |
| `c:host_port(container_port)` | `→ integer` | The host port a published container port maps to (raises if the port was not published) |
| `c:endpoint(container_port)` | `→ string` | Convenience: `"127.0.0.1:<host_port>"` |
| `c:logs()` | `→ string` | The container's combined stdout+stderr logs. Async. |
| `c:network_alias()` | `→ string?` | The alias this container answers to on its user-defined network (from `docker.run`'s `alias`), or `nil` |
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

The same recipe expresses the **system under test**: give the spec a `build`
(a `docker.build` context) instead of an `image`, and the image is built from the
project's own Dockerfile rather than pulled. A SUT is not a separate concept — it
is a resource whose image is local, so it inherits topology auto-join, the
`resource.network` vantage, readiness, and teardown unchanged. When a resource
joins a [topology](../../writing-tests/topologies.md) network, it also carries a
`network` field (`{ url, host, port }`) — the address a **sibling container**
uses, as opposed to `host`/`port`, which is the loopback address the **test** uses.

## Cleanup

The blessed pattern is `ctx:manage(docker.run{...})` — the [context](../lua-api/context.md) calls `:stop()` during async teardown when the fixture's scope ends (`ctx:defer(function() c:stop() end)` is equivalent). If a test forgets, a last-resort backstop force-removes the container when the handle is garbage-collected, so containers do not leak — but rely on `ctx:manage`, not the backstop.
