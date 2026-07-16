---
sidebar_position: 7
---

# sqlite

The one built-in database: **embedded SQLite**, no container, no daemon, nothing to provision — a file (or memory) is the database. It is the zero-infrastructure option for tests that need real SQL without Docker. Server databases (Postgres, MySQL) are [external plugins](../../plugins/official-plugins.md).

There is no `sqlite.container` — there is nothing to provision.

## `sqlite.client`

```lua
sqlite.client(url) --> Connection
```

| URL | Meaning |
|---|---|
| `sqlite://<path>?mode=rwc` | A file-backed database; `mode=rwc` creates it if absent |
| `sqlite::memory:` | An in-memory database that vanishes with the handle |

**Returns:** a `Connection` (a small pool). Async — call inside a fixture factory or test body. Raises if the database cannot be opened.

The namespace **validates its URL scheme** before connecting: passing a non-`sqlite:` URL raises immediately with `sqlite.client: expected a sqlite:// URL, got ...`.

```lua
local conn = sqlite.client("sqlite://" .. ctx:tempdir() .. "/app.db?mode=rwc")
ctx:manage(conn)   -- closed during teardown

local mem = sqlite.client("sqlite::memory:")   -- in-memory
```

## `Connection`

All methods are async. Bind parameters may be integers, numbers, booleans, strings, or `nil`; SQLite's placeholder syntax is `?`.

### `conn:execute(sql, params)`

```lua
conn:execute(sql, params?) --> integer
```

Runs a statement (INSERT/UPDATE/DELETE/DDL).

**Returns:** the number of rows affected. Raises on SQL error.

```lua
c:execute("CREATE TABLE IF NOT EXISTS orders (id INTEGER PRIMARY KEY, sku TEXT, qty INT)")
t:expect(c:execute("INSERT INTO orders (id, sku, qty) VALUES (?, ?, ?)",
         { 1, "widget", 3 })):equals(1)
```

### `conn:query(sql, params)`

```lua
conn:query(sql, params?) --> table[]
```

Runs a query.

**Returns:** a list of rows, each a table of column name → value. SQL `NULL` becomes `nil`; numeric, boolean, text, and blob columns map to the corresponding Lua values. A computed column with no declared type (e.g. `count(*)`) is probed integer-first, so counts stay integral.

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
t:expect(c:query_value("SELECT sku FROM orders WHERE id = ?", { 99 })):is_nil()
```

### `conn:close()`

```lua
conn:close()
```

Closes the connection pool. Async. Handing the connection to `ctx:manage(conn)` calls this during teardown.
