---
sidebar_position: 1
sidebar_label: "CLI"
---

# CLI Reference

Complete reference for the `prova` command-line interface.

## Usage

```text
prova [OPTIONS] [PATHS...]      run tests (the default command)
prova run [<lane>]              run the suite through a named lane ([profiles.<lane>]) —
                                sugar for --profile; `prova run --list` lists this package's lanes
prova init [KEY] [INIT-OPTIONS] render a catalog archetype into this package, then wire IDE support
prova ide setup [--manage ...]  (re)wire LuaLS support: core stubs + .luarc.json
prova eval '<code>'             run a one-shot Lua snippet in the full prova environment
prova skill [--install]         print (or install) the embedded agent skill
prova learn [<topic>]           the topic catalog: progressive disclosure of how Prova works
prova introspect [<filter>]     the API surface: every function and value, signature + summary
prova tests [<sel>]             the tests lane: every node, tagged PROMISE or PROOF
                                (--promises/--proofs narrow; `burndown` and `falsify` drive)
prova specs                     the specs lane: claims and backlog items
                                (--claims/--backlog narrow; `capture`, `promote <id>`, `backfill`)
prova owed                      what this package still owes: open promises, unproven claims,
                                dangling covers, due reminders
prova evidence                  the whole account: CLAIMED / BOUND / PROMISED / ATTESTED, then owed
prova attest [<address>]        did the proof covering this claim actually RUN? (no address: every claim)
prova reminders                 the attention account: every reminder with its recorded state
prova switches                  every opt-in class (`switch = ...`), how many tests it gates, who throws it
prova reports [<name>]          artifacts the last run kept, each with a summary and its forms
prova capabilities [<name>]     what this host can do, and what this package declares
prova mcp                       serve an MCP stdio server whose tools mirror the CLI
prova up [<topology>] [<url>]   list/stand up a topology — local, or from a git repo that advertises it
prova start <topology>          stand up a topology detached (use `down` to stop)
prova down <topology>           tear down a detached topology
prova ps                        list running topologies
prova lock <token> -- <cmd>     hold a package lock while <cmd> runs (--reads, --machine)
prova locks [--machine]         who holds which lock right now, with the pid and command
prova stress --copies N ...     run each selected nextest case as N isolated copies: reproduce a flake
prova relay --to <addr>         pipe stdio to a socket: makes a listening mock spawnable
prova package lint <FILE>...    check package files against the namespacing grammar
prova packages [<query>]        search the configured package registries (info / add subcommands)
prova broker                    the single-machine reference placement broker (spec scaffolding —
                                not needed to use prova)
```

With no subcommand, positional arguments are files or directories containing
test files.

```shell
# Run the suite declared in prova.toml (found by walking up from the cwd)
prova

# Run specific files/directories (bypasses the manifest entirely)
prova proofs/ smoke.prova.lua

# Run a manifest profile — the two spellings are equivalent
prova --profile ci
prova run ci

# Run a subset: keyword, tags, exact node, or last run's failures
prova -k MySQL
prova --tags '!build'
prova --node "orders api › creates an order"
prova --last-failed

# Stream machine-readable JSONL events
prova --format json proofs/

# Discover tests without running them
prova --list proofs/

# Run up to 4 units concurrently
prova --jobs 4 proofs/

# Add an ad-hoc package for this run (repeatable; layers over the manifest)
prova -P redis=../prova-redis
```

## Options

All value-taking flags accept both `--flag value` and `--flag=value`.

