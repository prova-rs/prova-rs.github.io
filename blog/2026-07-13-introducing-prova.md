---
slug: introducing-prova
title: Introducing Prova
authors: [jfulton]
tags: [announcements, prova]
---

Prova is a programmable, language-agnostic acceptance-test runner: a real
scripting language and pytest-grade fixtures, shipped as a single static
binary.

It lives in the layer most test tooling leaves uncovered — **black-box
acceptance testing**. Bring a system into existence — render it, build it,
boot it — then poke it from the outside with shell commands, HTTP and gRPC
calls, and filesystem assertions, with fixtures holding setup and teardown
together.

{/* truncate */}

## Why another test runner?

Unit-test frameworks like JUnit and pytest are excellent *inside* their
languages, but the moment your subject is "a service, in a container, talking
to a real database," you've left their sweet spot. The language-agnostic tools
that remain are either single-domain (Hurl owns HTTP; Bats owns shell) or
declarative YAML/Gherkin runners — and the moment a test needs a loop, a
computed value, or reusable scoped setup, YAML hits a wall.

Prova's wedge is combining two things that haven't shipped together before:

- **A real programming language.** Tests are Lua — loops, conditionals,
  helper functions, computed values, all with full IDE autocomplete and
  type-checking via bundled annotations.
- **A real fixture model.** Scoped setup/teardown (test, flow, file, suite),
  dependency injection, caching, and guaranteed LIFO cleanup — the pytest
  fixture experience, outside any single language ecosystem.

All of it in one static Rust binary. No interpreter to install, no
virtualenv, no `node_modules` — the same executable on your laptop and in CI.

## What it looks like

```lua
local workspace = prova.fixture("workspace", Scope.File, function(ctx)
  return ctx:tempdir()
end)

prova.test("greets the world", function(t)
  local dir = t:use(workspace)
  local r = shell.run("echo hello > greeting.txt && cat greeting.txt", { cwd = dir.path })

  t:expect(r.code):equals(0)
  t:expect(r.stdout):contains("hello")
  t:expect(dir:file("greeting.txt")):exists()
end)
```

Run it with `prova path/to/tests`, and every test in the file runs isolated
and in parallel — sharing the `workspace` fixture, which is built once and
torn down automatically.

Beyond `shell` and `fs`, Prova ships first-party modules for `http`, `grpc`,
`graphql`, `docker`, `postgres`/`mysql`/`sqlite`, `redis`, `kafka`, `pulsar`, and
`s3` — enough batteries to boot a real system and prove it works. And as a
sibling of [Archetect](https://archetect.github.io), Prova renders archetypes
in-process, so you can test that your generated projects don't just render —
they build, boot, and serve.

## Where to start

- [Introduction](/docs/intro) — what Prova is and the thinking behind it
- [Quick Start](/docs/getting-started/quick-start) — write and run your first
  test in minutes
- [Testing Real Systems](/docs/writing-tests/testing-real-systems) — the full
  render → build → boot → probe workflow

Prova is young and moving fast — the [roadmap](/docs/reference/roadmap) shows
what's landing next. Feedback and issues are welcome on
[GitHub](https://github.com/prova-rs/prova).
