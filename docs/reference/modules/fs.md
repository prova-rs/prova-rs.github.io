---
sidebar_position: 1
---

# fs

Synchronous filesystem helpers: read and write files, create temp dirs, glob a tree. All paths are plain strings; there is no ambient working directory — pass absolute paths (typically built from a fixture's temp dir).

## Functions

### `fs.tempdir()`

```lua
fs.tempdir() --> string
```

Creates a fresh temporary directory and returns its absolute path.

**Returns:** the directory path. Raises on failure.

:::note
`fs.tempdir()` is **not** auto-cleaned. Either remove it yourself with `ctx:defer`, or prefer [`ctx:tempdir()`](../lua-api/context.md), which is removed automatically at the end of its scope.
:::

```lua
local dir = fs.tempdir()
ctx:defer(function() fs.remove_all(dir) end)
```

### `fs.read(path)`

```lua
fs.read(path) --> string
```

| Parameter | Type | Description |
|---|---|---|
| `path` | `string` | File to read |

**Returns:** the file contents as a string. Raises if the file does not exist or is not valid UTF-8.

```lua
t:expect(fs.read(dir .. "/src/main.rs")):contains("fn main")
```

### `fs.write(path, contents)`

```lua
fs.write(path, contents)
```

Writes `contents` to `path`, **creating parent directories as needed**.

| Parameter | Type | Description |
|---|---|---|
| `path` | `string` | Destination file |
| `contents` | `string` | Bytes to write |

**Returns:** nothing. Raises on I/O failure.

```lua
fs.write(root .. "/config/app.toml", "[server]\nport = 8080\n")
```

### `fs.exists(path)`

```lua
fs.exists(path) --> boolean
```

**Returns:** `true` if a file or directory exists at `path`.

### `fs.remove_all(path)`

```lua
fs.remove_all(path)
```

Removes a file, or a directory and everything under it. Removing something that is already gone is a **no-op**, not an error.

### `fs.glob(root, pattern)`

```lua
fs.glob(root, pattern) --> string[]
```

| Parameter | Type | Description |
|---|---|---|
| `root` | `string` | Directory to search under |
| `pattern` | `string` | Glob pattern relative to `root`, e.g. `"**/*.rs"` |

**Returns:** a **sorted** list of matching paths (as strings).

```lua
local hits = fs.glob(dir, "**/*.rs")
t:expect(#hits):equals(1)
t:expect(hits[1]):contains("main.rs")
```

## Path handles: Tree, FileHandle, DirHandle

Some modules — notably [`archetect.render`](archetect.md) — return **path handles** instead of bare strings: plain Lua tables rooted at a path, with navigation methods. A tree handle, a file handle, and a directory handle all share the same shape:

| Member | Type | Description |
|---|---|---|
| `path` | `string` | The absolute path this handle points at |
| `handle:file(rel)` | `→ FileHandle` | A handle for the file at `rel`, relative to this handle |
| `handle:dir(rel)` | `→ DirHandle` | A handle for the directory at `rel`, relative to this handle |
| `handle:read()` | `→ string` | Read the contents at `path` (raises if unreadable) |

Navigation composes: `tree:dir("src"):file("main.rs")` is a handle for `<root>/src/main.rs`.

### Handles and filesystem matchers

The `path` field is what prova's [filesystem matchers](../lua-api/matchers.md) read, so a handle can be passed straight to `t:expect(...)` — the matchers `:exists()`, `:is_file()`, `:is_dir()`, and `:is_fully_rendered()` accept either a path string or any table with a `path` field:

```lua
local out = t:use(rendered)              -- a Tree from archetect.render
t:expect(out:file("Cargo.toml")):exists()
t:expect(out:dir("src")):is_dir()
t:expect(out):is_fully_rendered()        -- no leftover template markers anywhere under out.path
```
