---
sidebar_position: 2
---

# Installation

Prova is a single static binary named `prova` — no runtime, no interpreter, nothing else to install. Pick whichever channel fits:

## Homebrew (macOS and Linux)

```shell
brew install prova-rs/tap/prova
```

To pin a major line or an exact version:

```shell
brew install prova-rs/tap/prova@0        # latest stable 0.x
brew install prova-rs/tap/prova@0.2.2    # exactly 0.2.2
```

The tap's formulas are generated automatically from each release — see [prova-rs/homebrew-tap](https://github.com/prova-rs/homebrew-tap).

## Release binaries

Every release publishes prebuilt archives on the [GitHub releases page](https://github.com/prova-rs/prova/releases), named `prova-<version>-<platform>-<arch>.tar.gz` (with SHA256 checksums alongside):

- `prova-v0.2.4-linux-x86_64.tar.gz`
- `prova-v0.2.4-linux-arm64.tar.gz`
- `prova-v0.2.4-macos-arm64.tar.gz`
- `prova-v0.2.4-windows-x86_64.zip` (plus a `-installer.exe`)

Download, extract, and put the binary on your `PATH`:

```shell
curl -LO https://github.com/prova-rs/prova/releases/download/v0.2.4/prova-v0.2.4-linux-x86_64.tar.gz
tar -xzf prova-v0.2.4-linux-x86_64.tar.gz
sudo mv prova-v0.2.4-linux-x86_64/prova /usr/local/bin/
```

In GitHub Actions, skip all of this — the [`prova-rs/run-action`](../running-prova/ci-and-output.md#the-github-action) action installs a release binary for you.

## Cargo (build from source)

If you have a [Rust toolchain](https://rustup.rs/), you can always build from source:

```shell
cargo install --git https://github.com/prova-rs/prova prova-cli
```

This builds the `prova-cli` crate and puts a `prova` binary on your `PATH` (in `~/.cargo/bin` by default).

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

- **Docker** — the container-backed primitives and [plugins](/docs/plugins/) (`docker.run`, `postgres.container`, and friends) talk to the Docker daemon directly. Install [Docker](https://docs.docker.com/get-docker/) and have the daemon running if your tests provision ephemeral containers.
- **Anything on your `PATH`** — tests that shell out to `cargo`, `git`, `kubectl`, etc. naturally need those tools present.

You do not need any of these installed just to run Prova. Tests declare what they need with `requires = { "docker" }` (or any tool name), and when a capability is missing the test is **skipped with a reason — never failed** — so the same suite degrades gracefully across machines. See [Testing Real Systems](../writing-tests/testing-real-systems.md).

:::tip
Once installed, `prova init` scaffolds a project — a `prova.toml` manifest plus editor completion for the whole API — in one command. The [Quick Start](./quick-start.md) walks through it.
:::

## Next

With `prova` on your `PATH`, build the mental model in [Core Concepts](./core-concepts.md), or jump straight to the [Quick Start](./quick-start.md).
