---
sidebar_position: 1
---

# What is Prova?

Prova is a **black-box acceptance-test runner**. It tests systems from the *outside* — through files, processes, exit codes, HTTP, gRPC, databases, and message brokers — regardless of what language those systems are written in. You describe how to bring the system into existence (a fixture), then assert on what it actually does (a test).

That layer — above unit tests, below load tests, across every protocol — is real, and it is badly served. Every team ends up gluing it together from shell scripts, `Makefile` targets, and one-off harnesses. Prova makes it a first-class discipline.

## The landscape, honestly

Each of the existing tools nails one thing and stops:

| Tool | What it nails | Where it stops |
|---|---|---|
| **pytest / JUnit / Go `testing`** | Unit testing *inside* their language — fixtures, mocks, introspection | Bound to one language; awkward as a harness for a system written in anything else |
| **Hurl** | HTTP request/assert files, terse and fast | HTTP only — no shell, no filesystem, no provisioning |
| **Bats** | Shell-native TAP tests | Shell only, and no fixture model — setup/teardown is manual and unscoped |
| **Venom / Robot Framework / goss** | Language-agnostic, declarative, CI-friendly | YAML/keyword walls: the moment you need a loop, a computed value, or a conditional, you are fighting the format |

Two failure modes repeat across the language-agnostic column: the tool is **single-domain**, or it is **declarative** — and none of them has a **fixture model**. Scoped setup/teardown with dependency injection and caching is the thing pytest users cannot live without, and it is structurally impossible to express in a YAML schema.

## The differentiator

Prova's wedge is that it refuses the trade-off: a **real programming language** *and* **pytest-grade fixtures**, in one static binary with no runtime to install.

- **Real language.** Tests are plain Lua 5.4. Loops, conditionals, computed values, helper functions, and reusable modules all just work — with completion, hover docs, and type-checking in your editor via the Lua Language Server.
- **Real fixtures.** `prova.fixture` gives you named factories with four scopes (`Test`, `Flow`, `File`, `Suite`), lazy construction, per-scope caching, fixture-to-fixture dependencies, and guaranteed LIFO teardown — even when a test fails.
- **Real scheduling.** Independent tests parallelize; ordered flows stay serial; `depends_on` edges skip dependents when an upstream fails; declared resources keep parallel tests from colliding over shared ports and databases.

## What Prova deliberately is not

Being good at the acceptance layer means being honest about the boundary:

- **In-language unit testing** stays with pytest, JUnit, Go, and friends. Prova cannot mock a Java private method from Lua, and does not pretend to. The line: if the assertion needs to reach inside a process's memory, it is out of scope; if it observes the system from outside, it is Prova's.
- **Load and performance testing** stays with k6 and Gatling. Prova asserts on the correctness of behavior, not on throughput distributions.

## Relationship to Archetect

Prova is a sibling project to [Archetect](https://archetect.github.io), the code generator — they share the same Lua runtime and the same philosophy: real scripting with first-class editor tooling, shipped as a single native binary.

The core runner is fully **domain-agnostic**; archetype rendering is a first-party *plugin*. The standalone `prova` binary ships with `archetect.render{...}`, which renders an archetype in-process (no subprocess) so you can generate a project, assert on its layout, and build it — all inside one test. Testing archetypes is both the justifying use case that shaped Prova and its ongoing dogfooding target, but it sits behind the same plugin boundary any other module would.

## Where to next

Continue to [Installation](./installation.md), or get the mental model first in [Core Concepts](./core-concepts.md). For where the project is headed, see the [Roadmap](../reference/roadmap.md).
