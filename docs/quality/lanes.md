---
sidebar_position: 3
---

# Lanes

A **lane** is a named, described way to run a project: a `[profiles.<name>]` table in the manifest.
`prova run <lane>` runs it, and `prova run --list` prints every lane with its description, so the way
to work with a project is discoverable without reading its Makefile, CI config or README.

```shell
$ prova run --list
  (default)  the [run] table — what bare `prova` runs
  all        the pre-push sweep: every black-box proof plus the ut and quality legs
  ci         must_run: cargo
  coverage   line coverage, ratcheted: cargo llvm-cov nextest against the committed baseline
  quality    code-quality gates: clippy -D warnings, the unwrap/expect ratchet, duplication, file sizes
  ut         the workspace's unit tests, conducted once via cargo nextest and adopted into the account
```

`prova run ci` and `prova --profile ci` are the same thing; `run` is the spelling that reads as a
lane. Manifest details are in [Manifest & Profiles](../running-prova/manifest-and-profiles.md).

## One interface for every project

When projects share lane names, a person or an agent arriving at an unfamiliar repository already
knows how to work in it, whatever language it is written in:

| Lane | Means | The deputy underneath |
|---|---|---|
| (default) | the fast inner loop: build smoke and black-box proofs | — |
| `ut` | the unit tests, adopted into the account | cargo nextest, Maven Surefire, pytest, Jest… |
| `quality` | lint walls and ratchets | clippy, ESLint, ruff… |
| `coverage` | line coverage, ratcheted | llvm-cov, JaCoCo, coverage.py… |
| `all` | the pre-push sweep, one exit code | everything above except coverage |
| `ci` | what the merge gate runs, with its environment guaranteed | — |

The names are a convention, not a built-in: a team adopts them by rendering the same init
archetype into every repository (see [the Rust retrofit](#the-rust-retrofit) below, and
[Scaffolding](../running-prova/scaffolding.md) for adding an organization's own archetypes).

## Switches keep expensive work out of the inner loop

Some proofs recompile a workspace or boot a cluster. Marking them `switch = "<class>"` makes them an
**opt-in class**: off unless something throws the switch.

```lua
prova.test("clippy is clean (-D warnings)", { switch = "quality", locks = { prova.writes("cargo") } },
function(t) … end)
```

```toml
[profiles.quality]
description = "code-quality gates: clippy -D warnings, the unwrap/expect ratchet, …"
proofs      = ["quality"]     # only proofs/quality/
switches    = ["quality"]     # and throw its class
```

A lane throws switches with `switches = [...]`; `-s quality` throws one ad hoc; `--node` on an exact
path implies it. The bare tally names the classes it held back on one line, so nothing is skipped
silently. `prova switches` lists every class, how many tests it gates, and which lanes throw it.

## `requires` skips; `must_run` fails

Two facts with two remedies:

- **`requires = { "cargo-nextest" }`** on a test is a fact about the *test*. When the tool is missing,
  the test skips with a reason. That is right on a laptop: a missing tool should not ruin a morning.
- **`must_run = ["cargo-nextest"]`** on a lane is a promise about the *environment*. When the tool is
  missing, the run fails before anything executes.

Without `must_run`, a CI runner that lost its toolchain skips every cargo-backed proof and still
exits 0: "we could not ask anything" reads the same as "we answered everything". Guarantees union
across `[run]` and the profile and can never be subtracted, so put a guarantee only on the lane that
makes it. What the tool names mean on this host is the [capabilities](../running-prova/manifest-and-profiles.md)
vocabulary: `prova capabilities` lists it.

## The Rust retrofit

```shell
prova init rust-project
```

Walk into any Rust project, single crate or workspace, and this renders the whole quality surface:
the lanes above, the [nextest deputy](./deputed-verifiers.md#conduct-once-read-many-cargo-nextest),
the clippy wall, the unwrap/expect, function-length, file-size and duplication
[ratchets](./ratchets.md), ratcheted coverage, and two GitHub workflows. It is promptless, reads
the project's layout from `cargo metadata` at run time instead of assuming one, and never
overwrites a file the project already has. The one step after rendering is the first-run ritual:

```shell
prova run quality --update-baseline
prova run coverage --update-baseline
git add .prova/baselines && git commit -m "establish the quality floors"
```

On a legacy codebase the floors land wherever the project stands: existing unwraps, giant files and
clones become standing debt to pay down, not a wall of red.

The archetype is served by the [package registry](../packages/using-packages.md) rather than
listed by `prova init --list`; any archetype a configured registry serves can be named directly.
Other languages use the same pieces (`junit.verify`, `sarif.verify`, `measure.ratchet`) and the same
lane names; packaging them as an organization's own init archetype is what makes the lanes
identical across its repositories.

## Next

- [Reminders](./reminders.md): a lane can also be the one that heeds reminders.
- [CI & Output](../running-prova/ci-and-output.md): running a lane in GitHub Actions.
