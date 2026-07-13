---
sidebar_position: 5
sidebar_label: "Reference"
---

# Reference

Normative reference documentation for Prova. Every page in this section documents shipped, implemented behavior — precise signatures, flags, keys, and semantics you can look up while writing tests. For task-oriented guides, see [Getting Started](../getting-started/index.md), [Writing Tests](../writing-tests/index.md), and [Running Prova](../running-prova/index.md). Planned-but-unshipped features are tracked in one place: the [Roadmap](./roadmap.md).

| Section | Description |
|---|---|
| [CLI](./cli.md) | The `prova` command: every flag, discovery rules, and exit codes. |
| [prova.toml](./prova-toml.md) | The full suite-manifest schema: `[run]`, `[profiles.*]`, `[suites.*]`, and how CLI flags interact with it. |
| [Lua API](./lua-api/index.md) | The injected globals and the complete `prova` DSL: fixtures, tests, flows, groups, contexts, and matchers. |
| [Modules](./modules/index.md) | The batteries: `fs`, `shell`, `http`, `grpc`, `graphql`, `docker`, `db`, `redis`, messaging, `s3`, `yaml`, and `archetect`. |
| [Roadmap](./roadmap.md) | The canonical list of planned features and what to use today instead. |
