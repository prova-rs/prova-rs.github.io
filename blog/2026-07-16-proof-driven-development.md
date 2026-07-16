---
slug: proof-driven-development
title: "Prova 0.2: Proof-Driven Development"
authors: [jfulton]
tags: [announcements, prova]
---

Prova 0.2 is out, and it ships with a bigger idea than a release number:
**Proof-Driven Development**. The durable artifact of a codebase is an
executable, black-box definition of what the system must do — humans define
the proof, implementers (increasingly agents) drive it green, and CI holds
the bar after every context is gone. Prova — Italian for *proof* — is the
reference implementation.

{/* truncate */}

## The paradigm, with receipts

A quick disambiguation first: this is not theorem proving or formal
verification. PDD is executable *behavioral* proof — render the system,
build it, boot it, probe it from the outside, cross-check what it does.

Here is what that looks like in practice. Nine service archetypes across
three languages (C#, TypeScript, Python) and three transports (REST, gRPC,
GraphQL) are held to a persisted-CRUD bar by prova suites in CI. The bar is
the same for every variant: render the archetype, build it, boot it with a
real database, and prove that create/read/update/delete actually persists.

The suites earned their keep immediately. Variants that had never been
tested were hiding latent defects — renders that never compiled, database
pools closed at boot, health endpoints reporting UNKNOWN. None of those are
findable from inside a unit test; all of them fall out of booting the real
thing and poking it.

And the loop is fast enough for autonomous work: agents implemented to the
bar with roughly 30–60 second feedback cycles. That is the shift worth
naming. When the implementer is an agent, "done" cannot be a claim — it has
to be a proof that runs. Work merges only when it arrives **carrying its
proof** (an homage to proof-carrying code): the suite is the proof, and CI
holds it. A repo's suite is its **proving ground** — it outlives every
conversation, every branch, and every context window that produced the code.

## The plugin system

0.2's headline mechanism is the plugin system, and it has an unusual
property: **plugins are pure Lua, with zero native code**.

The binary keeps a lean core — `fs`, `shell` (+`net`), `http`, `grpc`,
`graphql`, `yaml`, `docker`, `sqlite`, plus the bundled `archetect` plugin.
Everything containerized moved out: `postgres`, `mysql`, `redis`, `kafka`,
`pulsar`, `rabbitmq`, and `s3` are now official external plugins
(`prova-rs/prova-<name>`). You declare them in `prova.toml`:

```toml
[plugins]
postgres = "prova-rs/prova-postgres@v1"
```

and attach them in a test:

```lua
local pg = require("postgres")

local db = prova.fixture("db", Scope.Suite, function(ctx)
  return pg.container(ctx)   -- { client, url, container, host, port }
end)
```

Under the hood every one of them is authored through `prova.containerized`
— a scaffolding helper that turns a spec (image, port, readiness wait, URL
shape) into a grammar-conformant namespace, driving the technology's own CLI
over docker-exec. No compiled client libraries, no dynamic loading, no
binary bloat. The seam first-party plugins use is exactly the seam you get:
a plugin is a Lua module that returns a namespace table, pinned by ref in
your manifest, reviewable in your repo.

Read more in [Plugins](/docs/plugins/), starting with
[Using Plugins](/docs/plugins/using-plugins) and the
[official plugin list](/docs/plugins/official-plugins), or write your own
with [Authoring Plugins](/docs/plugins/authoring-plugins).

## Quiet primitives

0.2.2 also lands a batch of ergonomics that mostly matter when things go
wrong — which is exactly when they matter most:

- **`check = true` failures carry both streams.** A non-zero exit raises an
  error that includes the tail of stdout *and* stderr, so the failure you
  read in CI is the failure that happened.
- **`env` accepts scalars.** Ports stay numbers, flags stay booleans —
  `env = { PORT = 8080, VERBOSE = false }` — no stringly ceremony.
- **Spawned processes capture output.** `proc:output()` returns the
  combined stdout+stderr so far, so a boot that times out is never a blind
  boot: assert on it, or print it.
- **Container resources expose `host` and `port`.** Wiring an app to a
  provisioned database is `DbHost = res.host, DbPort = res.port` — no
  `host_port()` ceremony.

Small primitives, quiet on the happy path, loud where you need them.

## Get it

```bash
brew install prova-rs/tap/prova
```

or grab a release binary (v0.2.2) from
[GitHub releases](https://github.com/prova-rs/prova/releases), or build with
cargo.

## Where to start

- [Introduction](/docs/intro) — Proof-Driven Development and the thinking behind Prova
- [Quick Start](/docs/getting-started/quick-start) — write and run your first test in minutes
- [Plugins](/docs/plugins/) — using and authoring docker-exec plugins
- [Testing Real Systems](/docs/writing-tests/testing-real-systems) — the full render → build → boot → probe workflow

Feedback and issues are welcome on
[GitHub](https://github.com/prova-rs/prova).
