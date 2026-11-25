---
sidebar_position: 3
---

# Adopt a Standards Package

A retrofit gives one project its lanes. A **standards package** keeps every project's lanes wired
and holds them all to one bar: the prova version floor, the proof file naming, pinned
dependencies, no blanket `allow`s, a formatted workspace. Each standard is a test with a reason, so
a violation reads like any other failure, and raising the bar for the whole organization is one
release.

This guide adopts an existing package. To write your own, see [The Shared Standards
Package](../patterns/shared-standards-package.md); a working starting point to fork is
[p6m-run/prova-project-standards](https://github.com/p6m-run/prova-project-standards), which this
guide uses as its example.

## 1. Pin the package

Add it to the manifest (`.prova/prova.toml` after a retrofit):

```toml
[dependencies]
project-standards = { git = "https://github.com/p6m-run/prova-project-standards", tag = "v1" }
```

`v1` is a floating major tag. When the package releases a new rule, the tag moves and your project
is held to it on its next resolve; a breaking change would be a deliberate move to `v2`.

## 2. Add one proof file

```lua
-- proofs/standards.prova.lua
require("project-standards").check {}
```

That is the whole adoption. The package detects which profiles apply from what is on disk: a
repository with a `Cargo.toml` gets the cargo rules, one without does not.

## 3. Run it and read the result

```shell
prova
```

On the `greeter` project from [Bootstrap a Project](./bootstrap-a-project.md), before its README
existed and before the baselines were recorded:

```text
  project standards
    FAIL  the repository carries a non-empty README.md
    PASS  the repository carries a .gitignore
    PASS  the project has a prova manifest
    PASS  the suite declares the prova it needs, at or above the org floor
    PASS  the manifest uses no retired prova surface
    PASS  proof files are named `*.prova.lua`
    PASS  git dependencies are pinned to a released tag
    PASS  the suite has a CI profile that states what the runner guarantees
    PASS  every crate is on a current Rust edition
    SKIP  a virtual workspace pins its feature resolver  — not a virtual workspace
    PASS  the build directory is ignored
    PASS  the suite declares the standard quality legs
    PASS  a proof holds clippy to -D warnings
    PASS  no attribute switches off a whole lint group
    FAIL  the quality ratchet has a committed floor
    PASS  the workspace is formatted (cargo fmt --check)
```

Each failure leads with the rule's id and the reason it exists, then what was found:

```text
    FAIL  the repository carries a non-empty README.md
          ↳ repo/readme — the first question about any repository is what it is, and the answer
            belongs where every tool already looks
            README.md at the project root: expected ".../greeter/README.md" to be a file
```

Write the README, run `prova run quality --update-baseline`, and the next `prova` is green.

## 4. Record exceptions as waivers

When a rule cannot be met yet, waive it in the proof file with a reason. Give it an owner and an
end date:

```lua
require("project-standards").check {
  except = {
    ["cargo/formatted"] = { why = "one-time reformat lands with TICKET-1234", owner = "jdoe", ends = "2026-12-31" },
  },
}
```

A waived rule reports as a skip with its reason on every run, so the debt stays visible. When the
end date passes, the rule turns red again: fix it, or renew the waiver with a new date and a reason
a reviewer can read.

## 5. Keep up with the bar

- `prova --tags standards` runs only the standards; `--tags static` runs the ones that never
  compile.
- Tag pins are cached as immutable. When the package moves `v1`, refresh with `prova -U` (CI that
  should always see the newest bar passes `-U` too).
- A new rule arrives as a new red line with its reason, on the next run, in every adopting
  repository at once.

## Next

[Bring a Project into Alignment](./bring-a-project-into-alignment.md): the same steps on a
codebase that already has years of warnings in it.
