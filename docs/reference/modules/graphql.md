---
sidebar_position: 5
---

# graphql

A thin GraphQL client: `POST { query, variables }` to one endpoint, get `{ data, errors }` back. Queries and mutations share the transport. The two methods mirror the [grpc module's](grpc.md) `call`/`call_status` split: `:query` is the happy path that raises on GraphQL errors, `:execute` returns the full envelope so a test can assert on the errors themselves.

## `graphql.client(opts)`

```lua
graphql.client(opts) --> GraphqlClient
```

Builds a client bound to one GraphQL endpoint.

| Option | Type | Description |
|---|---|---|
| `url` | `string` | Required. The endpoint URL |
| `headers` | `table<string,string>?` | Headers sent with every request (e.g. auth) |
| `timeout` | `string?` | Per-request deadline, e.g. `"10s"` |

Requests are sent as `POST` with `content-type: application/json`.

```lua
local api = graphql.client{
  url = "http://" .. c:endpoint(8080) .. "/graphql",
  headers = { authorization = "Bearer test-token" },
}
```

## `client:query(query, variables)`

```lua
client:query(query, variables?) --> any
```

Runs a query or mutation and returns its `data`. **Raises** if the response carries a non-empty `errors` array (the error message includes each GraphQL error's message).

| Parameter | Type | Description |
|---|---|---|
| `query` | `string` | The GraphQL document |
| `variables` | `table?` | Variable values, JSON-encoded into the request |

```lua
local data = api:query([[
  query Order($id: ID!) { order(id: $id) { sku qty } }
]], { id = "42" })
t:expect(data.order.sku):equals("widget")
t:expect(data.order.qty):equals(3)
```

## `client:execute(query, variables)`

```lua
client:execute(query, variables?) --> GraphqlResult
```

Like `query`, but **never raises** on GraphQL errors — it returns the full result envelope so the test can assert on them. (Transport failures — connection refused, non-JSON response — still raise.)

```lua
local res = api:execute("{ order(id: \"missing\") { sku } }")
t:expect(res.status):equals(200)
t:expect(res.errors):never():is_nil()
t:expect(res.errors[1].message):contains("not found")
t:expect(res.data):is_nil()
```

### `GraphqlResult`

| Member | Type | Description |
|---|---|---|
| `status` | `integer` | The HTTP status code |
| `data` | `any?` | The response `data` — `nil` when absent or JSON `null` |
| `errors` | `table[]?` | The response `errors` array — `nil` when absent or JSON `null` |
