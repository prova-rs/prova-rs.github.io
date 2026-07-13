---
sidebar_position: 4
---

# IDE Setup

Prova tests are plain Lua, which means the mature Lua tooling ecosystem works on them out of the box — most importantly [lua-language-server](https://luals.github.io/) (LuaLS). Prova ships LuaCATS annotation stubs for its entire authoring surface, so with a small amount of one-time setup your editor knows the whole API.

## What you get

- **Autocomplete** for `prova.*`, `expect(...)` matchers, the context methods (`ctx:use`, `ctx:defer`, `ctx:manage`, `ctx:tempdir`), and every built-in module (`http`, `shell`, `fs`, `docker`, `postgres`, ...).
- **Hover documentation** — each function's docs, parameters, and return types inline in the editor.
- **Diagnostics** — typo'd function names, wrong argument shapes, and unknown globals flagged as you type.
- **Typed fixture handles** — `prova.fixture` returns a typed handle, and `ctx:use(handle)` flows the fixture's value type through to the call site, so the object your test receives is fully typed and completable. (Passing a bare string name still works, but yields an untyped `any` — one more reason to prefer handles.)

The stubs are `---@meta` files — pure annotations, no runtime behavior. They live in the Prova repository under `library/`:

- `library/prova.lua` — the test/fixture DSL: `prova`, `Scope`, contexts, `expect`, `suite`.
- `library/modules.lua` — the built-in modules: `fs`, `shell`, `http`, `docker`, `postgres`, `archetect`, and friends.

## Manual setup

:::note Planned
A `prova ide setup` command that installs the stubs and writes the editor configuration for you is on the [roadmap](../reference/roadmap.md). Until then, setup is two short manual steps.
:::

### 1. Install lua-language-server

```shell
brew install lua-language-server        # macOS
```

On other platforms, grab a release from the [LuaLS releases page](https://github.com/LuaLS/lua-language-server/releases) or your package manager. (VS Code users can skip this — the extension below bundles it.)

### 2. Point LuaLS at the stubs

Copy `library/prova.lua` and `library/modules.lua` from the Prova repository into a `library/` directory in your test project (or keep a Prova checkout somewhere and reference it by path). Then drop a `.luarc.json` at your project root — this is adapted from the one the Prova repository itself uses:

```json
{
  "runtime.version": "Lua 5.4",
  "workspace.library": [
    "library"
  ],
  "workspace.checkThirdParty": false,
  "diagnostics.globals": [
    "fs",
    "shell",
    "net",
    "http",
    "archetect",
    "docker",
    "db",
    "grpc",
    "graphql",
    "yaml",
    "redis",
    "pulsar",
    "kafka",
    "s3",
    "Scope",
    "suite"
  ],
  "completion.callSnippet": "Replace",
  "hint.enable": true
}
```

The pieces that matter:

- **`runtime.version`** — Prova embeds Lua 5.4; telling LuaLS so keeps diagnostics accurate.
- **`workspace.library`** — where the stubs live. If you keep them outside the project, use an absolute path or a path relative to the project root.
- **`diagnostics.globals`** — Prova injects its modules as globals in test files (no `require` needed), so LuaLS must be told they're expected; otherwise every `http.get` is an "undefined global" warning.
- **`completion.callSnippet` / `hint.enable`** — optional quality-of-life: argument snippets on completion and inlay type hints.

That's it — open a `*_test.lua` file and completion, hover, and diagnostics should be live.

## Editor pointers

**VS Code** — install the [Lua extension by sumneko](https://marketplace.visualstudio.com/items?itemName=sumneko.lua), which bundles lua-language-server. It picks up `.luarc.json` from the workspace root automatically; no further configuration needed.

**JetBrains IDEs** — IntelliJ-family IDEs don't bundle LuaLS, but LSP-client plugins can run it: install lua-language-server (step 1 above) and configure it through a Lua/LSP plugin from the marketplace. `.luarc.json` is read by the language server itself, so the same file drives the experience regardless of editor.

**Neovim / other LSP editors** — anything that can launch `lua-language-server` against your workspace gets the identical experience; `.luarc.json` is the single source of configuration.

:::tip
Commit `.luarc.json` (and the `library/` stubs, if vendored) to your test repository. Editor setup then becomes "clone and open" for everyone on the team — the same philosophy as checking in [`prova.toml`](./manifest-and-profiles.md).
:::

For the full annotated API surface the stubs describe, see the [Lua API reference](../reference/lua-api/index.md).
