---
sidebar_position: 2
---

# Scaffolding: `prova init`

`prova init` scaffolds a Prova project by **rendering an archetype** into the current directory, then
wiring up [editor support](./ide-setup.md) as a finishing step. The archetype — not a flag — decides
the layout: where `prova.toml` lands, what the proof directory is called, what starter files appear.

```shell
prova init                 # choose an archetype interactively, then render it here
prova init project         # render the built-in `project` archetype
prova init --list          # print the catalog without rendering anything
```

With no key, `prova init` presents the catalog interactively and renders the one you pick. In a
non-interactive context (CI, a pipe) that has nothing to prompt on, so pass a key explicitly.

## The catalog

The catalog is the set of archetypes `prova init` can scaffold from. It always contains a built-in
**`project`** (a standard proof-suite scaffold), so `prova init` works with zero configuration. You
extend or override it in **`~/.config/prova/config.toml`** under `[init.*]`:

```toml
# ~/.config/prova/config.toml

[init.default]                       # a matching key REPLACES the built-in entry
description = "House proof-suite scaffold"
source      = "https://github.com/acme/prova-init"
switches    = ["ci"]                 # archetype switches always passed for this entry
defaults    = false                  # take the archetype's default for any unanswered prompt

[init.default.answers]               # baked answers — supplied to every render, never prompted
proof_dir = "proofs"

[init.service]                       # a new key ADDS an entry
description = "Service proof suite, pre-wired for postgres + http"
source      = "/Users/me/archetypes/prova-service"   # a local path works too
```

- **`source`** is anything Prova can resolve: a git URL (optionally `#ref` — a tag, branch, or
  commit) or a local path.
- A matching key **replaces** the built-in entry outright (whole-entry, not a field merge); a new key
  **adds** one. `prova init --list` shows the union.

## Answering the archetype

Archetypes ask questions. Each answer can come from four places, highest priority first:

1. **`--answer key=value`** on the command line (repeatable).
2. **`[init.<key>].answers`** baked into `config.toml`.
3. An **interactive prompt** (skipped by `--headless`).
4. The archetype's **own default**, taken without asking via `--defaults`.

So a parameter like the proof-suite directory name can be **baked** (`answers.proof_dir = "proofs"`,
never asked), **prompted** (omit it — the archetype asks each time), or supplied **ad hoc**
(`--answer proof_dir=tests`). `--switch <name>` (repeatable) unions with the entry's `switches`.

```shell
prova init service --answer db_name=orders --switch ci     # feed the render
prova init project --headless                              # CI: never prompt (an unanswered,
                                                           # undefaulted prompt is an error, not a hang)
```

## Flags

| Flag | Effect |
|---|---|
| `--list` | Print the catalog (keys + descriptions) and exit; renders nothing. |
| `--answer key=value` | Supply an answer (repeatable). Overrides a baked answer. |
| `--switch name` | Pass an archetype switch (repeatable); unions with the entry's `switches`. |
| `--defaults` | Take each prompt's default instead of asking (prompts without a default still ask). |
| `--headless` | Never prompt; an unanswered, undefaulted prompt is an error rather than a hang. |
| `--no-ide` | Skip the IDE-wiring finishing step (alias: `--no-luals`). |

`prova init` **refuses to run** if the project already has a manifest — it never clobbers an existing
layout. Whether a scaffold may overwrite files is the archetype's and the config entry's concern, not
a Prova flag.

## After the render

Once the archetype is rendered, `prova init` runs the same wiring as [`prova ide setup`](./ide-setup.md)
over whatever manifest was produced, so your editor has completion immediately (unless `--no-ide`).
IDE wiring is also available on its own — run `prova ide setup` any time to (re)create `.luarc.json`,
for instance after cloning a project someone else scaffolded.
