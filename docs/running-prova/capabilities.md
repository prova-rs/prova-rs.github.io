---
sidebar_position: 3.5
---

# Capabilities

A **capability** is a fact about the environment, not the code: a daemon that answers, a tool on
`PATH`, a client compiled into Prova, an operating system. Tests say what they need; Prova checks
the host. `prova learn capabilities` carries the same material in the binary.

```shell
prova capabilities          # the host's probes, plus everything this package declares or references
prova capabilities docker   # explain one: what it means here, what ran, what came back
```

## Two directions: `requires` skips, `must_run` fails

- `requires = { "docker" }` on a test, suite or topology **skips** it when the capability is unmet.
  The laptop without Docker runs everything else and stays green. A version can ride along:
  `"dotnet >= 9"`, `"node ^20"`.
- `must_run` on `[run]` or a profile **fails** the run (exit 2) when unmet, before anything runs.
  It is a lane's guarantee about its environment; see [Lanes](../quality/lanes.md#requires-skips-must_run-fails).

Neither is ever silently green. A misconfigured capability (a typo'd constraint, a bad regex) is an
error, not a skip, because a gate that never matched reads as green.

## Built-ins work undeclared

`docker` (a daemon that answers *and* runs Linux containers), `github` (`GITHUB_TOKEN` is set),
`unix` and `windows`, `network` and `internet`, the compiled-in clients (`http`, `sqlite`, `grpc`,
`graphql`, `yaml`), and **any binary on `PATH`**, probed with `--version`. The expression grammar is
in [Dependencies & Scheduling](../writing-tests/dependencies-and-scheduling.md#the-capability-expression).

## Declaring one: `[capabilities]`

Declare a capability when the default probe is not enough. Each entry is a name and exactly one
**factory**, the same grammar `[topologies]` uses:

```toml
[capabilities]
java    = { command = "java", version = ["-version"], stream = "stderr" }
kubectl = { command = "kubectl", version = ["version", "--client"],
            pattern = "GitVersion:\"v([0-9.]+)\"" }
gpu     = { package = "env", capability = "gpu" }     # a Lua predicate from a package
dockerd = { intrinsic = "docker" }                    # an alias for a built-in
"*"     = "error"                                     # what an undeclared name means
```

**`command`**: reach for this first. Most capabilities are "is this tool here, and which version".

| Key | Meaning |
|---|---|
| `command` | the executable (also the presence check when `probe` is absent) |
| `probe` / `expect` | arguments for the availability check (exit 0 means available) / output it must contain |
| `version` | arguments for the version query; `false` means the tool has no version |
| `stream` | where the tool prints: `stdout` (default), `stderr`, `both` |
| `pattern` | a regex over that output; the first capture group is the version |

`stream = "stderr"` is how `java -version` becomes readable at all. The parser normalizes what it
finds (`v1.30` becomes `1.30.0`).

**`package`**: for a fact no name and version can express, such as a GPU, a licence or a running
`kind` cluster. A package exports a predicate under `capabilities`, returning `true`, a version
string, or `false`:

```lua
local M = { capabilities = {} }
function M.capabilities.gpu() return probe_cuda() end   -- true | "2.4.0" | false
return M
```

It lives in a package, never a proof file: `must_run` is checked before any proof loads, and an
exported function is one a proof can call directly, which makes the predicate itself testable.

**`intrinsic`**: aliases a built-in, and states "not overridden" out loud.

## Closing the vocabulary

`"*"` decides what an undeclared name means: `probe` (the default: try it), `warn` (probe, and print
pasteable TOML for each one so you can declare it), or `error` (refuse). `warn` is the migration
step toward `error`. Strictness applies only to names Prova does not define, so a bare `unix` needs
no declaration.

An entry may redefine a built-in such as `docker`. Only the root manifest governs, and `prova
capabilities` marks the row `OVERRIDES the built-in`, so a reader never assumes a name means what it
means elsewhere.

## Capabilities are not intent

"Someone asked for this expensive class of tests" is a [switch](../quality/lanes.md#switches-keep-expensive-work-out-of-the-inner-loop),
not a capability. `requires` stays for what the world must provide.

## Migrating from the `prova.lua` companion

Before `[capabilities]`, custom capabilities were registered with `runtime.capability(name, fn)` in a
`prova.lua` (or `.prova/config.lua`) companion named by `[run] config`. It still works, with a
deprecation warning, and retires along with the `runtime` global, `[run] config`, `--config` and
`PROVA_CONFIG`. To migrate, move each predicate into a package under `capabilities` and declare it:
`gpu = { package = "<pkg>", capability = "gpu" }`.
