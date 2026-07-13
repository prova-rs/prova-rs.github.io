---
sidebar_position: 2
---

# Installation

Prova is a single Rust binary named `prova`. Today it installs from source with Cargo; a Rust toolchain is the only build requirement.

## Install with Cargo

If you don't already have Rust, install it via [rustup](https://rustup.rs/). Then:

```shell
cargo install --git https://github.com/prova-rs/prova prova-cli
```

This builds the `prova-cli` crate and puts a `prova` binary on your `PATH` (in `~/.cargo/bin` by default).

:::note Planned
Prebuilt static binaries, GitHub releases, and a Homebrew tap are planned — no toolchain required. Until then, `cargo install` from git is the supported path. See the [Roadmap](../reference/roadmap.md).
:::

## Verify the installation

Check the binary responds:

```shell
prova --version
```

Then verify discovery end to end. Prova finds test files named `*_test.lua` or `*.test.lua`; `--list` collects tests without running anything:

```shell
mkdir -p prova-smoke
cat > prova-smoke/smoke_test.lua <<'EOF'
prova.test("prova discovers this test", function(t)
  t:expect(true):is_true()
end)
EOF

prova --list prova-smoke
```

You should see the test's name printed:

```text
prova discovers this test
```

Run it for real with `prova prova-smoke` — it should report one passing test and exit `0`.

## Optional capability dependencies

Prova itself has no runtime dependencies, but some modules drive external tools:

- **Docker** — the container-backed modules and recipes (`docker.run`, `db.postgres`, `redis.container`, `kafka.container`, and friends) shell out to the `docker` CLI. Install [Docker](https://docs.docker.com/get-docker/) if your tests provision ephemeral containers.
- **Anything on your `PATH`** — tests that shell out to `cargo`, `git`, `kubectl`, etc. naturally need those tools present.

You do not need any of these installed just to run Prova. Tests declare what they need with `requires = { "docker" }` (or any tool name), and when a capability is missing the test is **skipped with a reason — never failed** — so the same suite degrades gracefully across machines. See [Testing Real Systems](../writing-tests/testing-real-systems.md).

:::tip
Set up editor support early — completion and type-checking on the `prova` API makes test authoring dramatically faster. See [IDE Setup](../running-prova/ide-setup.md).
:::

## Next

With `prova` on your `PATH`, build the mental model in [Core Concepts](./core-concepts.md), or jump straight to the [Quick Start](./quick-start.md).
