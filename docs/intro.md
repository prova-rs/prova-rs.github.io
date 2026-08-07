---
sidebar_position: 1
---

# Introduction

**Prova** — Italian for *proof* — is the reference implementation of **Proof-Driven Development (PDD)**: the practice where the durable artifact of a codebase is an executable, black-box definition of what the system must do. Humans define the proof; implementers — increasingly agents — drive it green; CI holds the bar after every context is gone. Work merges only when it arrives carrying its proof — the suite *is* the proof, and a repo's suite is its **proving ground**.

To be precise about the word: PDD is *not* theorem proving or formal verification. It is executable behavioral proof — render the system, build it, boot it, probe it from the outside, cross-check what it actually does.

Concretely, Prova is a programmable, language-agnostic acceptance-test runner: a real scripting language (Lua) plus a real fixture model, shipped as a single static binary. It brings a system into existence — render it, build it, boot it — then pokes it through its real surfaces (files, processes, exit codes, HTTP/gRPC/GraphQL), with fixtures holding setup and teardown together. It is deliberately *not* a unit-test framework — JUnit, pytest, and Go's `testing` own that layer inside their languages — and not a single-protocol tool like Hurl.

The runner is the ground floor. On top of it, Prova keeps a project's **evidence ledger**: a sentence in a design doc becomes a [claim](./evidence/claims-and-covers.md), a proof authored ahead of the implementation is a [promise](./writing-tests/promises-and-burndown.md), a kept promise graduates to `proves`, and the [run record attests](./evidence/record-and-attest.md) that the covering proof actually executed. **Claimed → bound → promised → proven → attested** — every stage of a change, from idea to evidence, is a state the tool can report (`prova evidence`) and the one open question is always answerable: `prova owed`. You can use Prova as nothing more than a very good test runner; the ledger is there the day a claim is worth anchoring.

Here is a complete, runnable test file. `prova` and the `fs`/`shell`/`http` modules are injected globals — no `require` needed:

```lua
-- workspace.prova.lua

-- Built once for this file, shared by every test below. The temp dir is
-- removed automatically when the file's tests finish.
local workspace = prova.fixture("workspace", Scope.File, function(ctx)
  local dir = ctx:tempdir()
  -- check = true: a non-zero exit raises, carrying both output streams.
  -- env values are plain scalars — ports stay numbers, flags stay booleans.
  shell.run("mkdir -p src && printf 'fn main() {}\\n' > src/main.rs",
    { cwd = dir, check = true, env = { BUILD_ID = 42, VERBOSE = false } })
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

Run it with `prova workspace.prova.lua`. That is the whole loop: a fixture that provisions state, tests that request it with `t:use`, and fluent `t:expect` assertions — with teardown guaranteed.

## Why Prova exists

Two arguments, one tool.

**The practice argument.** When the author in the loop is increasingly an agent, "done" cannot be a claim — it has to be a proof that runs. The unit frameworks assume the code already exists inside a language; agents increasingly conjure *whole systems* — scaffold a repo, render an archetype, build it, boot it — and must be held accountable at the outside boundary. That boundary is exactly where Prova lives. This is not hypothetical: nine service archetypes across three languages (C#, TypeScript, Python) and three transports (REST, gRPC, GraphQL) are held to a persisted-CRUD bar by prova suites in CI. The suites found latent defects the untested variants had hidden — renders that never compiled, database pools closed at boot, health endpoints reporting UNKNOWN — and agents implemented to the bar with roughly 30–60 second feedback loops.

**The tooling argument.** The existing language-agnostic testers are either **single-domain** (Hurl → HTTP, Bats → shell) or **declarative YAML/Gherkin walls** (Venom, Robot Framework, goss). The moment a test needs a loop, a computed value, a conditional, or reusable scoped setup, YAML hits a wall — and none of them have a fixture model. That is the wedge: a **real programming language** *and* **pytest-grade fixtures** (scoped setup/teardown, dependency injection, caching) in one binary with no runtime to install.

## Highlights

- **Real Lua, real tooling** — tests are plain Lua 5.4 with full editor support (completion, hover docs, and type-checking via the Lua Language Server), not a bespoke DSL or a YAML schema.
- **Pytest-grade fixtures** — named factories with `Test`/`Flow`/`File`/`Suite` scopes, lazy construction, per-scope caching, fixture-to-fixture dependencies, and guaranteed LIFO teardown.
- **Execution strategy you can read** — independent tests and groups parallelize; ordered `flow`s share state and cascade-skip on failure. The container declares the strategy, so `--jobs` is pure throughput and never changes what tests mean.
- **Dependency-aware scheduling** — `depends_on` edges skip (never fail) dependents when an upstream fails; declared resources let the scheduler parallelize safely around shared ports, databases, and files.
- **Graceful degradation** — `requires = { "docker" }` skips a test with a reason where a capability is missing, instead of turning CI red.
- **Topologies you can test *or* inhabit** — declare a named environment once with `prova.topology`; tests `use` it, and `prova up`/`watch`/`start` stand the identical environment up live to develop against, so tests and dev environment cannot drift.
- **Lean core, package ecosystem** — built-in modules for `fs`, `shell` (+`net`), `http`, `grpc`, `graphql`, `yaml`, `docker`, and `sqlite`, plus the bundled `archetect` package for in-process archetype rendering. Databases, caches, brokers, and object stores — `postgres`, `mysql`, `redis`, `kafka`, `pulsar`, `rabbitmq`, `s3` — are official [packages](./packages/index.md): pure Lua over docker-exec, declared in `prova.toml` `[dependencies]` and attached with `require("postgres")`.
- **One static binary** — written in Rust; nothing to install on the target beyond `prova` itself.

## Where to go next

| Section | What you'll find |
|---|---|
| [Getting Started](./getting-started/index.md) | What Prova is, how to install it, core concepts, and your first test suite |
| [Workflows](./workflows/index.md) | The ramp: complete ways of working, from "just write some tests" to docs that cannot drift |
| [Writing Tests](./writing-tests/index.md) | Tests, fixtures, assertions, flows, scheduling, and testing real systems |
| [Evidence & Obligations](./evidence/index.md) | The ledger: claims, covers, the run record, attestation, and falsifiers |
| [Running Prova](./running-prova/index.md) | The command line, the `prova.toml` manifest, profiles, and CI |
| [Packages](./packages/index.md) | Using official packages, authoring your own, and the docker-exec architecture |
| [Patterns](./patterns/index.md) | Production-tested shapes: shared standards packages, published topologies, org catalogs |
| [Reference](./reference/index.md) | Exhaustive reference for the CLI, the Lua API, and every module |
