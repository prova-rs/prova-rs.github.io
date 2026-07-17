---
sidebar_position: 2
---

# shell & net

Run commands and manage long-running processes. `shell.run` is the one-shot "run it, capture output" primitive; `shell.spawn` starts a process that outlives the call — the building block of the boot-then-probe acceptance loop. Both are async under the hood: child processes never block a worker.

Both take `command` as either a **string** or an **argv table**, and the choice picks the execution model:

- A **string** runs through a shell (`sh -c` on Unix, `cmd /C` on Windows), so pipes, redirects, globs, and quoting work verbatim — `shell.run("cargo build 2>&1 | tee log")`.
- An **argv table** runs the program **directly — no shell, no quoting** — so an argument with spaces or metacharacters is passed through untouched: `shell.run({ "git", "commit", "-m", msg })`. Prefer it whenever a value is interpolated from data (it needs a program on `PATH`, not a shell in the image).

## `shell.run(command, opts)`

```lua
shell.run(command, opts?) --> ShellResult
```

Runs a command to completion and captures its output.

| Option | Type | Description |
|---|---|---|
| `cwd` | `string?` | Working directory |
| `env` | `table<string, string\|number\|boolean>?` | Extra environment variables. Scalar values **coerce to strings** — ports stay numbers, flags stay booleans, no `tostring()` ceremony (`8080` → `"8080"`, `true` → `"true"`; integral floats render without a trailing `.0`). Any other value type raises `env.<KEY>: expected string/number/boolean, got <type>`. |
| `timeout` | `string?` | Deadline, e.g. `"120s"` — **raises** if exceeded |
| `check` | `boolean?` | If `true`, a non-zero exit **raises**, carrying the tail of **both** streams (see below) |

**Returns:** a `ShellResult`. Raises if the command cannot be spawned, times out, or exits non-zero with `check = true`.

```lua
local r = shell.run("cat src/main.rs", { cwd = dir })
t:expect(r.code):equals(0)
t:expect(r:ok()):is_true()
t:expect(r.stdout):contains("fn main")

-- Fail fast during setup: non-zero exit raises.
shell.run("cargo build --release", { cwd = dir, check = true, timeout = "300s" })
```

**The `check = true` error carries both streams.** Build tools put failure
detail on either stream (msbuild and pnpm favor stdout), so the raised error
includes the tail (last 4 KB, marked `[... truncated ...]` when cut) of stderr
*and* stdout — no hand-rolled assert prints more:

```text
shell.run: command exited 101 (check=true): cargo build --release
--- stderr ---
error[E0425]: cannot find value `prot` in this scope ...
--- stdout ---
   Compiling app v0.1.0 ...
```

### `ShellResult`

| Member | Type | Description |
|---|---|---|
| `code` | `integer` | Exit code (`-1` if terminated by a signal) |
| `stdout` | `string` | Captured standard output |
| `stderr` | `string` | Captured standard error |
| `duration` | `number` | Wall-clock seconds the command took |
| `result:ok()` | `→ boolean` | `true` iff `code == 0` |

## `shell.spawn(command, opts)`

```lua
shell.spawn(command, opts?) --> Process
```

Starts a long-running command in the background (a booted app, a mock server) and returns a handle. Combined stdout+stderr is **captured** into a bounded buffer — the last **64 KB**, oldest bytes dropped first — and readable at any time via `proc:output()`.

| Option | Type | Description |
|---|---|---|
| `cwd` | `string?` | Working directory |
| `env` | `table<string, string\|number\|boolean>?` | Extra environment variables — same scalar coercion as `shell.run` |

**Returns:** a `Process`. Raises if the command cannot be spawned.

The blessed pattern is to hand the process to the context so it is stopped during teardown — `ctx:manage(proc)` (or equivalently `ctx:defer(function() proc:stop() end)`). The process is also killed if its handle is garbage-collected, but that is a backstop, not the plan. See [Fixtures](../../writing-tests/fixtures.md).

```lua
local service = prova.fixture("service", Scope.File, function(ctx)
  local port = net.free_port()
  local proc = ctx:manage(shell.spawn("./target/release/app", {
    env = { PORT = port, LOGGING_STRUCTURED = true },   -- scalars coerce
  }))
  local base = "http://127.0.0.1:" .. port
  http.wait_for(base .. "/health", { status = 200, timeout = "10s" })
  return { base = base, proc = proc }
end)
```

### `Process`

| Member | Type | Description |
|---|---|---|
| `pid` | `integer?` | OS process id (`nil` if it could not be determined) |
| `proc:stop()` | | Kill the process (SIGKILL) and reap it. Idempotent — stopping twice, or after exit, is a no-op. Async. |
| `proc:wait()` | `→ integer?` | Wait for the process to exit; returns its exit code, or `nil` if it was signalled or already reaped. Async. |
| `proc:running()` | `→ boolean` | Whether the process is still running (reaps it if it has already exited) |
| `proc:output()` | `→ string` | The process's combined stdout+stderr so far. Bounded: the last 64 KB, oldest dropped. |

```lua
t:expect(svc.proc:running()):is_true()
t:expect(svc.proc.pid):gt(0)
```

### Never debug a boot blind

When a spawned app fails to come up, `proc:output()` returns whatever it said —
print it in the failure instead of guessing:

```lua
local proc = ctx:manage(shell.spawn("./target/release/app", { env = { PORT = port } }))
local ok = pcall(http.wait_for, base .. "/health", { status = 200, timeout = "10s" })
if not ok then
  error("app never became ready. Its output so far:\n" .. proc:output())
end
```

### Asserting on log output

`proc:output()` is also the hook for asserting on what the app logs. With
structured (JSON-lines) logging enabled, parse each line with
[`prova.parse`](../lua-api/prova.md#provaparse):

```lua
prova.test("emits structured log lines", function(t)
  local svc = t:use(service)
  http.get(svc.base .. "/health")
  -- Logs are written asynchronously; wait until the line shows up.
  prova.retry(function() return svc.proc:output():find("/health", 1, true) end)

  for _, line in ipairs(prova.parse.lines(svc.proc:output())) do
    if line:sub(1, 1) == "{" then
      local entry = prova.parse.json(line)      -- raises on malformed JSON
      t:expect(entry.level, "log level"):is_truthy()
      t:expect(entry.timestamp, "timestamp"):is_truthy()
    end
  end
end)
```

:::note
The buffer keeps only the most recent 64 KB. Assert on recent activity, or on
markers you know are near the end — a chatty app's boot banner may already have
been dropped by the time the test looks.
:::

## net

A tiny sibling module with a single function.

### `net.free_port()`

```lua
net.free_port() --> integer
```

**Returns:** an OS-assigned free TCP port on `127.0.0.1` (bind to `:0`, read the port, release it). The classic use is a dynamic port for a locally `shell.spawn`ed app — a container gets its random host port from [`docker.run`](docker.md) instead.

:::note
There is an inherent race: the port is free *now*, not guaranteed still free when your app binds it. In practice the window is tiny and this is the standard approach.
:::
