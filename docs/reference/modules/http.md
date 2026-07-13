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
