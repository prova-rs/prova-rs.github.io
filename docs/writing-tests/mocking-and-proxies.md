---
sidebar_position: 9
---

# Mocking & Proxying

Prova's thesis is **run the real thing**: boot the actual service, provision the actual database, probe it black-box. So a mock has to earn its place. Three situations earn it:

1. **A boundary you cannot run** — a third-party payment API, a partner service with no container, a dependency that costs money per call.
2. **Behavior the real thing won't produce on demand** — a `500`, a timeout, a malformed body, a specific error code. Proving your retry logic needs a dependency that fails when you say so.
3. **The interaction itself is the subject** — not "did it work" but "what did we send". A real dependency will never tell you which headers it received.

If none of those hold — if you *can* run the real dependency — run it (`prova.containerized`). A mock that stands in for a service you could have booted is a second definition of that service's behavior, and the two drift.

## The `mock` facet

Every network-driving namespace has a `mock` door alongside `client`, `container`, and `wait_for`. `http.mock(ctx)` and `grpc.mock(ctx, opts)` each provision a **real server, in this process** — not a stub library, not a matcher on the wire, an actual listener you point the system under test at:

```lua
local m = http.mock(t)
m:on{ method = "GET", path = "/v1/price/A1" }:reply{ status = 200, json = { cents = 999 } }

-- m.url is a real URL. Wire it into the SUT exactly as you would a database's.
local res = http.get(m.url .. "/v1/price/A1")
t:expect(res:json().cents):equals(999)
```

A mock is a [resource](../reference/modules/index.md#the-grammar): it carries `url` / `host` / `port`, and it is torn down with the scope that owns it. Its port is random, so parallel tests never collide, and its listener is bound before `mock` returns — the first request cannot race it.

## Stubs and reply handlers

`m:on{match}:reply(reply)` registers a stub. **The first matching stub wins**, in declaration order. A reply is either a **table** (canned) or a **function of the request** (computed):

```lua
-- canned
m:on{ method = "GET", path = "/health" }:reply{ status = 200, json = { ok = true } }

-- computed: a real Lua function, run at request time
m:on{ method = "GET", route = "/orders/:id" }:reply(function(req)
  local o = orders[req.params.id]
  if not o then return { status = 404, json = { error = "no such order" } } end
  return { status = 200, json = o }
end)
```

The handler is **real Lua**, run on the same Lua state at request time while the coroutine driving the SUT is suspended inside `http.get`. It computes from the request and closes over your test's locals. This is the whole point: there is **no response-templating mini-language** — no Handlebars, no JSONPath DSL — because the language is Lua. (A handler is not handed `t`; don't assert inside it. Assert on the journal, below.)

The `route` template captures path segments into `req.params` — `"/orders/:id"` makes `req.params.id` available. It exists so you don't spell a path twice, once to match and once to extract, in two dialects that can drift.

## Stateful fakes

Because a reply handler is real Lua closing over your fixture, **state is just a table you mutate** — there is no state API to learn:

```lua
local api = prova.fixture("api", Scope.Suite, function(ctx)
  local orders, seq = {}, 0
  local m = http.mock(ctx)

  m:on{ method = "POST", path = "/orders" }:reply(function(req)
    seq = seq + 1
    local id = "o-" .. seq
    orders[id] = { id = id, sku = req.json.sku, status = "open" }
    return { status = 201, json = orders[id] }
  end)

  m:on{ method = "POST", route = "/orders/:id/cancel" }:reply(function(req)
    local o = orders[req.params.id]
    if not o then return { status = 404 } end
    o.status = "cancelled"
    return { status = 204 }
  end)

  -- Hand the state back alongside the url: asserting on how the fake's world
  -- changed needs no API, because `orders` is just a Lua table.
  return { base = m.url, orders = orders, mock = m }
end)
```

Now a test can assert on the **fake's own state** and the **interaction** — two things a real dependency would never expose — and express a `404` that *depends on what was created*, which a static stub table cannot:

```lua
prova.test("cancelling moves the fake's world", function(t)
  local svc = t:use(api)
  local order = http.post(svc.base .. "/orders", { json = { sku = "widget" } }):json()
  http.post(svc.base .. "/orders/" .. order.id .. "/cancel")

  t:expect(svc.orders[order.id].status):equals("cancelled")            -- the state moved
  t:expect(svc.mock:received{ path = "/orders/" .. order.id .. "/cancel" }):has_length(1)
end)
```

## The journal — asserting on interactions

`m:received(filter?)` returns every request the mock saw, in order, **as plain data** — so the ordinary [matchers](../reference/lua-api/matchers.md) assert on it. There is no `verify(count, pattern)` DSL because `t:expect` already exists. **Unmatched requests are recorded too** — a call you didn't predict is often the most interesting thing a mock can tell you.

```lua
local calls = m:received{ method = "POST", path = "/v1/orders" }
t:expect(calls):has_length(1)
t:expect(calls[1].headers["x-idempotency-key"]):is_truthy()
t:expect(calls[1].json.sku):equals("A1")
```

A journal entry and a handler's argument are the [**same shape**](../reference/modules/http.md#the-journal--mreceivedfilter), so `req.path` in a handler and `m:received()[1].path` in an assertion mean the same thing.

## Fault injection

The behavior the real thing won't produce on demand is a one-liner. A non-2xx status is just a reply; a slow dependency is `delay`:

