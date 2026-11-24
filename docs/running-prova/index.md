---
sidebar_position: 6
sidebar_label: "Running Prova"
---

# Running Prova

Everything about *executing* your test suites — from ad-hoc runs against a single file on your laptop, to a zero-argument `prova` in CI driven by a checked-in manifest, to streaming machine-readable results into your own tooling. Writing tests is covered in [Writing Tests](../writing-tests/index.md); this section is about the runner itself.

## In this section

- **[The Command Line](./command-line.md)** — paths vs. manifest-driven runs, selection (`-k`, `--tags`, `--last-failed`), `prova eval`, the topology verbs (`up`/`start`/`down`/`ps`), every flag, discovery rules, and exit codes.
- **[Scaffolding](./scaffolding.md)** — `prova init`: render a catalog archetype into your project (interactively or headless), and author your own init catalog entries in `~/.config/prova/config.toml`.
- **[Manifest & Profiles](./manifest-and-profiles.md)** — `prova.toml`: declare what to run (and which packages) once, then switch environments with `--profile`.
- **[Capabilities](./capabilities.md)** — what the host must provide: `requires` and `must_run`, the built-ins, and declaring your own in `[capabilities]`.
- **[CI & Output](./ci-and-output.md)** — console, JSONL, TAP, and JUnit XML output, consuming the event stream, and the GitHub Action (with package caching).
- **[Locks, Flakes & Reruns](./locks-and-scale.md)** — house rules held across every prova instance, the FLAKY verdict and `prova stress`, `--resume` and `--reuse`, and time bounds.
- **[IDE Setup](./ide-setup.md)** — autocomplete, hover docs, and type-checking for your test files via lua-language-server, via `prova ide setup` (also run automatically by `prova init`).

## The shape of a run

Prova has exactly one command with two modes:

```shell
prova tests/orders.prova.lua    # explicit paths — run these, ignore any manifest
prova                           # no paths — run what ./prova.toml declares
prova --profile ci              # same, overlaying the `ci` profile from the manifest
```

Explicit paths always bypass the manifest entirely; flags on the command line always override manifest values. That's the whole model — a developer's quick loop and a CI pipeline are the same binary with the same semantics, and the manifest is just the place where "what CI runs" is written down and versioned.

:::tip
If you're new to Prova, run through the [Quick Start](../getting-started/quick-start.md) first — this section assumes you have a test file or two to point the runner at.
:::
