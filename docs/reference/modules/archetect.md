---
sidebar_position: 9
---

# archetect

The flagship plugin: test [Archetect](https://archetect.github.io) archetypes by rendering them **in-process** via archetect-core — no subprocess, no terminal. Answers pass as plain data, failures surface as real diagnostics, and rendering is always **headless**: every prompt resolves from a supplied answer or its default, or errors immediately (a render can never hang waiting for input).

`archetect.render` is the primitive — render once, get a tree handle, assert on it. `archetect.verify` is the declarative layer on top — one table describing the archetype's contract, expanded into the standard tests. See [Testing Real Systems](../../writing-tests/testing-real-systems.md) for the narrative walkthrough.

## `archetect.render(opts)`

```lua
archetect.render(opts) --> RenderResult
```

Renders an archetype and returns a [tree handle](fs.md#path-handles-tree-filehandle-dirhandle) rooted at the destination.

| Option | Type | Description |
|---|---|---|
| `source` | `string` | Required. A local archetype path or a git URL |
| `answers` | `table<string,any>?` | Prompt answers as data — strings, integers, numbers, booleans, or string arrays |
| `switches` | `string[]?` | Switches to enable |
| `defaults` | `boolean?` | Take the default for every unanswered prompt (default `false`) |
| `destination` | `string?` | Render destination; a temp dir is created if omitted |

**Returns:** a `RenderResult`. Raises with the archetype's error if the render fails — including a prompt that has neither an answer nor a default.

### `RenderResult`

A tree handle plus the write log:

| Member | Type | Description |
|---|---|---|
| `path` | `string` | The destination root |
| `out:file(rel)` | `→ FileHandle` | Handle for a rendered file |
| `out:dir(rel)` | `→ DirHandle` | Handle for a rendered directory |
| `out:read()` | `→ string` | Read the contents at `path` |
| `writes` | `string[]` | The file paths written, in render order |

The handles carry a `path` field, so they pair directly with the [filesystem matchers](../lua-api/matchers.md) — including `:is_fully_rendered()`, which asserts no leftover template markers survive anywhere under the tree:

```lua
local rendered = prova.fixture("rendered", Scope.File, function(ctx)
  return archetect.render{
    source = "archetypes/rust-cli",
    destination = ctx:tempdir(),
    answers = { name = "widget", port = 9090 },
    defaults = true,
  }
end)

prova.test("renders the parameter-named file", function(t)
  local out = t:use(rendered)
  t:expect(out:file("widget.txt")):exists()
  t:expect(out):is_fully_rendered()
end)

prova.test("templates the answers into the contents", function(t)
  local body = t:use(rendered):file("widget.txt"):read()
  t:expect(body):contains("Hello, widget!")
  t:expect(body):contains("Port: 9090")
end)
```

## `archetect.verify(spec)`

```lua
archetect.verify(spec)             --> Fixture   -- one-shot: renders for you
archetect.verify(fixture, checks)  --> Fixture   -- compositional: checks a render fixture you declared
```

The declarative archetype check — prova's answer to a `manifest.yaml`-style harness, matched field-for-field but as real Lua you can extend. The one-shot form renders the archetype **once** (headless, into a scope-managed temp dir); the compositional form takes a render [fixture](../../writing-tests/fixtures.md) you declared yourself (your name, scope, destination, computed answers) and registers the same checks against it — which makes render → verify → black-box one pipeline sharing one rendering. Either way, the standard tests land under a `prova.describe` block named after the archetype:

- **layout** — every `expected_files` entry exists; every `absent_files` entry does not (registered only if either list is non-empty)
- **fully rendered** — no leftover template markers anywhere in the output (unless `fully_rendered = false`)
- **yaml manifests parse** — each `yaml_globs` glob matches at least one file, and every match parses (registered only if `yaml_globs` is non-empty)
- **build** — each `build_steps` command runs sequentially in the project dir and must exit 0; gated by `requires` and tagged `build` (registered only if `build_steps` is non-empty)

| Field | Type | Description |
|---|---|---|
| `source` | `string` | Required in the one-shot form (forbidden in the compositional form — the fixture owns the render). Local archetype path or git URL |
| `name` | `string?` | Label for the generated tests (default `"archetype"`) |
| `answers` | `table<string,any>?` | One-shot only. Prompt answers as data |
| `switches` | `string[]?` | One-shot only. Switches to enable |
| `defaults` | `boolean?` | One-shot only. Headless defaults for unanswered prompts (default `true`) |
| `scope` | `Scope?` | One-shot only. Scope of the render fixture it creates (default `Scope.File`) |
| `project_dir` | `string?` | Assert relative to this subdirectory of the render output |
| `expected_files` | `string[]?` | Files that must exist (relative to `project_dir`) |
| `absent_files` | `string[]?` | Files that must NOT exist |
| `yaml_globs` | `string[]?` | Each glob must match ≥ 1 file; each match must parse as YAML |
| `fully_rendered` | `boolean?` | Assert no leftover template markers (default `true`) |
| `requires` | `string[]?` | Capabilities gating the build test (e.g. `{ "cargo" }`) — missing tools skip it rather than fail |
| `build_steps` | `(string \| string[])[]?` | Commands run sequentially in the project dir (a list entry is joined with spaces) |
| `env` | `table<string,string>?` | Extra environment for `build_steps` |
| `timeout` | `string?` | Deadline for the build test and each of its steps (default `"600s"`) |

**Returns:** the shared render [fixture](../../writing-tests/fixtures.md), so you can add your own tests against the same output — the superset pattern.

```lua
local rendered = archetect.verify{
  name = "rust-cli",
  source = "archetypes/rust-cli",               -- or a git URL
  answers = { project_name = "widget", description = "a demo cli" },
  expected_files = { "Cargo.toml", "src/main.rs", "README.md", ".gitignore" },
  yaml_globs = { ".github/workflows/*.yaml" },
  requires = { "cargo" },
  build_steps = { "cargo build" },
}

-- Extend the standard checks with your own, against the same render:
prova.test("binary name matches the project name", function(t)
  local manifest = t:use(rendered):file("Cargo.toml"):read()
  t:expect(manifest):contains('name = "widget"')
end)
```

The compositional form inverts the ownership — declare the render, then point verify (and your black-box fixtures) at it:

```lua
local project = prova.fixture("project", Scope.File, function(ctx)
  return archetect.render{
    source = "archetypes/rust-cli",
    answers = { project_name = "widget", description = "a demo cli" },
    destination = ctx:tempdir(),
    defaults = true,
  }
end)

archetect.verify(project, {
  name = "rust-cli",
  expected_files = { "Cargo.toml", "src/main.rs" },
  requires = { "cargo" },
  build_steps = { "cargo build" },
})

-- The same fixture then feeds boot/probe fixtures — one rendering, one pipeline.
```
