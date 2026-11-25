---
sidebar_position: 2
---

# Bootstrap a Project

This guide gives a Rust project its quality surface in one command: a prova manifest, a black-box
suite, lanes for clippy, the unwrap census, unit tests and coverage, committed baselines, and CI
that runs the same lanes. The project can be brand new or years old; `prova init rust-project`
never overwrites a file the project already has.

For a project that is not Rust, `prova init project` renders the manifest and a starter suite
without the cargo lanes; [Scaffolding](../running-prova/scaffolding.md) lists every archetype.

## 1. Retrofit the project

From the project root (here a fresh `cargo new --lib greeter`):

```shell
prova init rust-project
```

The render prints what it added and what it kept:

```text
The bar:
  prova                 build smoke + your black-box proofs — the inner loop
  prova run quality     clippy -D warnings, unwrap/expect census, duplication, file sizes
  prova run ut          unit tests deputed via cargo nextest
  prova run coverage    line coverage, ratcheted
  prova run all         the pre-push sweep

Seams detection found (rendering preserved your files):
  * .gitignore already exists (kept) — add a `/.luarc.json` line to it
```

Add that line to `.gitignore`: `.luarc.json` is editor support with machine-local paths.

| Rendered | What it is |
|---|---|
| `.prova/prova.toml` | the manifest: the `quality`, `ut`, `coverage`, `all` and `ci` lanes |
| `proofs/blackbox.prova.lua` | a build smoke test and a placeholder for your black-box proofs |
| `proofs/quality/` | clippy at `-D warnings`, the unwrap/expect census, duplication, file and function sizes |
| `proofs/ut/`, `proofs/coverage/` | cargo nextest conducted once; line coverage |
| `clippy.toml` | the function-length threshold the census ratchets |
| `.github/workflows/` | CI running the same lanes through `prova-rs/run-action` |

## 2. Run the inner loop

```shell
prova
```

```text
proofs/blackbox.prova.lua
  PASS  the workspace builds — the artifacts black-box proofs drive exist
  PROMISED  the project's behavior is proven black-box, through its real artifacts

1 passed, 0 failed, 0 skipped, 1 promised, 8 deselected
switched off: coverage (1), quality (6), ut (1) — throw with -s <switch> or a profile's switches
```

Bare `prova` is fast on purpose. The heavy gates sit behind switches, so typing `prova` never
recompiles the workspace for clippy. The `PROMISED` placeholder is the first thing to replace: it
stays visible until the project has a real black-box proof. [The Proof-Driven
Change](../workflows/the-proof-driven-change.md) is the loop for writing one.

`prova run --list` shows every lane:

```text
  (default)     the [run] table — what bare `prova` runs
  all           the pre-push sweep: every black-box proof plus the ut and quality legs
  ci            must_run: cargo
  coverage      line coverage, ratcheted: cargo llvm-cov nextest against the committed baseline
  quality       code-quality gates: clippy -D warnings, the unwrap/expect ratchet, duplication, file sizes
  ut            the workspace's unit tests, conducted once via cargo nextest and adopted into the account
```

## 3. Record the baselines

The quality and coverage lanes hold numbers (the unwrap count, oversized functions, coverage) to
floors committed in `.prova/baselines/`. A lane with no floor refuses to pass, so record them once:

```shell
prova run quality --update-baseline
prova run coverage --update-baseline    # needs cargo-llvm-cov
```

```text
prova: baseline established quality:rust.expect.production = 0
prova: baseline established quality:rust.functions.too_long = 0
```

The establishing run reports red while it writes the floors. Run the lane again and it is green:

```shell
prova run quality
```

```text
6 passed, 0 failed, 0 skipped
```

Commit `.prova/baselines/` with the rest of the retrofit. From now on a floor moves only toward
better: `--update-baseline` tightens and never loosens. [Ratchets](../quality/ratchets.md) covers
goals and deadlines for paying debt down.

## 4. Before every push

```shell
prova run all
```

One command and one exit code for the black-box suite, the unit tests and the quality gates. CI
runs the same lanes from the rendered workflows, so a green `prova run all` locally predicts a
green pipeline. Pin the prova version in the workflows (`with: { version: v0.30.14 }`) so the bar
moves when you decide, not when the action's default does.

## What you have now

A new compiler or clippy warning is a red test in `prova run quality`, not a line in a build log.
For example, an unused variable:

```text
  FAIL  clippy is clean (-D warnings, whole workspace)
          error: unused variable: `unused`
          16 |     let unused = 1;
             = note: `-D unused-variables` implied by `-D warnings`
```

## Next

[Adopt a Standards Package](./adopt-a-standards-package.md): hold this project to the same bar as
every other repository in your organization.
