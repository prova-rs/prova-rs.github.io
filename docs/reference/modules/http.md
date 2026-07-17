---
sidebar_position: 3
---

# http

HTTP verbs, a reusable REST client, and readiness polling — the probes of the boot-then-probe acceptance loop. All requests are async under the hood; call them inside a fixture factory or test body.

:::note HTTP-only in v1
The module speaks plain `http://` — no TLS. It is aimed at localhost services and CI containers, which is where black-box acceptance tests live.
:::

## Verb functions

```lua
http.get(url, opts?)     --> HttpResponse
http.post(url, opts?)    --> HttpResponse
http.put(url, opts?)     --> HttpResponse
http.patch(url, opts?)   --> HttpResponse
http.delete(url, opts?)  --> HttpResponse
http.head(url, opts?)    --> HttpResponse
http.options(url, opts?) --> HttpResponse
```

| Option | Type | Description |
|---|---|---|
| `headers` | `table<string,string>?` | Request headers |
| `json` | `table?` | Request body, JSON-encoded; sets `content-type: application/json` |
| `body` | `string?` | Raw request body (ignored when `json` is given) |
| `timeout` | `string?` | Per-request deadline, e.g. `"5s"` |

**Returns:** an `HttpResponse` for any status code — a 404 or 500 is a response, not an error. Raises only on transport failure (connection refused, timeout, invalid URL).

```lua
local res = http.get(base .. "/index.json")
t:expect(res.status):equals(200)
t:expect(res:json().status):equals("ok")

local created = http.post(base .. "/orders", {
  json = { sku = "widget", qty = 3 },
  headers = { authorization = "Bearer " .. token },
})
t:expect(created.status):equals(201)
```

## `HttpResponse`

| Member | Type | Description |
|---|---|---|
| `status` | `integer` | HTTP status code |
| `body` | `string` | Response body |
| `headers` | `table<string,string>` | Response headers |
| `res:json()` | `→ table` | Decode the body as JSON (raises on non-JSON) |

## `http.wait_for(url, opts)`

```lua
http.wait_for(url, opts?) --> HttpResponse
```

Polls the endpoint with GET until it returns the expected status or the deadline elapses — the readiness gate for anything that boots. Individual failed connections are swallowed while polling.

| Option | Type | Description |
|---|---|---|
| `status` | `integer?` | Expected status (default `200`) |
| `timeout` | `string?` | Overall deadline (default `"30s"`) |
| `every` | `string?` | Poll interval, also the per-attempt timeout (default `"500ms"`) |

