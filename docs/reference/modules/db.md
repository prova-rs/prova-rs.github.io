---
sidebar_position: 7
---

# db

One general SQL API over **Postgres, MySQL, and SQLite**. The backend is chosen by the connection URL's scheme, so the query surface is identical across all three — the only per-backend difference in a test is the URL and the placeholder syntax (`$1` for Postgres, `?` for MySQL/SQLite). No TLS in v1 (local/CI containers).

The `db.postgres` and `db.mysql` **recipes** fold the whole provision-an-ephemeral-database dance into one call.

## `db.connect(url)`

```lua
db.connect(url) --> Connection
```

| Parameter | Type | Description |
|---|---|---|
| `url` | `string` | `postgres://user:pass@host:port/db`, `mysql://user:pass@host:port/db`, or `sqlite://<path>?mode=rwc` |

**Returns:** a `Connection` (a small pool). Async — call inside a fixture factory or test body. Raises if the database is unreachable.

```lua
local conn = db.connect("sqlite://" .. ctx:tempdir() .. "/app.db?mode=rwc")
ctx:manage(conn)   -- closed during teardown
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

## Recipes: `db.postgres` / `db.mysql`

```lua
db.postgres(ctx, opts?) --> DbResource
db.mysql(ctx, opts?)    --> DbResource
```

Provision an ephemeral database in a container, wait until it **actually accepts connections** (the port opening is a false positive for a first-boot database — the recipe retries the real connection), open a managed connection, and tie everything to the scope. One call replaces the `docker.run` + retry + `db.connect` + `ctx:manage` dance.

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

**Returns:** a `DbResource`:

| Member | Type | Description |
|---|---|---|
| `url` | `string` | The connection URL |
| `conn` | `Connection` | An open, managed connection |
| `container` | `Container` | The managed [container handle](docker.md#container) |

```lua
local pg = prova.fixture("pg", Scope.File, function(ctx)
  return db.postgres(ctx, { database = "orders" }).conn
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
