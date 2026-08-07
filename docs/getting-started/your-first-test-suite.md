---
sidebar_position: 5
---

# Your First Test Suite

The [Quick Start](./quick-start.md) ran two self-contained tests from a bare file. Real acceptance tests live in a project and share expensive setup — a rendered project, a built binary, a booted service. This page grows the quick start into that shape: scaffold a project with `prova init`, provision a workspace with one **file-scoped fixture**, assert against it from several tests, and parallelize the run safely.

## 1. Scaffold the project

From your repository root:

```shell
prova init
```

`init` renders the `project` archetype from the catalog, which lays out:

```text
.prova/prova.toml     the manifest, tucked in the .prova/ nook — discovery walks up to it
.prova/config.lua     the runtime companion, where runtime.capability registrations live
.prova/packages/lib/  the project's shared library package — require("lib") from any proof
proofs/               the starter suite
.github/workflows/    CI that installs prova and runs this same suite
.luarc.json           editor completion — points workspace.library at the core annotations
```

The scaffolded manifest wires those pieces together:

```toml
[run]
proofs   = ["proofs"]           # your proof suites live in the open, at the project root
config   = ".prova/config.lua"  # the runtime companion
packages = ".prova/packages"    # the project's own packages

[profiles.ci]
must_run = []                   # what CI guarantees — e.g. ["docker"]

[requires]
prova = ">= 0.16"
```

One command does three things:

- **`.prova/`** — the [manifest](../running-prova/manifest-and-profiles.md) and its companions live in the `.prova/` nook, so prova's own files tuck away while your proofs stay visible at the project root. Discovery walks up to the nook, so a plain `prova` from anywhere in the project runs the suite; the starter proofs in `proofs/` show the shape (a fixture shared through the `lib` package, and a capability-gated `requires = { "soak" }` proof whose capability `.prova/config.lua` registers). (The layout — where the manifest lands, what the proof dir is called — is the archetype's choice; author your own [init catalog entry](../running-prova/scaffolding.md) to change it.)
- **`.luarc.json`** — [IDE integration](../running-prova/ide-setup.md): it points `workspace.library` at the core annotations under `~/.local/share/prova/lua/annotations`, so an editor with lua-language-server completes and type-checks the whole `prova` API immediately; package annotations are linked automatically as you declare them and run `prova`.
- It **never clobbers** — `init` refuses to run if a manifest already exists.

## 2. Add a shared fixture

Delete the starter proofs — they exist to show the shape, and this file replaces them — and create `proofs/workspace.prova.lua`:

```lua
-- workspace.prova.lua

-- A scratch project, built ONCE for this file and shared by every test below.
-- ctx:tempdir() is removed automatically when the file's tests finish.
local workspace = prova.fixture("workspace", Scope.File, function(ctx)
  local dir = ctx:tempdir()
  shell.run("mkdir -p src && printf 'fn main() {}\\n' > src/main.rs", { cwd = dir, check = true })
  fs.write(dir .. "/Cargo.toml", '[package]\nname = "widget"\nversion = "0.1.0"\n')
  fs.write(dir .. "/README.md", "# widget\n\nA demo CLI.\n")
  return dir
end)

prova.test("produces the expected layout", function(t)
  local dir = t:use(workspace)
  -- Soft assertions: report every missing file, not just the first.
  t:expect_all(function()
    t:expect(dir .. "/Cargo.toml"):exists()
    t:expect(dir .. "/src/main.rs"):exists()
    t:expect(dir .. "/README.md"):exists()
    t:expect(dir .. "/src"):is_dir()
  end)
end)

prova.test("wires the crate name through", function(t)
  local cargo = fs.read(t:use(workspace) .. "/Cargo.toml")
  -- The label makes the failure read "Cargo.toml [package] name: expected ..."
  t:expect(cargo, "Cargo.toml [package] name"):contains('name = "widget"')
end)

prova.test("the entry point is a real Rust file", function(t)
  local dir = t:use(workspace)
  local r = shell.run("cat src/main.rs", { cwd = dir })
  t:expect(r.code):equals(0)
  t:expect(r.stdout):contains("fn main")
end)
```

What changed from the quick start:

- **`prova.fixture(name, scope, factory)`** declares the fixture. `Scope.File` means: build it once for this file, share it across the file's tests, tear it down after the last one. The factory receives a context `ctx` with `ctx:tempdir()` (scope-cleaned scratch space), `ctx:defer(fn)` (custom teardown), and `ctx:use(...)` (fixture-to-fixture dependencies).
- **`prova.fixture` returns a handle**, and tests request the value with `t:use(workspace)`. The handle (rather than a string) is deliberate: your editor knows the fixture's value type, so completion and type-checking flow through to the call site.
- **`t:expect_all(body)`** collects every failed assertion inside `body` before failing the test — a layout check reports *all* the missing files, not just the first.

## 3. Run it in parallel

The manifest makes the whole suite one word; `--jobs` raises the concurrency:

```shell
prova --jobs 4
```

```text
  PASS  produces the expected layout  (12.4ms, 4 assert)
  PASS  wires the crate name through  (1.8ms, 1 assert)
  PASS  the entry point is a real Rust file  (6.9ms, 2 assert)

3 passed, 0 failed, 0 skipped   in 15.7ms
```

`--jobs N` lets up to N units run concurrently — across files (each ungrouped file is its own isolated suite on its own worker) and, within a file, by overlapping I/O-bound tests cooperatively.

(You can always bypass the manifest and point at one file directly — `prova proofs/workspace.prova.lua` — the two modes are covered in [The Command Line](../running-prova/command-line.md).)

## 4. Why this is safe

Two properties make `--jobs` a pure throughput knob:

- **Isolation by construction.** Top-level tests are independent by definition: the API exposes no shared mutable globals, no implicit working directory, no ambient state to leak between them. When tests genuinely need ordering and shared state, you declare it with a [flow](../writing-tests/flows.md) — and that shows in the code.
- **Fixture caching respects scope.** The `workspace` fixture is built exactly once no matter how many tests `use` it or in what order they run — first `use` builds it, everyone else gets the cached value, and teardown runs once after the file's last test. A `Scope.Test` fixture, by contrast, is rebuilt fresh for every test.

So the three tests above may run in any order, or concurrently, and the result is identical.

:::tip
Lazy construction matters: a fixture no test `use`s is never built. You can keep expensive fixtures (a rendered project, a database container) declared in the file and pay for them only when a selected test actually needs them.
:::

## Where to go from here

- Give fixtures dependencies, teardown, and broader scopes in [Fixtures](../writing-tests/fixtures.md).
- Share one fixture across *multiple files* with a `suite.lua` — see [Suites and Shared State](../writing-tests/suites-and-shared-state.md).
- Point Prova at real systems — containers, databases, HTTP services — in [Testing Real Systems](../writing-tests/testing-real-systems.md), and declare the infrastructure they need as [packages](/docs/packages/) in the manifest `init` just wrote.
- Wire the suite into CI with the manifest in [Manifest and Profiles](../running-prova/manifest-and-profiles.md).
