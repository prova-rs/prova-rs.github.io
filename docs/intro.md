---
sidebar_position: 1
---

# Introduction

**Prova** is a programmable, language-agnostic acceptance-test runner: a real scripting language (Lua) plus a real fixture model, shipped as a single static binary. It brings a system into existence — render it, build it, boot it — then pokes it from the outside with shell, filesystem, and HTTP assertions, with fixtures holding setup and teardown together.

Prova is deliberately *not* a unit-test framework — JUnit, pytest, and Go's `testing` own that layer inside their languages — and it is not a single-protocol tool like Hurl. It occupies the **black-box acceptance and integration layer**: the tests that exercise your system through its real surfaces (files, processes, exit codes, HTTP/gRPC), regardless of what language the system is written in.

Here is a complete, runnable test file. `prova` and the `fs`/`shell`/`http` modules are injected globals — no `require` needed:

```lua
-- workspace_test.lua

-- Built once for this file, shared by every test below. The temp dir is
-- removed automatically when the file's tests finish.
local workspace = prova.fixture("workspace", Scope.File, function(ctx)
  local dir = ctx:tempdir()
  shell.run("mkdir -p src && printf 'fn main() {}\\n' > src/main.rs", { cwd = dir, check = true })
  return dir
end)

prova.test("the workspace has the source file", function(t)
  local dir = t:use(workspace)
  t:expect(dir .. "/src/main.rs"):exists()
  t:expect(fs.read(dir .. "/src/main.rs")):contains("fn main")
end)

prova.test("shell commands report exit code and output", function(t)
  local dir = t:use(workspace)
  local r = shell.run("cat src/main.rs", { cwd = dir })
  t:expect(r.code):equals(0)
  t:expect(r.stdout):contains("fn main")
end)
```

Run it with `prova workspace_test.lua`. That is the whole loop: a fixture that provisions state, tests that request it with `t:use`, and fluent `t:expect` assertions — with teardown guaranteed.

## Why Prova exists

The existing language-agnostic testers are either **single-domain** (Hurl → HTTP, Bats → shell) or **declarative YAML/Gherkin walls** (Venom, Robot Framework, goss). The moment a test needs a loop, a computed value, a conditional, or reusable scoped setup, YAML hits a wall — and none of them have a fixture model. That is the wedge: a **real programming language** *and* **pytest-grade fixtures** (scoped setup/teardown, dependency injection, caching) in one binary with no runtime to install.

## Highlights

- **Real Lua, real tooling** — tests are plain Lua 5.4 with full editor support (completion, hover docs, and type-checking via the Lua Language Server), not a bespoke DSL or a YAML schema.
- **Pytest-grade fixtures** — named factories with `Test`/`Flow`/`File`/`Suite` scopes, lazy construction, per-scope caching, fixture-to-fixture dependencies, and guaranteed LIFO teardown.
- **Execution strategy you can read** — independent tests and groups parallelize; ordered `flow`s share state and cascade-skip on failure. The container declares the strategy, so `--jobs` is pure throughput and never changes what tests mean.
- **Dependency-aware scheduling** — `depends_on` edges skip (never fail) dependents when an upstream fails; declared resources let the scheduler parallelize safely around shared ports, databases, and files.
- **Graceful degradation** — `requires = { "docker" }` skips a test with a reason where a capability is missing, instead of turning CI red.
- **Batteries for real systems** — first-party modules for `fs`, `shell`, `http`, `grpc`, `graphql`, `docker`, `postgres`/`mysql`/`sqlite`, `redis`, Kafka/Pulsar messaging, `s3`, and `yaml`, plus the `archetect` plugin for in-process archetype rendering.
- **One static binary** — written in Rust; nothing to install on the target beyond `prova` itself.

## Where to go next

| Section | What you'll find |
|---|---|
| [Getting Started](./getting-started/index.md) | What Prova is, how to install it, core concepts, and your first test suite |
| [Writing Tests](./writing-tests/index.md) | Tests, fixtures, assertions, flows, scheduling, and testing real systems |
| [Running Prova](./running-prova/index.md) | The command line, the `prova.toml` manifest, profiles, and CI |
| [Reference](./reference/index.md) | Exhaustive reference for the CLI, the Lua API, and every module |
