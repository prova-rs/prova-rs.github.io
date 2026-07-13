---
sidebar_position: 4
---

# grpc

A **native, dynamic gRPC client**. There is no `grpcurl` on PATH, no `.proto` files in the repo, and no codegen: the client discovers the server's schema at runtime via **gRPC Server Reflection**, builds request messages from plain Lua tables against the fetched descriptors, and decodes replies back to Lua tables. Prova stays a single self-contained binary.

The server must have reflection enabled (both the current `v1` protocol and the older `v1alpha` many servers still use are supported — prova negotiates automatically). If reflection is off, `grpc.client` fails with a clear message.

:::note Plaintext-only in v1
Like [`http`](http.md), the client speaks plaintext (no TLS) — aimed at localhost servers and CI containers.
:::

## `grpc.client(addr, opts)`

```lua
grpc.client(addr, opts?) --> GrpcClient
```

Builds a client for the server at `addr`, performing reflection **once** to discover every service it advertises. Async — call it inside a fixture factory or test body.

| Parameter | Type | Description |
|---|---|---|
| `addr` | `string` | `"host:port"` or `"http://host:port"` |
| `opts.timeout` | `string?` | Per-call deadline applied to every RPC, e.g. `"30s"` |

**Returns:** a `GrpcClient`. Raises if the server is unreachable or does not expose reflection.

```lua
local server = prova.fixture("grpcbin", Scope.File, function(ctx)
  local c = ctx:manage(docker.run{
    image = "moul/grpcbin",
    ports = { 9000 },
    wait = { port = 9000, timeout = "60s" },
  })
  local addr = "127.0.0.1:" .. c:host_port(9000)
  grpc.wait_for(addr, { timeout = "30s" })
  return grpc.client(addr)
end)
```

## `GrpcClient`

Method names are `"package.Service/Method"` (a leading `/` is accepted). Request tables map onto the method's input message by the proto JSON mapping; response tables carry the full message shape — zero and empty fields are present, with JSON-style (camelCase) field names.

### `client:call(method, request)`

```lua
client:call(method, request?) --> table
```

Invokes a unary method and returns the response as a table. **Raises** on any non-OK gRPC status — the happy path for calls that must succeed.

| Parameter | Type | Description |
|---|---|---|
| `method` | `string` | `"package.Service/Method"` |
| `request` | `table?` | Request message as data (default: empty message) |

```lua
local resp = client:call("hello.HelloService/SayHello", { greeting = "prova" })
t:expect(resp.reply):equals("hello prova")
```

### `client:call_status(method, request)`

```lua
client:call_status(method, request?) --> GrpcStatus
```

Like `call`, but **never raises** on a gRPC error: it returns the status envelope so a test can assert on the status code — the way to test your API's error contract.

```lua
local res = client:call_status("orders.Orders/GetOrder", { id = "missing" })
t:expect(res.ok):is_false()
t:expect(res.code):equals("NotFound")
t:expect(res.message):contains("order")
```

### `GrpcStatus`

| Member | Type | Description |
|---|---|---|
| `ok` | `boolean` | `true` iff the call returned gRPC `Ok` |
| `code` | `string` | Status code name — `"Ok"`, `"NotFound"`, `"InvalidArgument"`, `"Unavailable"`, … |
| `message` | `string` | The server's status message (`""` on success) |
| `response` | `table?` | The decoded response — `nil` unless `ok` |

## `grpc.wait_for(addr, opts)`

```lua
grpc.wait_for(addr, opts?)
```

Polls until the server answers a reflection request or the deadline elapses — the gRPC counterpart to [`http.wait_for`](http.md#httpwait_forurl-opts) for the boot-then-probe pattern.

| Option | Type | Description |
|---|---|---|
| `timeout` | `string?` | Overall deadline (default `"30s"`) |
| `every` | `string?` | Poll interval (default `"500ms"`) |

**Returns:** nothing. **Raises** if the deadline elapses.
