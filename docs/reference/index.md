---
sidebar_position: 9
sidebar_label: "Reference"
---

# Reference

Normative reference documentation for Prova. Every page in this section documents shipped, implemented behavior — precise signatures, flags, keys, and semantics you can look up while writing tests. For task-oriented guides, see [Getting Started](../getting-started/index.md), [Writing Tests](../writing-tests/index.md), and [Running Prova](../running-prova/index.md). Planned-but-unshipped features are tracked in one place: the [Roadmap](./roadmap.md).

| Section | Description |
|---|---|
| [CLI](./cli.md) | The `prova` command: every flag, discovery rules, and exit codes. |
| [prova.toml](./prova-toml.md) | The full manifest schema: `[run]`, `[profiles.*]`, `[specs]`, `[topologies]`, `[capabilities]`, `[modules]`, `[runner]` and the rest, and how CLI flags interact with it. |
| [API Index](./api.md) | Every function, method and type the binary reports, with signature and summary. Generated from `prova introspect`. |
| [Lua API](./lua-api/index.md) | The injected globals and the complete `prova` DSL: fixtures, tests, flows, groups, contexts, and matchers. |
| [Modules](./modules/index.md) | The built-ins: `fs`, `shell`, `net`, `http`, `grpc`, `graphql`, `docker`, `sqlite`, `yaml`, the stream drivers, the data formats, `archetect`, and the verifier namespaces (`junit`, `sarif`, `measure`, `report`, `date`). |
| [Packages](../packages/index.md) | Service containers and clients — Postgres, MySQL, Redis, Kafka, Pulsar, RabbitMQ, S3 — as external packages: using, authoring, and the official catalog. |
| [Roadmap](./roadmap.md) | The canonical list of planned features and what to use today instead. |
