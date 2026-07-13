---
sidebar_position: 3
sidebar_label: "Writing Tests"
---

# Writing Tests

This section teaches you the full authoring surface of Prova: declaring tests, building setup and teardown with fixtures, asserting with the fluent matcher API, ordering work with flows and dependencies, sharing live state across files with suites — and finally putting it all together to test a real system end to end. Everything here is plain Lua with first-class editor support, and every construct is designed around one principle: the safe thing is the quiet default, and the dangerous thing (ordering, shared state) is always visible in the code.

## Learning path

1. **[Tests & Grouping](./tests-and-grouping.md)** — declare tests, drive them from data tables, and organize them with `describe` and explicit groups.
2. **[Fixtures](./fixtures.md)** — the heart of Prova: scoped, cached, dependency-injected setup and teardown.
3. **[Assertions](./assertions.md)** — the `t:expect(...)` fluent matcher API, negation, soft assertions, and runtime skips.
4. **[Flows](./flows.md)** — ordered steps that share state, with cascade-skip on failure.
5. **[Dependencies & Scheduling](./dependencies-and-scheduling.md)** — the `depends_on` DAG, resource declarations, and capability gating.
6. **[Suites & Shared State](./suites-and-shared-state.md)** — one Lua state across many files, so expensive infrastructure is provisioned once.
7. **[Testing Real Systems](./testing-real-systems.md)** — the capstone: render a service, build it, provision Postgres, boot it, and drive its gRPC API while cross-checking the database.

## Prerequisites

You should have Prova [installed](../getting-started/installation.md) and have run through [Your First Test Suite](../getting-started/your-first-test-suite.md). When you need the exhaustive API surface rather than a guided tour, the [Lua API reference](../reference/lua-api/index.md) and the [module reference](../reference/modules/index.md) are the places to look.
