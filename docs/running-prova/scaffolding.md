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
prova init package         # render the built-in `package` archetype
prova init --list          # print the catalog without rendering anything
```

With no key, `prova init` presents the catalog interactively and renders the one you pick. In a
non-interactive context (CI, a pipe) that has nothing to prompt on, so pass a key explicitly.

## The catalog

The catalog is the set of archetypes `prova init` can scaffold from. Two entries are built in, so
`prova init` works with zero configuration:

- **`project`** — the full default package: a `.prova/` nook (the manifest, `config.lua`, and a
  shared `lib` package under `.prova/packages/`) plus a `proofs/` starter suite, a CI workflow, and
  `.luarc.json`.
- **`package`** — a prova package that also exports a namespace others `require()`: an `init.lua`,
  a `[package]` table, and a self-test. Run inside an existing package it scaffolds a **local**
  package into the `packages` directory; outside one — or with `-s standalone` — it renders a
  repo-ready standalone.

Beyond the built-ins, any archetype a configured registry serves can be named directly — `prova
init <name>` resolves the name against the registry. And you extend or override the catalog in
**`~/.config/prova/config.toml`** under `[init.*]` — entries layer over the built-ins:

```toml
# ~/.config/prova/config.toml

[init.project]                       # a matching key REPLACES the built-in entry
description = "House proof-suite scaffold"
source      = "https://github.com/acme/prova-init"
switches    = ["ci"]                 # archetype switches always passed for this entry
defaults    = false                  # take the archetype's default for any unanswered prompt

[init.project.answers]               # baked answers — supplied to every render, never prompted
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

1. **`-a key=value` / `--answer key=value`** on the command line (repeatable).
2. **`[init.<key>].answers`** baked into `config.toml`.
3. **Injected package state** — scaffolding inside an existing package, Prova supplies the answers
   it already knows from that package without asking.
4. An **interactive prompt** (skipped by `--headless`), or the archetype's **own default**, taken
   without asking via `--defaults`.

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
| `-a, --answer key=value` | Supply an answer (repeatable). Overrides a baked answer. |
| `-s, --switch name` | Pass an archetype switch (repeatable); unions with the entry's `switches`. |
| `--defaults` | Take each prompt's default instead of asking (prompts without a default still ask). |
| `--headless` | Never prompt; an unanswered, undefaulted prompt is an error rather than a hang. |
| `--no-ide` | Skip the IDE-wiring finishing step (alias: `--no-luals`). |

`prova init` **never overwrites an existing manifest**: rendering into a project that already has
one is refused unless the entry declares `in_package = "allow"` — which is how the built-in
`package` entry can scaffold a local package inside an existing project. Whether a scaffold may
overwrite other files is the archetype's and the config entry's concern, not a Prova flag.

## After the render

Once the archetype is rendered, `prova init` runs the same wiring as [`prova ide setup`](./ide-setup.md)
over whatever manifest was produced, so your editor has completion immediately (unless `--no-ide`).
IDE wiring is also available on its own — run `prova ide setup` any time to (re)create `.luarc.json`,
for instance after cloning a project someone else scaffolded.
