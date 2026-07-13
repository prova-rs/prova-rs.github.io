---
sidebar_position: 2
---

# shell & net

Run commands and manage long-running processes. `shell.run` is the one-shot "run it, capture output" primitive; `shell.spawn` starts a process that outlives the call — the building block of the boot-then-probe acceptance loop. Both run the command string through a shell (`sh -c` on Unix, `cmd /C` on Windows), so pipes, redirects, and quoting work verbatim. Both are async under the hood: child processes never block a worker.

## `shell.run(command, opts)`

```lua
shell.run(command, opts?) --> ShellResult
```

Runs a command to completion and captures its output.

| Option | Type | Description |
|---|---|---|
| `cwd` | `string?` | Working directory |
| `env` | `table<string,string>?` | Extra environment variables |
| `timeout` | `string?` | Deadline, e.g. `"120s"` — **raises** if exceeded |
| `check` | `boolean?` | If `true`, a non-zero exit **raises** (with the command's stderr) instead of returning |

**Returns:** a `ShellResult`. Raises if the command cannot be spawned, times out, or exits non-zero with `check = true`.

```lua
local r = shell.run("cat src/main.rs", { cwd = dir })
t:expect(r.code):equals(0)
t:expect(r:ok()):is_true()
t:expect(r.stdout):contains("fn main")

-- Fail fast during setup: non-zero exit raises.
shell.run("cargo build --release", { cwd = dir, check = true, timeout = "300s" })
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

Starts a long-running command in the background (a booted app, a mock server) and returns a handle. stdout/stderr are **discarded** in v1.

| Option | Type | Description |
|---|---|---|
| `cwd` | `string?` | Working directory |
| `env` | `table<string,string>?` | Extra environment variables |

**Returns:** a `Process`. Raises if the command cannot be spawned.

The blessed pattern is to hand the process to the context so it is stopped during teardown — `ctx:manage(proc)` (or equivalently `ctx:defer(function() proc:stop() end)`). The process is also killed if its handle is garbage-collected, but that is a backstop, not the plan. See [Fixtures](../../writing-tests/fixtures.md).

```lua
local service = prova.fixture("service", Scope.File, function(ctx)
  local port = net.free_port()
  local proc = ctx:manage(shell.spawn("./target/release/app --port " .. port))
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

```lua
t:expect(svc.proc:running()):is_true()
t:expect(svc.proc.pid):gt(0)
```

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
