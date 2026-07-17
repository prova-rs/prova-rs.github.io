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

Method names are `"package.Service/Method"` (a leading `/` is accepted). Request tables map onto the method's input message by the proto JSON mapping; response tables carry the full message shape — zero and empty fields are present, field names are the proto (snake_case) names you used in the request, and 64-bit integers arrive as Lua numbers. What you send is the shape you read back.

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

## The `mock` facet: `grpc.mock`

```lua
grpc.mock(ctx, opts) --> GrpcMock
```

The [`mock` facet](http.md#the-mock-facet-httpmock), carried to gRPC unchanged: a real gRPC server, in this process, that you stub and assert on. It **serves reflection** (via `tonic-reflection`), so the unmodified [`grpc.client`](#grpcclientaddr-opts) drives it with no special case — *if the real client can't tell it from a server, it is a server* — and `m.url` wires into a system under test exactly as a real service's would.

Unlike `grpc.client`, a mock **must be told its schema.** The client needs no `.proto` because it learns one *from the server* by reflection; a mock **is** the server, so there is nobody to learn from. Hence `proto`, compiled at runtime by **protox** (pure Rust — no `protoc` on PATH).

```lua
local m = grpc.mock(t, { proto = t:use(proto) })

m:on{ method = "pricing.Pricing/GetPrice" }:reply{ response = { sku = "A1", cents = 999 } }
m:on{ method = "pricing.Pricing/OutOfStock" }:reply{ code = "NotFound", message = "unknown sku" }
m:on{ method = "pricing.Pricing/Quote" }:reply(function(call)
  return { response = { sku = call.request.sku, cents = 100 * call.request.qty } }
end)

local c = grpc.client(m.url)                    -- reflection: no .proto on this side
c:call("pricing.Pricing/GetPrice", { sku = "A1" })
```

### `GrpcMockOpts`

| Field | Type | Description |
|---|---|---|
| `proto` | `string \| string[]` | `.proto` path(s), compiled at runtime |
| `includes` | `string[]?` | Import paths (default: each proto's own directory) |
| `allow_handler_errors` | `boolean?` | A raising `:reply` handler normally **fails the owning scope** at teardown; set true when the error path is the subject — see [http.mock](http.md#raising-handlers-fail-the-scope) |
| `network` | `boolean\|string?` | Expose a `.network` host-gateway vantage — see [http.mock](http.md#reaching-a-mock-from-a-container-the-network-vantage) |

### Stubs, replies, and the journal

`GrpcMock` mirrors `MockServer`: `m:on(match):reply(reply)`, `m:received(filter?)`, `m:stop()`. Only the vocabulary inside the tables changes — a reply is a **message or a status**, not an HTTP body.

| `GrpcMockMatch` | Type | Description |
|---|---|---|
| `method` | `string?` | Exact — `"package.Service/Method"` |
| `method_matches` | `string?` | A Lua pattern |

| `GrpcMockReply` | Type | Description |
|---|---|---|
| `response` | `any?` | The reply message, as a table (default: an empty message) |
| `code` | `string?` | A non-Ok status name — `"NotFound"`, `"ResourceExhausted"`, … (default `"Ok"`) |
| `message` | `string?` | The status message, for a non-Ok code |
| `delay` | `string?` | Hold the reply this long (`"250ms"`) — fault injection |

`response` and `code` are mutually exclusive: an RPC returns a message or a status. `code` uses the **spelling [`client:call_status`](#clientcall_statusmethod-request) reports**, so what a failure tells you is what you write to reproduce it.

`m:received(filter?)` returns `GrpcMockCall[]` — `{ method, request }`, plus journal-only `code` / `matched` / `error`. **Unstubbed calls are recorded too**, and answer `Unimplemented`. `grpc.mock` is **unary-only**, matching the client; `{ response = … }`-style stubs and journal assertions are the whole surface.