**Returns:** the first matching response. **Raises** if the deadline elapses. (The client method `client:wait_for(path, opts)` probes with the client's default headers.)

```lua
local proc = ctx:manage(shell.spawn("./target/release/app --port " .. port))
http.wait_for("http://127.0.0.1:" .. port .. "/health", {
  status = 200, timeout = "10s", every = "100ms",
})
```

## `http.client(opts)`

```lua
http.client(opts) --> HttpClient
```

Builds a reusable REST client: base URL, default headers, and default timeout declared once. The ergonomic path for a suite that hits one service many times.

| Option | Type | Description |
|---|---|---|
| `base_url` | `string` | Required. Prefixed onto each call's path |
| `headers` | `table<string,string>?` | Default headers; per-call headers override by (case-insensitive) name |
| `timeout` | `string?` | Default per-call timeout; per-call `timeout` overrides |

### `HttpClient`

The client mirrors the free functions, taking a **path** instead of a full URL:

```lua
client:get(path, opts?)      --> HttpResponse
client:post(path, opts?)     --> HttpResponse
client:put(path, opts?)      --> HttpResponse
client:patch(path, opts?)    --> HttpResponse
client:delete(path, opts?)   --> HttpResponse
client:head(path, opts?)     --> HttpResponse
client:options(path, opts?)  --> HttpResponse
client:wait_for(path, opts?) --> HttpResponse
```

`path` is joined onto `base_url` with exactly one `/` between them; a path that is itself an absolute `http://`/`https://` URL is used verbatim. Per-call `opts` take the same fields as the free functions and override the client's defaults.

```lua
local api = http.client{
  base_url = "http://" .. c:endpoint(8080),
  headers = { authorization = "Bearer test-token" },
  timeout = "5s",
}

api:wait_for("/health", { timeout = "30s" })
local res = api:post("/orders", { json = { sku = "widget" } })
t:expect(res.status):equals(201)
t:expect(api:get("/orders/" .. res:json().id).status):equals(200)
```

## The `mock` facet: `http.mock`

```lua
http.mock(ctx, opts?) --> MockServer
```

The **fourth door** on a protocol namespace. `client` attaches to a real dependency, `container` provisions a real one, `wait_for` probes one — `mock` provisions a **fake** one: a real HTTP server, in this process, that you stub and then assert on. It is grammar-shaped like any [resource](index.md#the-grammar) — wire `m.url` into the system under test exactly as you would a database's, and it is torn down with the scope that owns it. The listener is bound before `http.mock` returns, so the first request can never race it — no `wait_for` needed.

Reach for a mock on a boundary you **cannot run**, for behavior the real thing won't produce on demand (a 500, a timeout), or to **assert on the interaction itself**. If you *can* run the real dependency, run it (`prova.containerized`) — see [Mocking & Proxying](../../writing-tests/mocking-and-proxies.md) for when each earns its place.

```lua
local m = http.mock(t)
m:on{ method = "GET", path = "/v1/price/A1" }:reply{ status = 200, json = { cents = 999 } }

local res = http.get(m.url .. "/v1/price/A1")
t:expect(res.status):equals(200)
t:expect(res:json().cents):equals(999)
```

### `MockServer`

| Member | Type | Description |
|---|---|---|
| `url` | `string` | `"http://127.0.0.1:<port>"` — how the **test** reaches it |
| `host` | `string` | `"127.0.0.1"` |
| `port` | `integer` | The bound port — **random**, so parallel tests never collide |
| `network` | `table?` | `{ url, host, port }` — a cross-substrate vantage; present **only** with the `network` option (see [below](#reaching-a-mock-from-a-container-the-network-vantage)) |
| `m:on(match)` | `→ MockStub` | Register a stub; `:reply(…)` it |
| `m:received(filter?)` | `→ MockRequest[]` | The journal — every request, in order, as data |
| `m:stop()` | | Stop serving (idempotent; the owning scope calls it too) |

### Stubs — `m:on{match}:reply(reply)`

`m:on` registers a stub and returns it so you can `:reply(…)`. **The first matching stub wins**, in declaration order. An omitted `MockMatch` field does not constrain — `m:on{ path = "/x" }` matches any method.

| `MockMatch` field | Type | Description |
|---|---|---|
| `method` | `string?` | Matched case-insensitively |
| `path` | `string?` | Exact match — a literal `:` is **not** a param (`/models/x:predict` works) |
| `path_matches` | `string?` | A Lua pattern (same dialect as [`:matches(pat)`](../lua-api/matchers.md)) |
| `route` | `string?` | A template — `"/orders/:id"` captures into `req.params.id`. **Segment-wise**, so a param never swallows a `/` |

`route` is the one helper built for stateful fakes: without it you spell a path twice — once as `path_matches = "^/orders/"` and once as `req.path:match("/orders/(.+)$")` — in two dialects free to drift apart.

The `reply` is either a **response table** (terse) or a **function of the request** (the primitive):

```lua
-- a canned table
m:on{ method = "GET", path = "/health" }:reply{ status = 200, json = { ok = true } }

-- a function: real Lua, run at request time while the coroutine driving the SUT is
-- suspended inside http.get — so it computes from the request and closes over test locals
m:on{ method = "GET", route = "/orders/:id" }:reply(function(req)
  local o = orders[req.params.id]
  if not o then return { status = 404, json = { error = "no such order" } } end
  return { status = 200, json = o }
end)
```

That the handler is real Lua is the differentiator: there is **no response-templating language** to learn. A handler is **not given `t`** — do not assert inside it; assert on the journal afterward.

| `MockReply` field | Type | Description |
|---|---|---|
| `status` | `integer?` | Default `200` |
| `json` | `any?` | Encoded as JSON; sets `content-type` unless you set it. Mutually exclusive with `body` |
| `body` | `string?` | A raw body |
| `headers` | `table?` | Response headers |
| `delay` | `string?` | Hold the response this long (`"250ms"`) — **fault injection** |

### The journal — `m:received(filter?)`

Everything the mock was asked, in order, **as data** — so the ordinary matchers assert on it. There is no `verify(count, pattern)` DSL because [`t:expect`](../lua-api/matchers.md) already exists. **Unmatched requests are recorded too**: a call you did not predict is usually the most interesting thing a mock can tell you.

```lua
local calls = m:received{ path = "/v1/orders" }   -- filter: { method?, path? }
t:expect(calls):has_length(1)
t:expect(calls[1].headers["x-idempotency-key"]):is_truthy()
t:expect(calls[1].json.sku):equals("A1")
```

A `MockRequest` is a handler's argument **and** a journal entry — the **same shape**, so `req.path` in a handler and `m:received()[1].path` in an assertion mean the same thing:

| `MockRequest` field | Type | Description |
|---|---|---|
| `method` | `string` | `"GET"`, `"POST"`, … (uppercase) |
| `path` | `string` | Path only; the query string is parsed into `query` |
| `query` | `table` | Parsed and percent-decoded |
| `headers` | `table` | Header names **lowercased** (HTTP names are case-insensitive) |
| `body` | `string` | The raw request bytes |
| `json` | `any?` | The body decoded, when it parses as JSON; `nil` otherwise |
| `params` | `table` | Captures from the stub's `route` (empty for other stubs) |
| `status` | `integer?` | *Journal only:* the status the mock answered with |
| `matched` | `boolean?` | *Journal only:* whether a stub matched |
| `source` | `string?` | *Journal only:* `"stub"` \| `"passthrough"` \| `"replay"` \| `"unmatched"` |
| `error` | `string?` | *Journal only:* why a handler or upstream failed, if it did |

### Passthrough, record, and replay — `MockOpts`

A **proxy is not a second concept**: it is a mock whose *unmatched* requests are forwarded rather than 404'd. Same object, same stubs, same journal — one option. Pass these to `http.mock(ctx, opts)`:

| `MockOpts` field | Type | Description |
|---|---|---|
| `passthrough` | `string?` | Forward **unmatched** requests to this base URL — the dependency stays **real**, and the exchange is journaled (`source = "passthrough"`) |
| `record` | `string?` | Write forwarded exchanges to this cassette file on teardown (**requires** `passthrough`) |
| `replay` | `string?` | Answer from a cassette — **no dependency, no network** (mutually exclusive with `passthrough`) |
| `redact` | `string[]?` | Extra header names to redact in the cassette (auth/cookie headers are redacted anyway) |
| `allow_handler_errors` | `boolean?` | See [below](#raising-handlers-fail-the-scope) |
| `network` | `boolean\|string?` | Expose the `.network` vantage — see [below](#reaching-a-mock-from-a-container-the-network-vantage) |

The load-bearing semantics:

- **Stubs always win over passthrough** — stub one endpoint, let the rest reach the real service (partial mocking).
- **Replay is strict.** An unrecorded call returns **404** — it never invents an answer. That strictness is the feature: a replay that guessed would let the SUT change behavior without the suite noticing.
- **Replay is ordered.** Repeated identical calls replay in the order they were recorded (`(method, path, query)`), so a `create → read-back` sequence reproduces rather than collapsing to its first answer; different endpoints stay order-independent.
- **Cassettes redact credentials by default.** Recording writes real traffic to a file someone will commit; a live bearer token in it is a security incident. The written value carries `REDACTED`. The **in-memory journal is not redacted** — that is where you assert auth was sent.
- **A dead upstream surfaces as `502`**, and is journaled with a truthy `error`.

```lua
-- record against the real service, then replay with it gone — the SAME assertions pass
local cassette = t:tempdir() .. "/pricing.json"

local rec = http.mock(t, { passthrough = real.url, record = cassette })
t:expect(http.get(rec.url .. "/v1/price/A1"):json().cents):equals(999)
rec:stop()  -- writes the cassette

local replay = http.mock(t, { replay = cassette })
t:expect(http.get(replay.url .. "/v1/price/A1"):json().cents):equals(999) -- no dependency
```

### Raising handlers fail the scope

By default a `:reply` handler that **raises** (or returns a non-table) answers `500`, records `error` in the journal, and **fails the owning scope at teardown**. The reason: a SUT with a fallback would swallow the 500 and the suite would go green over a broken handler — reporting prova's own bug as a flaky dependency. Set `allow_handler_errors = true` for a test whose subject **is** the error path:

```lua
local m = http.mock(t, { allow_handler_errors = true })
m:on{ path = "/boom" }:reply(function() error("deliberate") end)
t:expect(http.get(m.url .. "/boom").status):equals(500)
t:expect(m:received()[1].error):contains("deliberate")
```

### Reaching a mock from a container: the network vantage

A mock is the one resource that is a **host process a container must reach** (the inverse of every other resource). By default it binds `127.0.0.1` — reachable by the test, not by a container. Opt in with `network`:

```lua
local m = http.mock(t, { network = true })
-- m.url          is STILL loopback — how the TEST reaches it
-- m.network.url  = "http://host.docker.internal:<port>" — how a CONTAINER reaches it
-- m.network.host = "host.docker.internal"   (a string overrides the host: { network = "gateway.local" })
```

`network = true` binds `0.0.0.0` — a real LAN exposure, which is why it is opt-in and never the default. It closes the "green on your laptop, red in CI" gap: on Docker Desktop `host.docker.internal` egresses from the host, so a loopback bind happens to work; on Linux it resolves to the bridge gateway and a `127.0.0.1`-bound server refuses the connection. Any containerized SUT reaches a host-bound mock this way — [`docker.run`](docker.md)'s `extra_hosts` (and `prova.containerized`, unconditionally) add `host.docker.internal:host-gateway` so the name resolves on Linux too.
