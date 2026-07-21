---
sidebar_position: 5
---

# IDE Setup

Prova tests are plain Lua, which means the mature Lua tooling ecosystem works on them out of the box — most importantly [lua-language-server](https://luals.github.io/) (LuaLS). Prova ships LuaCATS annotations for its entire authoring surface — and **wires them up for you**: on a project with a manifest, editor support is automatic, plugins included.

## What you get

- **Autocomplete** for `prova.*`, `expect(...)` matchers, the context methods (`ctx:use`, `ctx:defer`, `ctx:manage`, `ctx:tempdir`), and every built-in module (`http`, `shell`, `fs`, `net`, `docker`, `grpc`, ...).
- **Completion for your plugins** — `require("postgres")` is fully typed, because each plugin ships its own `---@meta` stub and Prova syncs it into the project automatically.
- **Hover documentation** — each function's docs, parameters, and return types inline in the editor.
- **Diagnostics** — typo'd function names, wrong argument shapes, and unknown globals flagged as you type.
- **Typed fixture handles** — `prova.fixture` returns a typed handle, and `ctx:use(handle)` flows the fixture's value type through to the call site, so the object your test receives is fully typed and completable. (Passing a bare string name still works, but yields an untyped `any` — one more reason to prefer handles.)

## Automatic setup

On a project with a [manifest](./manifest-and-profiles.md), wiring is one step — and it happens for you as the finishing step of [`prova init`](./scaffolding.md). To wire (or re-wire) a project on its own — say after cloning one someone else scaffolded — run the verb directly:

```shell
prova ide setup   # wire this project; also runs automatically at the end of `prova init`
```

Every subsequent `prova` run keeps things current, so declaring a new plugin and running the suite is enough to pick up its completions.

- **The core stubs** (`prova.lua`, `modules.lua`) are written once to a shared folder under Prova's data directory (`~/.local/share/prova/lua/annotations/`) — the same copy for every project on the machine, refreshed when you upgrade Prova. **Each plugin's** `---@meta` stub is read straight from that plugin's cached checkout. Nothing is copied into your project.
- **`.luarc.json`** at the project root — the one project-local file — points LuaLS (`workspace.library`) at the shared core stubs plus each declared plugin's stub directory, and declares Lua 5.4. It's re-derived when your plugin set changes. Because it holds **machine-local absolute paths**, it isn't shareable — **add it to `.gitignore`** rather than committing it.

Open the project in an editor running LuaLS and completion, hover, and diagnostics are live — including for `require("<plugin>")`.

### The `.luarc.json` policy: `[luals] manage`

Prova is deliberately polite about a file your project may own. The manifest's `[luals] manage` key controls the pointer (the shared core stubs are installed regardless):

| Policy | Behavior |
|---|---|
| `"auto"` (default) | Create `.luarc.json` when absent. If one already exists (a Lua-native project), leave it alone and print a hint. |
| `"always"` | Merge Prova's entries into an existing `.luarc.json` non-destructively (your other keys survive). |
| `"never"` | Never create or edit `.luarc.json`. |

`prova ide setup` is the explicit ask, so it creates-or-merges regardless of policy — running it once is also the fix when `auto` found a pre-existing `.luarc.json` and stayed out of it. If you keep `manage = "never"`, wire the pointer yourself: run `prova ide setup` once to see the exact `workspace.library` paths it would write, then add them to your own `.luarc.json`.

## Install lua-language-server

```shell
brew install lua-language-server        # macOS
```

On other platforms, grab a release from the [LuaLS releases page](https://github.com/LuaLS/lua-language-server/releases) or your package manager. (VS Code users can skip this — the extension below bundles it.)

## Editor pointers

**VS Code** — install the [Lua extension by sumneko](https://marketplace.visualstudio.com/items?itemName=sumneko.lua), which bundles lua-language-server. It picks up `.luarc.json` from the workspace root automatically; no further configuration needed.

**JetBrains IDEs** — IntelliJ-family IDEs don't bundle LuaLS, but LSP-client plugins can run it: install lua-language-server (above) and configure it through a Lua/LSP plugin from the marketplace. `.luarc.json` is read by the language server itself, so the same file drives the experience regardless of editor.

**Neovim / other LSP editors** — anything that can launch `lua-language-server` against your workspace gets the identical experience; `.luarc.json` is the single source of configuration.

:::tip
**Don't** commit `.luarc.json` — it holds machine-local absolute paths, so add it to `.gitignore`. Editor setup for a teammate is then "clone, run `prova ide setup`, open": the pointer is regenerated locally, and the annotations it points at are shared machine-wide, so nothing project-local needs to travel — the same clone-and-go philosophy as checking in [`prova.toml`](./manifest-and-profiles.md), just with the pointer generated rather than committed.
:::

## Manual setup (no manifest)

Running Prova purely ad hoc, with no manifest anywhere? There is nothing to sync annotations into, so point LuaLS at the stubs yourself: copy `library/prova.lua` and `library/modules.lua` from the [Prova repository](https://github.com/prova-rs/prova) into your project (or reference a checkout by path) and list that directory in a hand-written `.luarc.json`:

```json
{
  "runtime.version": "Lua 5.4",
  "workspace.library": ["library"],
  "workspace.checkThirdParty": false
}
```

The moment the project grows a manifest, delete the vendored stubs and let `prova ide setup` take over — the automatic path also keeps plugin annotations current, which the manual one cannot.

For the full annotated API surface the stubs describe, see the [Lua API reference](../reference/lua-api/index.md).