| Flag | Default | Description |
|---|---|---|
| `-p`, `--profile <NAME>` | — | Overlay the named `[profiles.<NAME>]` from the manifest on `[run]`. Errors if the profile does not exist. `prova run <NAME>` is the memorable spelling. |
| `--manifest <PATH>` | walk-up discovery | Read the manifest from a specific path instead of discovering it (see below). |
| `--format <console\|json\|tap>` | `console` | Output format: human-readable console output, one JSON object per line on stdout (run/node started/finished events), or TAP (Test Anything Protocol). `--json` is shorthand for `--format json`. Any other value is a usage error. |
| `--color <auto\|always\|never>` | `auto` | Color console output. `auto` colors only a TTY and honors `NO_COLOR`. |
| `-q`, `--quiet` | — | Only print failures (with their header chain), the failure recap, and the summary. |
| `--progress <auto\|on\|off>` | `auto` | Narrate slow pauses (an image pulling, a readiness gate) on **stderr** so a run never looks hung. `auto` is on for a TTY, off when piped; stdout stays exactly the report. |
| `--junit <PATH>` | — | Also write a JUnit XML report to `PATH` (for CI dashboards). Composes with any `--format` — the stdout format and the XML file are independent sinks of the same event stream. The manifest's `[run] junit = "path"` does the same with no flag. |
| `--gha <auto\|on\|off>` | `auto` | GitHub Actions annotations (`::error file=,line=`) and a step-summary table. `auto` emits them only when running inside GitHub Actions. |
| `--record <PATH>` | — | Also write the run record to `PATH` (it is always written to `.prova/var/last-run.json`) — what executed and, named individually, what did **not**: skips with their gate's reason, and deselections. `prova attest` reads it. |
| `-j`, `--jobs <N>` | `1` | Run up to `N` units concurrently. Throughput only — never changes test semantics (flows stay serial; declared resources gate co-scheduling). |
| `-P`, `--package <name=source>` | — | Add an ad-hoc package for this run (repeatable). `source` takes the same string forms as a manifest `[dependencies]` entry. Layers **over** the manifest — a CLI entry overrides a manifest entry of the same name. See [Using packages](../packages/using-packages.md). |
| `-k <PATTERN>` | — | Select nodes whose path contains `PATTERN` (case-insensitive substring; repeatable). `!PATTERN` excludes instead. See [Selection semantics](#selection-semantics). |
| `--tags <a,b>` | — | Select nodes carrying any listed tag — their own or inherited from an enclosing group (comma-separated; repeatable). `!tag` excludes. |
| `--node <PATH>` | — | Select an exact node path (repeatable) — re-run precisely the node a report named. |
| `--last-failed` | — | Select only the nodes that failed in the previous run. With no failure state, prints a note and runs everything. |
| `--promises` | — | Select only [promised](../writing-tests/promises-and-burndown.md) tests — the open surface. Composes with the other selectors and with `--list`. |
| `--due` | — | Promises fall due: open promises report as real failures. With `--promises` this is burndown's mode; alone, the whole suite tolerates no open promise. |
| `--falsify` | — | Select only tests declaring `falsified_by`, apply each test's mutation, and **invert the verdict** — a body that survives its falsifier is reported vacuous and fails. `prova tests falsify` is `--falsify --allow-empty`. |
| `--allow-empty` | — | A selection matching no tests is OK (by default that is an error). |
| `--topology <NAME>` | — | Require attaching to the **held** topology `NAME` (error when it is not running) — judge the live environment, never a silently fresh one. |
| `--fresh` | — | Ignore held topologies: always provision fresh (the CI behavior). |
| `--heed` | — | Fail the run when any reminder is DUE — the ad-hoc form of the manifest's `heed_reminders` (a guarantee: it can only tighten). |
| `-u`, `--update-snapshots` | — | (Re)write `.snap` files instead of comparing — accept the current output as the new snapshot. See [Matchers](./lua-api/matchers.md#matches_snapshot). |
| `--update-baseline` | — | Move ratchet baselines (`.prova/baselines/`, written by `measure.ratchet`) toward this run's measurements. Tightens only; refuses to loosen — loosening is a hand-edit of the tracked baseline file, visible in review. |
| `--unreferenced <ignore\|warn\|delete>` | `ignore` | What to do with `.snap` files no test referenced this run: `warn` lists them and fails the run (exit `1`), `delete` removes them. Sound only on a **full** run — skipped (with a note) when any selection flag is active. |
| `-U`, `--update` | — | Force-refresh git package sources, skipping the freshness cache. |
| `--offline` | — | Never fetch git package sources; use only what is already cached. |
| `--list` | — | Discover and print every test/step path (one per line) without executing anything, then exit `0`. Respects selection. |
| `-V`, `--version` | — | Print `prova <version>` and exit `0`. |
| `-h`, `--help` | — | Print usage help and exit `0`. |

## Selection semantics

`-k`, `--tags`, `--node`, `--last-failed`, `--promises`, and `--falsify` compose into one selection:

- **Includes union, excludes veto.** A node runs if it matches *any* include
  (`-k pat`, `--tags a,b`, `--node path`) and *no* exclude (`-k '!pat'`,
  `--tags '!tag'`). With no includes at all, everything not excluded runs.
- **Dependency-aware.** A selected node's `depends_on` upstreams are pulled into
  the run automatically, so gates still gate.
- **Flow-atomic.** Selecting any step of a flow runs the whole flow — steps are
  never torn out of their sequence.
- **Cheap.** Deselected nodes never provision fixtures; a deselected node is
  reported as *deselected* (counted in the summary), never as skipped.
- Group `tags` are inherited by every node inside the group.
- Under a lane (`prova run <lane>`, a profile with `tags`), CLI selection
  narrows **within** the lane's set, never outside it.

## `prova run` — lanes

```text
prova run <lane> [<selection>]   # run the suite through [profiles.<lane>]
prova run --list                 # list this package's lanes, with their descriptions
```

Sugar for `--profile`, named for how teams use profiles: as **lanes** — one
`prova` for every layer of the quality account. A lane is shaped in the
manifest by what its profile selects (`tags`, `proofs`) and guarantees
(`must_run`); `description` is what `run --list` prints:

```toml
[profiles.ut]
description = "fast unit lane"
tags = ["unit", "!slow"]
```

`prova` is the whole bar; `prova run ut` is the inner loop.

## `prova init`

Scaffold a package by rendering a **catalog archetype** into the current directory, then wiring
LuaLS IDE support as a finishing step. The archetype owns the layout; Prova just selects and renders
it. Full guide: [Scaffolding](../running-prova/scaffolding.md).

```text
prova init                 # choose an archetype interactively, then render it here
prova init <key>           # render the named catalog entry
prova init --list          # print the catalog (keys + descriptions); renders nothing
```

The catalog is Prova's built-in `project` and `package` entries, any archetype a configured
registry serves (nameable directly, listed or not), and any `[init.*]` entries in
`~/.config/prova/config.toml` (a matching key replaces a built-in; a new key adds). With no key,
`prova init` prompts interactively; in a non-interactive context (no TTY) that is an error naming
`--list` / a key, never a hang.

| Option | Effect |
|---|---|
| `-a`, `--answer key=value` | Supply an archetype answer (repeatable). Overrides a baked config answer. |
| `-s`, `--switch name` | Pass an archetype switch (repeatable); unions with the entry's `switches`. |
| `--defaults` | Take each prompt's default instead of asking. |
| `--headless` | Never prompt; an unanswered, undefaulted prompt is an error, not a hang. |
| `--no-ide` | Skip the IDE-wiring finishing step (alias: `--no-luals`). |

Answer precedence, highest first: `--answer` → the entry's baked `answers` → injected package
state → an interactive prompt (or the archetype default with `--defaults`). `init` **refuses to
run** if any manifest location (`prova.toml`, `.prova.toml`, `prova/prova.toml`,
`.prova/prova.toml`) already exists — it never clobbers an existing layout — unless the catalog
entry declares `in_package = "allow"` (it augments a package rather than creating one; the
built-in `package` entry uses this to scaffold a local package into the `packages` directory).

## `prova ide setup`

Install the shared LuaCATS core stubs and create/merge the project's `.luarc.json` pointer — the
IDE-wiring half of `init`, as its own re-runnable verb (regenerate the machine-local `.luarc.json`
after a clone, or wire a project scaffolded some other way).

```text
prova ide setup                    # create-or-merge .luarc.json (default: manage = always)
prova ide setup --manage auto      # create if absent; if you already own one, leave it and hint
prova ide setup --manage never     # install stubs only; never touch .luarc.json
```

See [IDE setup](../running-prova/ide-setup.md) for what the annotations provide and the `[luals]
manage` policy.

## `prova eval`

```text
prova eval '<lua code>' [--format json] [--profile NAME] [--manifest PATH] [-P name=source]
prova eval -            # read the snippet from stdin
```

Run a one-shot Lua snippet in the **full prova environment** — the built-in
modules (`fs`, `shell`, `http`, `docker`, …), manifest-declared packages via
`require()`, and a real transient `ctx` — then print the returned value and
exit. Anything the snippet provisions through `ctx:manage`/`ctx:defer`/
`ctx:tempdir` is **torn down when it returns**, success or error.

The snippet may be a bare expression (`1 + 1`) or statements with an explicit
`return`. Pass `-` to read the snippet from stdin (unquotable payloads).

```shell
prova eval 'return 1 + 1'
prova eval 'return fs.exists("Cargo.toml")'
prova eval 'local db = require("postgres").container(ctx); return db.url'
```

Manifest resolution works exactly as on the run path (walk-up discovery,
`--manifest`, `--profile`, `-P/--package` layering), so `require("postgres")`
works from a project directory; **without a manifest the snippet still runs**
with just the built-ins.

Output: scalars print plainly (a string without quotes, so the value is
shell-friendly), `nil` prints nothing, and tables/arrays print as pretty JSON.
`--format json` (or `--json`) forces JSON for everything. Exit codes: `0` on
success, `1` if the snippet raises, `2` on usage errors.

## `prova learn`

```text
prova learn                # list the topic catalog
prova learn <topic>        # one topic, one screen
```

The progressive-disclosure knowledge surface: one screen per topic — `pdd`,
`promises`, `reminders`, `verifiers`, `falsify`, `claims`, `record`,
`evidence`, `project`, `init`, `authoring`, `fixtures`, `doubles`, `proxies`,
`drivers`, `topologies`, `packages`, `package-authoring`, `running`, `mcp` —
with aliases resolving (`mocks` → `doubles`). Topic slots render **this**
package's facts (its proofs, dependencies, topologies, profiles), so the
content is computed at call time rather than being a snapshot. A project can
add its own topics with the manifest's top-level `context = [...]` key, served
as `ctx:<stem>`; see [prova.toml](./prova-toml.md).

## `prova tests` — the tests lane

```text
prova tests [<selection>]   # every selected node, tagged PROMISE or PROOF; runs nothing
```

The run axis as a list: what exists, and in which state. `--promises` narrows to open promises and `--proofs` to settled proofs. Two drivers act on the lane: `burndown` and `falsify`. The older top-level verbs (`list`, `promises`, `burndown`, `falsify`) now print their replacement and exit.

### `prova tests --promises`

```text
prova tests --promises [<selection>]   # enumerate the open promise surface; runs nothing
```

Lists every [promised](../writing-tests/promises-and-burndown.md) test — proofs authored ahead of
their implementation. This is the executable spec's open surface: unlike a `TODO` grep it cannot go stale,
because the entries are the tests themselves. An empty list means the burndown is complete.

Composes with [selection](#selection-semantics), so `prova tests --promises -k websocket` narrows to one
area. Equivalent to `prova --promises --list`.

### `prova tests burndown`

```text
prova tests burndown [<selection>]   # run ONLY promised tests, open ones failing loud
```

The implementing loop. Runs just the promise surface and inverts the CI-friendly behavior: an
open promise reports as a real failure with its full error, which is what you want while driving
it green rather than while protecting a build.

Equivalent to `prova --promises --due`. An empty surface means **complete** — exit `0`, not a
selection error.

### `prova tests falsify`

```text
prova tests falsify [<selection>]    # apply declared falsifiers; INVERT the verdict
```

Prove the proofs can fail. Selects only tests declaring a `falsified_by` mutation, applies it,
and inverts the verdict: red under mutation is the passing result, and a body that survives its
falsifier is reported **vacuous** and fails the run. A proof without a falsifier is simply not
part of this pass (most never declare one). Equivalent to `--falsify --allow-empty`; the flag
composes with any selection. A declared falsifier costs nothing on the ordinary path — the
mutation runs only under the verb that asks for it.

## `prova owed`

```text
prova owed         # every open obligation, from every origin
prova owed --pin   # additionally: write text pins for the claims you confirm
```

The ledger's remainder, as one list: **PROMISED** tests (the open surface), **UNPROVEN** claims
(an anchored claim no proof covers), **DANGLING** covers (a `covers` naming prose that is not
there), **STALE** pinned claims (the anchored text changed since the pin), and **DUE** reminders.
An arriving agent asks one question — *what is owed here?* — and this is its answer.

## `prova evidence`

```text
prova evidence     # where does this project stand?
```

The whole account, as counts: **CLAIMED** (anchored claims in the declared docs), **BOUND**
(covered by at least one proof), **PROMISED** (proofs authored ahead), **ATTESTED** (covering
proof executed and passed in the recorded run), plus deputed cases and reminder states, then what
is owed. A report, never a gate: exit `0`, executes no proof body, safe on any machine.

## `prova attest`

```text
prova attest <doc.md#id>            # one claim: did its covering proof RUN and pass?
prova attest <id>                   # a bare claim id resolves when unique
prova attest junit:<suite>#<case>   # a deputed case: did this upstream case run and pass?
prova attest                        # every claim — the CI gate
```

Reads the **run record** (`.prova/var/last-run.json`, or wherever `--record` wrote it) and
answers whether the obligation is evidenced by an *executed, passing* proof. Skipped, deselected,
red, still promised, absent from the record, or covered by nothing — every one of those withholds
the attestation, because "0 failed" is not evidence and neither is a proof that never executed.
Where several proofs cover one claim they are all obligations, not a menu: one skipped sibling is
enough to withhold.

Exit `0` attested, `1` not attested (a real finding), `2` usage error (in CI a missing argument
is a broken pipeline, an unattested claim is a real finding). A package with no claims exits `0`
and says so.

## `prova reminders`

```text
prova reminders    # the attention account, DUE first
```

Lists every `prova.remind` with its recorded state — **DUE** (with its why and its instruction),
**WATCHING** (armed; the world holds still), **UNEVALUATED** (a `requires` unmet, or the
condition raised) — and **exits non-zero when any is due**: one exit-code answer for a pipeline.
Conditions evaluate during runs and land in the run record; this verb executes nothing (no
recorded run is exit `2`, with a note to run `prova` first). DUE never fails a *run* by default —
a lane opts in with the manifest's `heed_reminders = true`, or `--heed` for one invocation.

## `prova packages`

```text
prova packages                  # list every package the configured registries serve
prova packages <query>          # search by name / description / capability
prova packages info <name>      # details for one
prova packages add <name>[@ref] # pin it into [dependencies] in this package's manifest
```

Searches the configured package registries (git repos of TOML entries; discovery-only — `require`
never resolves through a registry). `add` writes the pinned source into the manifest so the
package resolves identically on a laptop and in CI, rather than being injected out-of-band. See
[Using packages](../packages/using-packages.md#finding-packages--the-registry).

## `prova skill`

```text
prova skill              # print the embedded agent skill to stdout
prova skill --install    # write it to .claude/skills/prova/SKILL.md at the project root
```

Print the **agent skill** — a compact document teaching a coding agent how to
drive Prova (the test-file idiom, the resource grammar, topologies, selection,
`eval`). It is embedded in the binary (`include_str!`), so it is versioned with
the features it describes and can never drift. `--install` writes it to
`.claude/skills/prova/SKILL.md` under the project root (found by walking up to
the manifest; the current directory if there is none), so the repo carries it
durably.

## Topology verbs: `up`, `start`, `down`, `ps`

The inhabited counterparts of a test run — they stand up a **registered topology**
(declared in the manifest's [`[topologies]` table](./prova-toml.md#topologies--environments-addressable-by-name), typically backed
by a package's factory) outside any test. All of them accept `--profile NAME` and
`--manifest PATH`, resolving the manifest and its packages exactly as a run does. The inhabited
verbs resolve registrations only — a `prova.topology(...)` declared inside a test file is a
fixture belonging to that file, not an addressable environment.

### `prova up [<topology>] [<url>]` — attached

```text
prova up                              # list the topologies this package registers
prova up <topology> [--fixed]         # stand one up, attached
prova up <git-url>                    # stand up a topology a remote repo advertises
```

Stand up the named topology, print each resource's endpoint (`name → url`),
and **hold it running until Ctrl-C** (SIGINT or SIGTERM), then run the normal
`ctx:manage` teardown. By default resources get **random host ports**
(parallel-safe — several topologies can be up at once); `--fixed` pins each
resource to its **canonical container port** on the host (postgres on `5432`,
redis on `6379`, …) for a predictable, external-tool-friendly address — only
one fixed instance of a port can run at a time.

A running `up` records itself under `<home>/running/<name>.json` (pid +
endpoints) so `prova ps`/`down` can supervise it, and removes the record on
clean teardown. Standing up a topology whose record is still live is refused;
a stale record (the holder is gone) is cleaned and the command proceeds.

### `prova start <topology>` — detached

```text
prova start <topology> [--fixed] [--profile NAME] [--manifest PATH]
```

Stand up the topology **detached**: spawns `prova up <topology>` in its own
process group (stdio to `<home>/running/<name>.log`), waits for it to come up
(up to 300s — provisioning can be slow on first image pulls), prints the
endpoints and the holder's pid, and returns, leaving it running. On failure it
prints the log tail.

### `prova down <topology>`

Tear down a detached topology by signalling its holder (SIGTERM), which runs
the same in-process teardown an attached Ctrl-C would — **one provisioning
path, one teardown path**. Waits up to 120s for the holder to exit.
Idempotent: a missing or stale record is not an error.

### `prova ps`

```text
prova ps [--manifest PATH]
```

List this project's running topologies — name, status, pid, uptime, and each
endpoint. Stale records (holder gone) are reported once and cleaned up.

## `prova package lint`

```text
prova package lint <FILE>...
```

Load each package file with the same primitives a run would install and check it
against the package namespacing grammar. Prints `ok <file> (resource; facets: …)`
or `ok <file> (library)` per clean file, `FAIL` with the issues otherwise; also
warns (non-fatally) when a package ships no `library/<name>.lua` LuaCATS stub.
Exits `0` when every file passes, `1` otherwise. See
[Authoring packages](../packages/authoring-packages.md).

## Paths vs. the manifest

- **With positional `PATHS`** — the manifest is bypassed entirely. Only the
  given files/directories run (relative to the cwd); `--jobs` defaults to `1`
  and `--format` to `console` unless passed explicitly. `[run.env]`, profiles,
  `[suites.*]`, and manifest `[dependencies]` are all ignored (`-P/--package`
  still applies).
- **Without positional `PATHS`** — Prova finds the manifest by **walking up**
  from the current directory (like git finding `.git`), checking each ancestor
  for one of `prova.toml`, `.prova.toml`, `prova/prova.toml`, or
  `.prova/prova.toml`. Finding more than one in the same directory is an error
  (ambiguous layout). It then resolves `[run]` (plus the `--profile` overlay,
  if any), applies `[run.env]` to the process environment, resolves
  `[dependencies]` (fetching git sources into the cache), and runs the
  manifest's `proofs` directories and declared `[suites.*]` — all manifest
  paths relative to the manifest's root. If no manifest is found, `prova`
  prints usage and exits `2`. `--manifest PATH` points directly at a manifest
  instead of discovering one.
- **CLI flags override manifest values**: `--jobs` and `--format` on the
  command line win over `jobs`/`format` resolved from the manifest, and
  `-P/--package` entries override same-named manifest dependencies.

On a manifest run (not `--list`), Prova also refreshes the IDE annotation
wiring (core stubs + each package's `library/`) and manages `.luarc.json` per
`[luals] manage` — never blocking the run (a sync error is a warning), with all
such output on stderr so `--format json` stdout stays a clean event stream.

See [prova.toml](./prova-toml.md) for the full manifest schema and merge semantics.

## Discovery rules

- Test files match `*.prova.lua` (`*_test.lua` and `*.test.lua` are also
  accepted). Directories are searched recursively. A file may declare tests,
  fixtures, topologies, and reminders — it is named for the collector. The bare
  `prova.lua` is the manifest companion, never collected.
- A path that names a **file** directly is run as-is, even if its name does not
  match the test-file pattern.
- A directory containing a `suite.lua` becomes **one suite**: `suite.lua` runs
  first as the setup file, and every test file in that directory's subtree loads
  into the same Lua state (sharing `Scope.Suite` fixtures).
- Every other discovered test file is a singleton suite of its own.
- If discovery finds no test files at all, `prova` reports the error and exits
  `2` (pass `--allow-empty` when an empty selection is expected).

## `prova mcp`

```shell
prova mcp [--profile NAME] [--manifest PATH] [-P name=source]
```

Serves Prova as an MCP server over stdio, resolved against the prova home exactly like a CLI run. The server's `instructions` field is the embedded [agent skill](#prova-skill), so MCP clients know Prova on connect. Every tool returns one text content item whose text is compact JSON (exception: `learn`, which returns markdown). Tools serialize FIFO — side effects land in the order you call them.

**Cold tools** mirror the CLI one-to-one:

| Tool | CLI equivalent | Result JSON |
|---|---|---|
| `run { keywords?, tags?, nodes?, last_failed?, promises?, due?, profile?, jobs?, package? }` | `prova` + selection flags | `{ passed, failed, skipped, deselected, duration_ms, failures: [{ path, message, file?, line? }] }` — `isError` when any node failed |
| `list { same selection fields, package? }` | `prova --list` | `{ nodes: [{ path }] }` |
| `eval { code, package? }` | `prova eval '<code>'` | the snippet's returned value as JSON |
| `owed { package? }` | `prova owed` | the open obligations |
| `evidence { package? }` | `prova evidence` | the account's counts |
| `attest { address?, package? }` | `prova attest` | the attestation verdict |
| `introspect { filter?, package? }` | — (see below) | `{ entries: [{ name, signature, summary }] }` |
| `learn { topic?, package? }` | `prova learn` | the topic as markdown; no `topic` lists the catalog |

A `run` also records the failed nodes, so a later `run { last_failed = true }` re-runs exactly them — the same state the CLI's [`--last-failed`](#selection-semantics) reads.

**`introspect`** answers *what the Lua API is* — every function's name, signature, and one-line summary — without a Lua environment, without provisioning, and **before a manifest even exists**. It is derived from the same LuaCATS stubs that drive editor completion, so it cannot drift from what an author sees; it is the tool an agent starts with instead of probing the surface by trial. Its in-Lua counterpart, callable from `eval` and test bodies, is [`prova.help([filter])`](./lua-api/prova.md#provahelp).

**`learn`** answers *how Prova works* — the [topic catalog](#prova-learn), rendered for **this**
package. Where `introspect` gives API shape, `learn` gives practice. The dynamic facts in a
topic — proof locations, declared dependencies, topologies, the init catalog — are computed at
call time, so they are always current rather than a snapshot. Topics are also protocol-native
resources: `prova://learn/<topic>` and `prova://skill`.

**`package`** targets a suite **anywhere on disk**, not just the directory the server started in. Pass a directory (resolved as a CLI run there would, walking up to find the home) or a `prova.toml` path directly. Omit it to use the server's startup package — its "affinity", like a shell being *in* a directory. A `package` always **resolves fresh**, re-reading the manifest and its dependencies, so a `prova.toml` you just scaffolded or edited is picked up **without restarting the server**. (`eval` works with no manifest at all, so a `package` there just roots [`prova.root`/`prova.home`](./lua-api/prova.md) and the dependency set at that home.)

### Warm topology tools (MCP-only)

The CLI is cold by design: every `prova` run re-provisions its fixtures. Over MCP the server can also be a **topology holder** — provision a [topology](../writing-tests/topologies.md) once and re-run against the held live instance in milliseconds. This is the one capability MCP has that the CLI does not; the CLI equivalent of holding an environment is [`prova up`/`start`](#topology-verbs-up-start-down-ps).

| Tool | Purpose | Result JSON |
|---|---|---|
| `up { name, package?, fixed? }` | Provision the named topology **once, inside the server**, and hold it across tool calls (`fixed` pins canonical ports, like `prova up --fixed`) | `{ name, resources: [{ name, url }] }` |
| `run { …, topology: name }` | Run **warm**: `t:use(<name>)` resolves the held instance instead of provisioning | same shape as a cold `run` |
| `eval { code, topology: name }` | Evaluate **warm** inside the held env — the held value is a global named after the topology (`return orders.db.url`) | the returned value as JSON |
| `down { name }` | Run the held scope's teardown (LIFO `ctx:manage`/`ctx:defer`) and release it | `{ name, down: true }` |
| `status {}` | List what's currently held | `{ held: [{ name, resources: [{ name, url }] }] }` |

The semantics in one breath: `up` provisions once and holds it; `run { topology }` and `eval { topology }` then resolve that **held instance** — the same live Lua values — so re-runs are milliseconds and **state accumulates across calls** (that is the point of warmth). The holder is the only reaper: `down` (or server shutdown) runs the one true teardown, and warm runs never tear the held instance down. A `run { topology }` **without a prior `up` is an explicit error** — warm mode never silently provisions. When you need isolation, `down` then `up`, exactly as a developer would.

## Exit codes

| Code | Meaning |
|---|---|
| `0` | The run completed and no test failed (skipped tests do not fail a run). Also used for `--list`, `--version`, `--help`, a successful `prova init`/`eval`/`skill`, a clean `prova package lint`, `prova evidence`, a quiet `prova reminders`, and a cleanly torn-down topology verb. |
| `1` | The run completed and at least one test failed, `--unreferenced warn` found orphaned snapshots, a `prova eval` snippet raised, `prova package lint` found issues, `prova reminders` found a DUE reminder, or `prova attest` found an obligation not attested. |
| `2` | Usage, configuration, or collection error: unknown flag, invalid flag value, unreadable or invalid manifest, ambiguous manifest layout, unknown profile, a package that fails to resolve, a manifest defining nothing to run, no test files found (without `--allow-empty`), a `must_run` guarantee unmet (a broken environment is not a skipped test), a file that fails to load/collect, `prova init` in an already-initialized package, or a topology that fails to provision / is already up. |
