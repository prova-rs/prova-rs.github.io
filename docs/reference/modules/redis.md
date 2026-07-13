---
sidebar_position: 8
---

# redis

A thin cache client — enough to assert on a cache dependency: check a key the app set, seed a value, count keys. The generic `:command(...)` is the escape hatch for anything not covered. No TLS in v1 (local/CI containers). `redis.container` is the ephemeral-container recipe, the counterpart to [`db.postgres`](db.md#recipes-dbpostgres--dbmysql).

## `redis.connect(url)`

```lua
redis.connect(url) --> RedisConnection
```

| Parameter | Type | Description |
|---|---|---|
| `url` | `string` | `redis://host:port` |

**Returns:** a `RedisConnection`. Async — call inside a fixture factory or test body. Raises if the server is unreachable.

## `RedisConnection`

All command methods are async and raise on a Redis error.

| Member | Type | Description |
|---|---|---|
| `conn:get(key)` | `→ string?` | A key's value, or `nil` if it does not exist |
| `conn:set(key, value)` | | Set a key to a string value |
| `conn:del(key, ...)` | `→ integer` | Delete one or more keys; returns the number removed |
| `conn:exists(key)` | `→ boolean` | Whether a key exists |
| `conn:incr(key, by?)` | `→ integer` | Increment by `by` (default 1); returns the new value |
| `conn:expire(key, seconds)` | | Set a key's time-to-live in seconds |
| `conn:ping()` | `→ string` | PING the server; returns `"PONG"` |
| `conn:command(name, ...)` | `→ any` | Run an arbitrary command (string arguments); returns the raw reply converted to a Lua value — the escape hatch |
| `conn:close()` | | No-op (the connection drops with the handle); present so the connection is `ctx:manage`-able |

```lua
local cache = prova.fixture("redis", Scope.File, function(ctx)
  return redis.container(ctx).conn
end)

prova.group("redis", { requires = { "docker" } }, function(g)
  g:test("set / get round-trips a value", function(t)
    local r = t:use(cache)
    r:set("greeting", "hello")
    t:expect(r:get("greeting")):equals("hello")
    t:expect(r:get("missing")):is_nil()
  end)

  g:test("counters and the escape hatch", function(t)
    local r = t:use(cache)
    t:expect(r:incr("counter")):equals(1)
    t:expect(r:incr("counter", 4)):equals(5)
    r:command("LPUSH", "queue", "job-1")
    t:expect(r:command("LLEN", "queue")):equals(1)
  end)
end)
```

## `redis.container(ctx, opts)`

```lua
redis.container(ctx, opts?) --> RedisResource
```

Provisions an ephemeral Redis in a container, waits for it to accept connections, opens a managed connection, and ties both to the scope. Requires the [`docker`](docker.md) module at call time — gate with `requires = { "docker" }`.

| Parameter | Type | Description |
|---|---|---|
| `ctx` | `Context` | The fixture/test context (first argument, required) |
| `opts.image` | `string?` | Full image ref; overrides `tag` |
| `opts.tag` | `string?` | Image tag (default `"7-alpine"`, image `redis`) |
| `opts.timeout` | `string?` | Readiness deadline (default `"60s"`) |

**Returns:** a `RedisResource`:

| Member | Type | Description |
|---|---|---|
| `url` | `string` | `redis://127.0.0.1:<host_port>` |
| `conn` | `RedisConnection` | An open, managed connection |
| `container` | `Container` | The managed [container handle](docker.md#container) |
