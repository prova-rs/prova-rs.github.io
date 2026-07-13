---
sidebar_position: 7
sidebar_label: "Postgres, MySQL & SQLite"
---

# Postgres, MySQL & SQLite

Three namespaces — `postgres`, `mysql`, `sqlite` — fronting **one general SQL API**. Each `X.client(url)` returns the same generic `Connection` type, so the query surface is identical across all three — the only per-backend difference in a test is the URL and the placeholder syntax (`$1` for Postgres, `?` for MySQL/SQLite). The namespace exists for discoverability and URL-scheme validation, not for a per-engine API. No TLS in v1 (local/CI containers).

The `postgres.container` and `mysql.container` **recipes** fold the whole provision-an-ephemeral-database dance into one call. SQLite has no container recipe — there is nothing to provision.

## `postgres.client` / `mysql.client` / `sqlite.client`

```lua
postgres.client(url) --> Connection
mysql.client(url)    --> Connection
sqlite.client(url)   --> Connection
```

| Namespace | URL | 
|---|---|
| `postgres` | `postgres://user:pass@host:port/db` (or `postgresql://`) |
| `mysql` | `mysql://user:pass@host:port/db` |
| `sqlite` | `sqlite://<path>?mode=rwc`, or `sqlite::memory:` for an in-memory database |

**Returns:** a `Connection` (a small pool). Async — call inside a fixture factory or test body. Raises if the database is unreachable.

Each namespace **validates its URL scheme** before connecting: `postgres.client("mysql://...")` raises immediately with `postgres.client: expected a postgres:// URL, got ...` — pass the URL to the namespace that matches it.

```lua
local conn = sqlite.client("sqlite://" .. ctx:tempdir() .. "/app.db?mode=rwc")
ctx:manage(conn)   -- closed during teardown

local mem = sqlite.client("sqlite::memory:")   -- in-memory, vanishes with the handle
```

## `Connection`

All methods are async. Bind parameters may be integers, numbers, booleans, strings, or `nil`; use the backend's own placeholder syntax in the SQL.

### `conn:execute(sql, params)`

```lua
conn:execute(sql, params?) --> integer
```

Runs a statement (INSERT/UPDATE/DELETE/DDL).

**Returns:** the number of rows affected. Raises on SQL error.

```lua
c:execute("CREATE TABLE IF NOT EXISTS orders (id BIGINT PRIMARY KEY, sku TEXT, qty INT)")
t:expect(c:execute("INSERT INTO orders (id, sku, qty) VALUES ($1, $2, $3)",
         { 1, "widget", 3 })):equals(1)
```

### `conn:query(sql, params)`

```lua
conn:query(sql, params?) --> table[]
```

Runs a query.

**Returns:** a list of rows, each a table of column name → value. SQL `NULL` becomes `nil`; numeric, boolean, text, and blob columns map to the corresponding Lua values.

```lua
local rows = c:query("SELECT id, sku, qty FROM orders ORDER BY id")
t:expect(#rows):equals(2)
t:expect(rows[1].sku):equals("widget")
t:expect(rows[1].qty):equals(3)
```

### `conn:query_value(sql, params)`

```lua
conn:query_value(sql, params?) --> any
```

**Returns:** a single scalar — the first column of the first row — or `nil` if the query returns no rows.

```lua
t:expect(c:query_value("SELECT count(*) FROM orders")):equals(2)
t:expect(c:query_value("SELECT sku FROM orders WHERE id = $1", { 99 })):is_nil()
```

### `conn:close()`

```lua
conn:close()
```

Closes the connection pool. Async. Handing the connection to `ctx:manage(conn)` calls this during teardown.

## Recipes: `postgres.container` / `mysql.container`

```lua
postgres.container(ctx, opts?) --> SqlResource
mysql.container(ctx, opts?)    --> SqlResource
```

Provision an ephemeral database in a container, wait until it **actually accepts connections** (the port opening is a false positive for a first-boot database — the recipe retries the real connection), open a managed client, and tie everything to the scope. One call replaces the `docker.run` + retry + `postgres.client` + `ctx:manage` dance.

Both require the [`docker`](docker.md) module at call time — gate the tests with `requires = { "docker" }` so they skip where the daemon is absent.

| Option | Type | Description |
|---|---|---|
| `user` | `string?` | Default `"prova"` |
| `password` | `string?` | Default `"prova"` |
| `database` | `string?` | Default `"prova"` |
| `image` | `string?` | Full image ref; overrides `tag` |
| `tag` | `string?` | Image tag — Postgres default `"16-alpine"` (image `postgres`), MySQL default `"8"` (image `mysql`) |
| `root_password` | `string?` | MySQL only; default `"root"` |
| `timeout` | `string?` | Readiness deadline — default `"60s"` (Postgres) / `"90s"` (MySQL) |

**Returns:** a `SqlResource` — the standard resource shape:

| Member | Type | Description |
|---|---|---|
| `client` | `Connection` | An open, managed client — exactly what `postgres.client(url)` / `mysql.client(url)` returns |
| `url` | `string` | The connection URL that reaches the instance |
| `container` | `Container` | The managed [container handle](docker.md#container) |

```lua
local pg = prova.fixture("pg", Scope.File, function(ctx)
  return postgres.container(ctx, { database = "orders" }).client
end)

prova.group("postgres", { requires = { "docker" } }, function(g)
  g:test("round-trips rows", function(t)
    local c = t:use(pg)
    c:execute("CREATE TABLE orders (id BIGINT PRIMARY KEY, sku TEXT)")
    c:execute("INSERT INTO orders (id, sku) VALUES ($1, $2)", { 1, "widget" })
    t:expect(c:query_value("SELECT sku FROM orders WHERE id = $1", { 1 })):equals("widget")
  end)
end)
```
