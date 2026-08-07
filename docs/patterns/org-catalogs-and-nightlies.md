---
sidebar_position: 6
---

# Org Init Catalogs & Nightly Lanes

Two supporting shapes that show up around every fleet running the
[shared standards pattern](./shared-standards-package.md): baking the org's defaults into
`prova init` so every new repo starts compliant, and running network-touching freshness checks on
a schedule instead of in the merge gate so they can exist at all.

## Org init catalogs

The [`prova init` catalog](../running-prova/scaffolding.md#the-catalog) layers `[init.*]` entries
from `~/.config/prova/config.toml` over the built-ins. An org uses that to make the *default*
scaffold the org's scaffold — same key, so muscle memory (`prova init project`) now renders the
house archetype, with the org's answers baked in and never prompted:

```toml
# ~/.config/prova/config.toml

[init.project]                        # same key: REPLACES the built-in entry
description = "Acme proof-suite scaffold"
source      = "https://github.com/acme/prova-init"
switches    = ["ci"]                  # always render the CI workflow

[init.project.answers]
proof_dir = "proofs"                  # baked — supplied to every render, never asked

[init.service]                        # new key: ADDS an entry
description = "Service suite, pre-wired for postgres + http"
source      = "https://github.com/acme/prova-init-service"
```

The scaffold is where the standards package earns compounding interest: the archetype renders the
`[dependencies]` pin and the thin `proofs/standards_test.lua`, so a repo is held to the bar from
its first commit, not retrofitted later.

Beyond the config file, any archetype a configured registry serves can be named directly —
`prova init <name>` resolves the name against the org's registry, so the catalog scales past what
one config file lists.

### The local-path-override gotcha

While an archetype incubates, its author points the entry at a working copy:

```toml
[init.service]
source = "/Users/dev/archetypes/prova-init-service"   # incubating
```

**Delete that entry once the archetype is registered.** The config entry wins over registry
resolution, and a local path is unpinned — six months later `prova init service` is silently
rendering whatever state that directory was left in, while everyone assumes it tracks the
registry. The field found this one the slow way: two engineers scaffolding "the same" archetype
and getting different repos. Incubate on a local path, register, delete the override.

## Nightly lanes

Some proofs should exist but not gate merges. The canonical case is **freshness**: this very
site's docs quote version numbers, and version numbers rot — at one point three different
documents named three different "current" versions, each drifting on its own schedule. The proof
is easy to write; the problem is that it hits the network, and *a docs build should not go red
because GitHub is slow*. The shape is a profile that selects its own proofs directory:

```toml
[run]
proofs = ["proofs"]           # the merge gate; never sees nightly/

[profiles.ci]
must_run = ["node", "pnpm"]   # what the merge gate guarantees

[profiles.nightly]
proofs   = ["nightly"]        # a directory-NAME pattern: selects exactly nightly/
must_run = ["gh"]
```

`proofs` is a directory-name pattern, so `["nightly"]` selects that directory and — because a
profile's `proofs` *replace* the base's — the default run never sees it. A scheduled workflow runs
`prova --profile nightly`, and rot surfaces as a red run the next morning instead of as a
reader's confusion months later.

The worked example, adapted from this site's own `nightly/` lane — every string that *claims* to
be current, asserted against the source of truth:

```lua
local latest = prova.fixture("latest-release", Scope.File, function()
  local r = shell.run({ "gh", "release", "view", "--repo", "prova-rs/prova",
    "--json", "tagName", "--jq", ".tagName" }, { check = true })
  return (r.stdout:gsub("%s+$", ""))
end)

prova.test("the install example names the current release",
  { requires = { "gh" } }, function(t)
  local body = fs.read(prova.root .. "/docs/getting-started/installation.md")
  t:expect(body:match("VERSION=(v%d+%.%d+%.%d+)"),
    "the download example tells a reader to install this exact version"):equals(t:use(latest))
end)
```

One discipline keeps the lane honest: only strings that claim to track the current release belong
in it. A pinned example (`prova-postgres@v0.2.0` in a docs snippet) is a fixed illustration —
asserting on it would assert that documentation never uses a stable example.

### Profile idioms worth stealing

- **`must_run` is the inverse of `requires`** — a test's `requires` skips when a capability is
  missing; a profile's [`must_run`](../reference/prova-toml.md#must_run) fails the run up front.
  Every lane should guarantee what its proofs gate on (`gh` above), or a runner that lost a
  capability skips the whole lane and reports green.
- **Guarantees belong to the profile that makes the promise.** `must_run` is *unioned* across
  profiles and can never be subtracted — and this site learned that the semantic way: `node` and
  `pnpm` were once guaranteed at `[run]` level, and the nightly job failed on the union, because
  the nightly lane only reads version strings and has no reason to own a toolchain. That failure
  is the rule working. A base guarantee must be true of *every* run the package can perform; a
  lane's guarantee goes on the lane.
- **Directory lanes compose with the rest.** The same shape carries any
  out-of-gate concern — `proofs = ["e2e"]` for a long-running end-to-end lane, each with its own
  `must_run`, its own schedule, and zero effect on `prova` at the developer's keyboard.