```lua
m:on{ path = "/flaky" }:reply{ status = 503 }                       -- prove your retry
m:on{ path = "/slow"  }:reply{ status = 200, delay = "3s" }         -- prove your timeout
```

## Proxying: observe, record, replay

**A proxy is not a second concept.** It is a mock whose *unmatched* requests are **forwarded to a real upstream** instead of answered `404`. Same object, same stubs, same journal — one option turns it on. That yields a spectrum from fully-faked to fully-real, dialed per endpoint:

| Mode | Options | The dependency is | Answers the question |
|---|---|---|---|
| **stub** | *(none)* | absent | "does my code handle *this* response?" |
| **observe** | `{ passthrough = real.url }` | **real** | "what did we actually send it?" |
| **record** | `{ passthrough = real.url, record = "cassette" }` | real (then captured) | "…and can I replay it later?" |
| **replay** | `{ replay = "cassette" }` | absent (hermetic) | "does the recorded contract still hold?" |

**Observe** is the only mode that is purely additive to the black-box thesis — the dependency is real, the traffic is real, and you merely watched:

```lua
local proxy = http.mock(t, { passthrough = real.url })
http.post(proxy.url .. "/v1/orders", {
  json = { sku = "A1" }, headers = { ["X-Idempotency-Key"] = "k-42" },
})

-- the REAL service composed the answer, and we still know exactly what was said to it
local calls = proxy:received{ method = "POST", path = "/v1/orders" }
t:expect(calls[1].headers["x-idempotency-key"]):equals("k-42")
```

**Stubs still win over passthrough**, so you can fake one endpoint and let the rest reach the real service — partial mocking.

**Record then replay** is the payoff, and the reason observe/replay earns its place over hand-written stubs: the **same assertions pass** against the real service and against its recording. Prove the contract where the service exists; run hermetically where it doesn't.

```lua
local cassette = t:tempdir() .. "/pricing.json"

local rec = http.mock(t, { passthrough = real.url, record = cassette })
t:expect(http.get(rec.url .. "/v1/price/A1"):json().cents):equals(999)
rec:stop()   -- writes the cassette

local replay = http.mock(t, { replay = cassette })
t:expect(http.get(replay.url .. "/v1/price/A1"):json().cents):equals(999)  -- no dependency
```

Three properties make replay trustworthy rather than convenient:

- **It is strict.** A call the cassette never recorded returns `404` — it never invents an answer. A replay that guessed would let the SUT change behavior without the suite noticing, which is the exact failure cassettes exist to catch.
- **It is ordered.** Repeated identical calls replay in recorded order, so a `create → read-back` sequence reproduces instead of collapsing to its first answer.
- **It redacts by default.** Recording writes real traffic to a file someone will commit; a live bearer token in it is a security incident. Auth and cookie headers are written as `REDACTED` (add more with `redact = { "X-Tenant" }`). The in-memory journal is *not* redacted — that is where you assert auth was sent.

A dead upstream during passthrough surfaces as a `502` and is journaled, so a proxy never hangs a test on a dependency that vanished.

## gRPC mocks

[`grpc.mock`](../reference/modules/grpc.md#the-mock-facet-grpcmock) carries the same facet to gRPC — same `:on/:reply/:received` shape, different vocabulary inside the tables (a reply is a `response` message **or** a `code` status, not an HTTP body). It **serves reflection**, so the unmodified `grpc.client` drives it; and because a mock *is* the server, it must be told its schema (`proto = …`, compiled at runtime with no `protoc`):

```lua
local m = grpc.mock(t, { proto = t:use(proto) })
m:on{ method = "pricing.Pricing/GetPrice" }:reply{ response = { sku = "A1", cents = 999 } }
m:on{ method = "pricing.Pricing/OutOfStock" }:reply{ code = "NotFound", message = "unknown sku" }

grpc.client(m.url):call("pricing.Pricing/GetPrice", { sku = "A1" })
```

gRPC mocking is **stub-and-journal only** — there is no passthrough/record/replay on the gRPC facet yet.

## Reaching a mock from a container

A mock is the one resource that is a **host process a container must reach** — the inverse of every other resource. When your system under test runs in a container and calls the mock, opt into a network vantage:

```lua
local m = http.mock(t, { network = true })
-- m.url          — still loopback, how the TEST reaches it
-- m.network.url  — "http://host.docker.internal:<port>", how a CONTAINER reaches it
```

`network = true` binds `0.0.0.0` (a real LAN exposure, hence opt-in). It closes a "green on my laptop, red in CI" gap: Docker Desktop happens to route `host.docker.internal` to a loopback bind, but Linux does not. See the [reference](../reference/modules/http.md#reaching-a-mock-from-a-container-the-network-vantage) for the full story and `docker.run`'s `extra_hosts`.

## Handler errors fail loudly

By default a `:reply` handler that **raises** answers `500`, journals the error, and **fails the owning scope at teardown**. That is deliberate: a SUT with a fallback would swallow the 500 and the suite would go green over a bug in *your mock*. When the error path is the subject of the test, opt out with `allow_handler_errors = true` — see the [reference](../reference/modules/http.md#raising-handlers-fail-the-scope).

## Next

- [`http.mock`](../reference/modules/http.md#the-mock-facet-httpmock) and [`grpc.mock`](../reference/modules/grpc.md#the-mock-facet-grpcmock) — the full API.
- [Testing Real Systems](./testing-real-systems.md) — when to run the real dependency instead.
- [Topologies](./topologies.md) — holding a whole environment across runs.
