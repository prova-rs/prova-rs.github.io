---
sidebar_position: 2
sidebar_label: "prova.toml"
---

# prova.toml Reference

The package manifest. Place a `prova.toml` at your repository root (or in a `prova/` / `.prova/`
nook) and `prova` with no arguments runs the configured suite — CI is just `prova`. Its tables:
`[run]` (the default profile), `[profiles.<name>]` (overlays selected with `--profile` /
`prova run <name>`), `[requires]` (the prova version this package needs), `[claims]` (the prose
side of the obligation ledger), `[suites.<name>]` (explicitly-declared suites), `[dependencies]`
(+ `[sources]`) for external packages, `[package]` (when this package exports a namespace),
`[topologies]`, `[globals]`, `[updates]`, `[luals]` for IDE integration, and `[agent]`.

One file, whichever hats it declares — there is no separate package manifest. A package that also
exports a namespace adds `[package]`; see [Authoring Packages](../packages/authoring-packages.md).

All tables and keys are optional, but a resolved run must yield at least one path or one suite,
or `prova` exits `2`.

## `[run]` — the default profile

| Key | Type | Default | Description |
|---|---|---|---|
| `proofs` | array of strings | `[]` | Directory-name patterns holding the proof suites to discover (`*.prova.lua`; `*_test.lua` / `*.test.lua` also accepted). This is the key `prova init` writes. |
| `config` | string | — | The runtime companion (`prova.lua` / `.prova/config.lua`) where [custom capabilities](../writing-tests/dependencies-and-scheduling.md#custom-capabilities-the-provalua-companion) are registered. |
| `packages` | string | — | **The** directory of this package's own local packages; each child directory is reachable as `require("<dir>")` with no declaration. No default — undeclared means none scanned. |
| `jobs` | integer | `1` | Maximum units run concurrently. Throughput only — never changes test semantics. |
| `format` | string | `"console"` | Output format: `"console"`, `"json"`, or `"tap"`. Any other value is an error (exit `2`). |
| `color` | string | `"auto"` | Console color: `"auto"` (TTY only, honors `NO_COLOR`), `"always"`, or `"never"`. CLI `--color` wins. |
| `progress` | string | `"auto"` | Narrate blocking pauses on stderr so a long run never looks hung: `"auto"`, `"always"`, `"never"`. |
| `quiet` | boolean | `false` | Print only failures, the recap, and the summary. CLI `--quiet` wins (it can only enable). |
| `github` | string | `"auto"` | GitHub Actions annotations + step summary: `"auto"` (on exactly when `GITHUB_ACTIONS=true`), `"on"`, `"off"`. CLI `--gha` and `PROVA_GHA` win. |
| `junit` | string | — | Also write a JUnit XML report to this home-relative path — the manifest form of `--junit`, so a CI profile needs no extra flag. |
| `env` | table of string → string | `{}` | Environment variables set for the whole run, applied to the process before any test executes. Written as a `[run.env]` sub-table. |
| `must_run` | array of strings | `[]` | Capabilities this run **guarantees**; an unmet one **fails** the run up front. See [below](#must_run). |
| `heed_reminders` | boolean | `false` | Fail the run when any reminder is DUE. Like `must_run` it is a guarantee: `[run]`'s or the selected profile's, whichever promises attention, wins — a laxer profile can never silence it. `--heed` promotes a single invocation the same way. |

### `must_run`

`must_run` is the inverse of a test's [`requires`](../writing-tests/dependencies-and-scheduling.md#capability-gating-requires). Where `requires` **skips** a unit whose capability is absent, `must_run` **fails the whole run** — before anything executes — if a guaranteed capability is missing. It stops a green "0 failed" from hiding "everything skipped" (a CI box that lost its Docker daemon, say).

```toml
[run]
must_run = ["docker"]

[profiles.ci]
must_run = ["docker", "dotnet >= 9"]   # unmet → FAIL, never skip
```

- **Same grammar as `requires`** — a name, optionally with a semver constraint (`"dotnet >= 9"`, `"unix"`), resolved by the same probes. No capability is privileged; `must_run = ["kubectl"]` means kubectl on `PATH`.
- **Checked as a precondition** (fail-fast), reporting the probe's own answer, e.g. `profile 'ci' guarantees capability 'docker', which is unavailable`.
- **Additive across `[run]` and the selected profile** — the sets are **unioned**, so a laxer profile can never silence a stricter guarantee. A `must_run` naming an unregistered/typo'd capability still fails (a guarantee that can't be honored).
- Custom capabilities registered in [the runtime companion](../writing-tests/dependencies-and-scheduling.md#custom-capabilities-the-provalua-companion) work here too.

:::note Empty selection is also a failure
Related to the same "silent green" hazard: a selection that matches nothing (`-k thisdoesnotexist`) exits non-zero rather than reporting `0 passed`. Opt out with `--allow-empty`.
:::

## `[profiles.<name>]` — overlays, worn as lanes

Each profile accepts the same keys as `[run]` (`proofs`, `jobs`, `format`, `color`, `progress`,
`quiet`, `github`, `junit`, `env`, `must_run`, `heed_reminders`), plus its own `dependencies`
table and two lane-shaping keys of its own:

| Key | Type | Description |
|---|---|---|
| `description` | string | What `prova run --list` prints for this lane. |
| `tags` | array of strings | The lane's baked selection: tags a leaf must carry to be in this lane (`!tag` excludes — the same grammar as `--tags`). CLI selection then narrows **within** the lane, never past it. |

Selecting a profile with `prova --profile <name>` (or `prova run <name>`) overlays it on `[run]`:

- `proofs`, `tags` — the profile's **replace** the base's, but only if the profile's list is
  non-empty; an absent or empty list inherits the base (a lane defines its own set).
- `jobs`, `format` — taken from the profile when present, otherwise from `[run]`.
- `env` — **merged** key-by-key: base entries first, then the profile's entries; on a key
  collision the profile wins.
- `must_run` — **unioned** with the base: the profile's guarantees are *added* to `[run]`'s,
  never subtracted (a guarantee is additive by design). `heed_reminders` follows the same rule:
  either table promising attention wins.
- `dependencies` — `[profiles.<name>.dependencies]` entries are **overlaid** on the project-wide
  `[dependencies]` set: the base packages all remain available, the profile adds its own, and a
  same-named entry from the profile wins. See [below](#profile-scoped-dependencies).
- Naming a profile that does not exist is an error (exit `2`).

## `[requires]` — the version this package needs

```toml
[requires]
prova = ">= 0.17"
```

Declares the minimum prova a suite needs, so an out-of-date binary says so **up front** instead of
failing somewhere in the middle with whatever symptom the missing feature happens to produce.

**Write `>=`.** The value is a semver *range*, and a bare `"0.17"` means `^0.17`, which on 0.x is
`>=0.17.0, <0.18.0` — a wall that refuses the very upgrades a suite should keep working across.
`>= 0.17` is how you say "this version or newer".

Read **before** the rest of the manifest is validated, from generic TOML. That ordering is what
lets it work at all: `[run]` and friends reject unknown keys, so a manifest written for a newer
prova would otherwise fail on a key this binary has never heard of — and "unknown field" is the
wrong diagnosis for an out-of-date binary. Two consequences worth knowing: `[requires]` must never
change shape, and the version must stay parseable by every future binary, because the binary that
needs to read it is by definition the old one.

The same key also declares a **package's** compatibility range (see
[Using Packages](../packages/using-packages.md)), and it means exactly the same thing in both
places. That is not a coincidence to be tidied away later: a `prova.toml` is one file wearing
whichever hats it declares, and `prova init package` scaffolds a package that carries its own
proof suite — so one `requires.prova` is read once by the package gate and once by the dependency
resolver. They must agree, and a proof holds them to it.

## `[claims]` — the prose side of the obligation ledger

```toml
[claims]
docs = ["docs/design", "README.md"]
```

Files and directories scanned for `<!-- claim: id -->` anchors — normative prose a proof binds to
with `covers = "<doc>#<id>"`, reconciled by `prova owed` / `prova evidence` / `prova attest`.
Package-relative, and scoped deliberately: prova must never crawl a whole repo looking for prose.

**Absent by default, and absence is the whole opt-out**: no section means no scan, no cost. An
unproven claim never turns a green suite red — the scan belongs to the query verbs, not to `prova`.

## `[suites.<name>]` — explicit suites

Declares a named suite whose files load into **one Lua state**, so `Scope.Suite`
fixtures are built once and shared across them. Use it when the grouping does not
match the directory tree; a directory's own `suite.lua` is the zero-config
alternative (see [CLI discovery rules](./cli.md#discovery-rules)).

| Key | Type | Default | Description |
|---|---|---|---|
| `paths` | array of strings | `[]` | Files/directories whose discovered test files form the suite. **`paths`, not `proofs`** — the two mean different things (literal paths here; directory-*name* patterns in `[run]`), and writing `proofs` in a suite is an error. |
| `setup` | string | — | Optional setup file (a `suite.lua`) loaded first; where suite-scoped fixtures and `suite.config{...}` live. |

Declared suites run **in addition to** the resolved `proofs`, and are not affected
by profile overlays. Capability gating and environment belong in the setup file
(`suite.config{ requires = ... }`) and `[run.env]`, not in the suite declaration.

## `[dependencies]` — external packages

Maps each name `require()` will resolve in test files to a **package source** — a
local path or a git repo. The project-wide `[dependencies]` set applies to every
run; a profile can layer additional (or overriding) entries on top with
`[profiles.<name>.dependencies]` (see below).

```toml
[dependencies]
greet    = "./packages/greet.lua"                          # local path shorthand
postgres = "prova-rs/prova-postgres@v1"                    # org/repo@ref → GitHub (@ref required)
redis    = "github:acme/prova-redis@v1"                    # host-prefix shorthand
rabbitmq = { git = "https://github.com/acme/prova-rabbitmq", tag = "v1.0.0" }
nats     = { git = "https://github.com/acme/prova-nats", rev = "abc123", module = "src/nats.lua" }
```

The detailed table form takes exactly one of `path` / `git`, an optional pin
(`tag` / `branch` / `rev`), and an optional in-repo `module` path. Git sources
are fetched into a local cache keyed by URL + ref and reused across runs; pin
tags for reproducibility. `-P`/`--package name=source` adds an ad-hoc package on
top of (and overriding) the manifest's set. A package's own `[dependencies]`
resolve transitively and stay private to it.

A companion `[sources]` table registers aliases for shorthands
(`acme = "github:acme"` makes `"acme:prova-redis@v1"` a valid source), and
`[luals]` controls whether prova manages the project's `.luarc.json` pointer for
editor completion (`manage = "auto" | "always" | "never"`, default `"auto"`).

Every source form, resolution rule, and the caching/freshness semantics are
documented in [Using Packages](../packages/using-packages.md).

## Profile-scoped dependencies

A `[profiles.<name>.dependencies]` table declares packages of the profile's own,
overlaid on the project-wide `[dependencies]` set when the profile is selected.
This is the principled home for CI-only or nightly-only capabilities: the
package is still declared in `prova.toml` — pinned in-repo, versioned with the
tests — instead of injected as an out-of-band flag in a workflow file.

```toml
[dependencies]
redis = "prova-rs/prova-redis@v1"

[profiles.ci]
[profiles.ci.dependencies]
kafka = "acme/prova-kafka@v2"           # only resolved under --profile ci
redis = "./packages/redis-ci.lua"       # overrides the project-wide entry under ci
```

The overlay is per-entry: base packages remain available under the profile, the
profile's entries are added, and a same-named profile entry **wins** over the
base. Values take every source form `[dependencies]` accepts. `-P`/`--package`
still layers over the fully resolved (base + profile) set.

## `[topologies]` — environments addressable by name

Names an environment a package can stand up, so `prova up <name>` (and any proof) can reach it.
Sugar for `prova.topology(<name>, require(<package>).<factory>)` — a property of the package, not
a profile. The inhabited verbs (`up`/`start`/`watch`/`ps`) resolve **registered** topologies only.

```toml
[topologies]
vm = { package = "parallels", topology = "vm", options = { image = "ubuntu-24.04" } }
```

| Key | Type | Default | Description |
|---|---|---|---|
| `package` | string | *required* | The package providing it — a name from `[dependencies]`, or a local package under `[run] packages`. |
| `topology` | string | — | The package's **advertised** topology name (`[[package.topologies]]`). Mutually exclusive with `factory`. |
| `factory` | string | — | A dotted path to a factory inside the package's namespace, when it advertises none. Mutually exclusive with `topology`. |
| `requires` | array of strings | `[]` | Capabilities the environment needs, added to whatever the package's advertisement declares. Unmet blocks `prova up` **before** provisioning. |
| `options` | table | `{}` | Passed to the factory as its second argument — what the factory needs and the caller cannot otherwise supply. Absent → registered bare. |

Exactly one of `topology` / `factory` must be present. Because `requires` is checked before
anything is provisioned, a machine without the capability **skips cleanly** rather than failing
half-way through a stand-up.

## `[package]` — exporting a namespace

The declaration that makes this package `require()`-able by consumers — the second hat. See
[Authoring Packages](../packages/authoring-packages.md) for the full contract.

| Key | Type | Description |
|---|---|---|
| `name` | string | Canonical name — namespaces the package's own internal `require()`s, independent of any consumer alias. |
| `entry` | string | Entry file, relative to the package root. Resolution precedence: consumer `module =` → `entry` → `init.lua` → `<alias>.lua`. |
| `description` | string | What registries index and `prova packages` prints. |
| `license` | string | SPDX identifier. |

A package may also advertise topologies:

```toml
[[package.topologies]]
name     = "vm"
factory  = "topologies.vm"
requires = ["prlctl"]
```

## `[globals]` — which modules are ambient

Every bundled namespace — `fs`, `shell`, `http`, `json` and the rest — is injected as an
unqualified ambient global by default, so a proof reads without a preamble of imports; the
canonical form `prova.<name>` (`prova.fs`, `prova.shell`, …) is always bound regardless.
`[globals]` is the knob for teams that would rather be explicit — a top-level table, a property
of the package:

```toml
[globals]
inject = ["fs", "shell", "http"]
```

`inject` lists the module names (bundled modules and/or declared package names) bound as
unqualified globals. **Absent means the default set; a present list is the whole truth** — even
`inject = []`, which injects nothing and leaves every module reachable through `prova.<name>` or
`require`. A name that is neither a bundled module nor a declared dependency is an error (a typo
would otherwise silently change what your files see).

## `[updates]` — freshness policy for git package sources

Governs the shared cache's gate for `[dependencies]` git sources: inside `interval` the cache is
used with no network at all; past it, a cheap `ls-remote` decides whether a pull is actually
needed. Mirrors archetect's `updates` config, so the sibling tools read the same knobs.

| Key | Type | Default | Description |
|---|---|---|---|
| `interval` | duration string | `1d` | How long a cached source is trusted without checking. `"1d"`, `"12h"`, `"30m"`, `"3600s"`, or a bare integer (seconds). |
| `force` | boolean | `false` | Ignore the freshness gates entirely. The CLI `-U` / `--update` also sets this. |
| `retention` | duration string | `90d` | How long an unused materialized source tree survives before the quiet prune reaps it. |

`--offline` is the opposite end: never fetch, use only what is already cached.

## `context` — project docs an agent can discover

A top-level array of markdown/text files surfaced by [`prova learn`](./cli.md#prova-learn)
as `ctx:<stem>` topics, so a team's own doctrine rides the same discovery rail as prova's built-in
ones — an agent finds it by listing topics rather than by being told a path.

```toml
context = ["docs/agent.md", "~/team/conventions.md"]
```

Paths are home-relative and `~/` expands. A property of the package, not a profile. A declared file
that does not exist is **reported loudly** by `learn` rather than silently skipped — a context doc
nobody notices has gone missing is worse than none.

Note it is a top-level key. Putting `context` inside `[run]` is an error rather than a
silently-ignored setting. (A zero-config sibling: a `.prova/CONTEXT.md` file, when present, is
inlined into `prova learn project` with no manifest entry at all.)

## `[agent]` — how `prova learn` addresses an agent

| Key | Type | Default | Description |
|---|---|---|---|
| `spec_first` | boolean | `true` | Whether `prova learn project` nudges spec-first PDD — author behaviour as [promised](../writing-tests/promises-and-burndown.md) proofs, then burn them down. Set `false` for a package not run that way. |

It is a one-line inclination in `learn`, never a gate: turning it off changes what an agent is
*told*, not what prova enforces.

## `[luals]` — editor integration policy

Controls whether prova manages the project's `.luarc.json` pointer for LuaLS completion.

| Key | Type | Default | Description |
|---|---|---|---|
| `manage` | string | `"auto"` | `"auto"` — create if absent, else reconcile prova's entries quietly and non-destructively (user keys untouched, identical content never rewritten, so the steady state is silent); a file prova cannot parse as plain JSON is left alone with a hint. `"always"` — same reconcile, but an unmergeable file is an error, for the explicit `prova ide setup` ask. `"never"` — install annotations, never touch the pointer. |

`.luarc.json` holds machine-local absolute paths, so it usually belongs in `.gitignore`. Set
`manage = "never"` when the file is deliberately committed and hand-maintained.

## Complete annotated example

```toml
[run]                       # the default profile (`prova` with no --profile)
proofs = ["proofs"]         # directory patterns to discover (*.prova.lua)
jobs   = 4                  # concurrency — throughput only
format = "console"          # "console" (human) | "json" (JSONL event protocol)

[run.env]                   # environment for the whole run
LOG_LEVEL = "info"

# Declare the prova this suite needs; an older binary says so up front.
[requires]
prova = ">= 0.17"

# The prose side of the ledger: scan these for <!-- claim: id --> anchors.
[claims]
docs = ["docs/design"]

# `prova run ci`: inherits proofs/format, overrides jobs, merges env, adds guarantees.
[profiles.ci]
description = "the merge gate"
jobs     = 8
format   = "json"
must_run = ["docker"]
[profiles.ci.env]
CI = "true"

# A fast subset for the inner loop: `prova run smoke`.
[profiles.smoke]
description = "the inner loop"
proofs = ["proofs/smoke"]

# A tag lane: `prova run ut` — CLI selection narrows within it.
[profiles.ut]
description = "fast unit lane"
tags = ["unit", "!slow"]

# An explicit suite: these files share one Lua state (Scope.Suite fixtures).
[suites.grpc]
paths = ["services/grpc"]
setup = "services/grpc/suite.lua"

# External packages: `require("postgres")` in any test file resolves to this source.
[dependencies]
postgres = "prova-rs/prova-postgres@v1"
```

## Resolution order

How the manifest, `--profile`, `--manifest`, and CLI arguments interact:

1. **Explicit path arguments bypass the manifest entirely.**
   `prova proofs/foo.prova.lua` never reads `prova.toml` — no profiles, no
   `[run.env]`, no declared suites.
2. Otherwise Prova discovers the manifest by walking up (any of `prova.toml`,
   `.prova.toml`, `prova/prova.toml`, `.prova/prova.toml`), or reads the file
   named by `--manifest`. An unreadable manifest is an error when `--manifest`
   or `--profile` was given; with neither, `prova` prints usage instead. Both
   exit `2`.
3. `--profile <name>` (or `prova run <name>`) overlays `[profiles.<name>]` on
   `[run]` as described above.
4. The resolved `env` is applied to the process environment.
5. **CLI flags win last**: `--jobs` and `--format` override the resolved
   `jobs`/`format`.
