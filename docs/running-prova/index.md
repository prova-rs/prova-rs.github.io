---
sidebar_position: 4
sidebar_label: "Running Prova"
---

# Running Prova

Everything about *executing* your test suites — from ad-hoc runs against a single file on your laptop, to a zero-argument `prova` in CI driven by a checked-in manifest, to streaming machine-readable results into your own tooling. Writing tests is covered in [Writing Tests](../writing-tests/index.md); this section is about the runner itself.

## In this section

- **[The Command Line](./command-line.md)** — paths vs. manifest-driven runs, selection (`-k`, `--tags`, `--last-failed`), `prova init`, `prova eval`, the topology verbs (`up`/`watch`/`start`/`down`/`ps`), every flag, discovery rules, and exit codes.
- **[Manifest & Profiles](./manifest-and-profiles.md)** — `prova.toml`: declare what to run (and which plugins) once, then switch environments with `--profile`.
- **[CI & Output](./ci-and-output.md)** — console, JSONL, TAP, and JUnit XML output, consuming the event stream, and the GitHub Action (with plugin caching).
- **[IDE Setup](./ide-setup.md)** — autocomplete, hover docs, and type-checking for your test files via lua-language-server, wired up automatically by `prova init`.

## The shape of a run

Prova has exactly one command with two modes:

```shell
prova tests/orders_test.lua     # explicit paths — run these, ignore any manifest
prova                           # no paths — run what ./prova.toml declares
prova --profile ci              # same, overlaying the `ci` profile from the manifest
```

Explicit paths always bypass the manifest entirely; flags on the command line always override manifest values. That's the whole model — a developer's quick loop and a CI pipeline are the same binary with the same semantics, and the manifest is just the place where "what CI runs" is written down and versioned.

:::tip
If you're new to Prova, run through the [Quick Start](../getting-started/quick-start.md) first — this section assumes you have a test file or two to point the runner at.
:::
