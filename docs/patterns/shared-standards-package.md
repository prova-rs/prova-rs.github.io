---
sidebar_position: 1
---

# The Shared Standards Package

:::tip
To adopt an existing standards package rather than write one, follow [Adopt a Standards
Package](../guides/adopt-a-standards-package.md).
:::

Every organization has standards — the licence every repo must carry, the registry the build may
publish to, the metric prefix a service's telemetry must use. And in most organizations they live
in a wiki, which means they are enforced by whoever happens to look. **A standard nobody can run
is a wiki page.** This pattern turns each one into a `prova.test` in a single org-wide package —
call it `prova-acme-standards` — that every repository in the fleet consumes. A violation reads
like any other failure, a deliberate exception is a waiver with a reason in the repo, and raising
the bar for the whole fleet is one tag move. Three independent fleets converged on this shape.

## The layout

A standards package is an ordinary [dual-role package](../packages/authoring-packages.md#package-anatomy--one-manifest-two-hats):
`init.lua` exports the namespace, `library/` carries the LuaCATS stub, `proofs/` self-tests it,
and the manifest wears both hats — including the self-pin that makes the self-test honest:

```toml
[package]
name        = "standards"
description = "Acme project standards, as proofs"

[requires]
prova = ">= 0.16"

# Resolve THIS package from its own directory, so the self-tests `require("standards")`
# exactly as a consumer does. A consumer instead pins the released tag:
#   standards = "acme/prova-acme-standards@v1"
[dependencies]
standards = { path = "." }
```

Inside, each standard is one `rule{}` entry with a stable `id` (the waiver key — it never changes
once repos depend on it), a `title` (what broke), and a `why` — the sentence a person reads when
it fails. Write the *reason*, not a restatement: a rule without one gets waived by the first
person it inconveniences.

```lua
rule{
  id    = "cargo/publish",
  title = "the workspace publishes only to the private registry",
  why   = "the default is crates.io: a proprietary crate that omits this is one "
       .. "`cargo publish` away from being public, irreversibly",
  check = function(t, c)
    local publish = c.project.meta.publish
    t:expect(publish, "publish is a registry allow-list"):never():is_nil()
    t:expect(publish[1], "the only registry it may go to"):equals(c.cfg.registry)
  end,
}
```

Two structural rules the field settled on early:

- **The naming oracle.** One `standards.identity(spec)` function is the answer key for every
  derived name — image path, metric family prefix, release name. Nothing downstream restates a
  name; consumer proofs and code generators both call the oracle. Before this existed, a wrong
  metric prefix in one place quietly made every consumer proof assert the wrong family.
- **The contract as data.** Ports, paths, and metric families live in one table that both the
  proof suite and the org's generators read. When the suite and the scaffolding share a source,
  they cannot disagree about what compliant looks like.

## The self-test: prove what can be silently wrong

The package's own `proofs/` are hermetic — synthetic repositories built in a tempdir, no
toolchain, same result on a laptop and a bare runner. They prove the two things that can be
*silently* wrong: the oracle and the parsers. The live enforcement path is proven by every
consumer suite in the fleet, daily; what nothing downstream can prove is that a rule still has
teeth. So the discipline is falsifiability: **every rule runs against a compliant fixture and
against one broken in exactly one way.** As one org's self-test puts it: *a rule that cannot fail
is a comment with a green tick next to it.*

```lua
prova.test_each("{id} fails on {broke}", {
  { id = "repo/license-file", edits = { LICENSE = false },          broke = "no LICENSE" },
  { id = "cargo/publish",     edits = { ["Cargo.toml"] = NO_LIST }, broke = "the crates.io default" },
}, function(t, case)
  local r = run(case.id, repo(t, case.edits))   -- a synthetic repo, one violation
  t:expect(#r.failures, "the rule reported a violation"):gt(0)
end)
```

And the last line of the self-test is `standards.check{}` — exactly as a consumer writes it. The
package is subject to its own standards; it cannot demand a LICENSE it does not carry.

## Consuming it — as a dependency

A fleet repo opts in with one pin and one deliberately thin proof file. Everything generic lives
in the package; the proof file states only what is specific to *this* repo:

```lua
-- proofs/standards_test.lua — only what is specific to THIS repo: its name.
local standards = require("standards")

standards.check {
  binaries = { "ordersd" },
  except   = { ["cargo/edition"] = "pinned to 2021 until the FFI crate drops its requirement" },
}
```

`except` is the waiver mechanism: a rule skipped **with a reason**, keyed on the stable id,
reported as a skip in every run — visible debt, not a silent exemption. A bare id without a
reason is accepted and nagged about.

## Consuming it — as an external observer

Every entry point takes an optional target root, defaulting to the package it runs in:

```lua
function standards.check(opts)
  local root = (opts and opts.root) or prova.root
  ...
end
```

That one line is a seam: the suite need not live in the subject repository. A migration effort
can point the standards at a sibling checkout; a fleet-audit harness can render a repo into a
tempdir and hold it to the bar before it exists on the org's forge. Same rules, same reasons,
different vantage.

## The fleet ratchet

Consumers pin `standards = "acme/prova-acme-standards@v1"` — a **moving** major tag. Raising the
bar is: add the rule, prove it falsifiable, release, move `@v1`. The fleet answers on its next CI
run, each repo either passing or waiving with a reason. One wrinkle the field hit: tag pins are
[cached as immutable](../packages/using-packages.md#caching-and-freshness), which is exactly right
for `v1.2.0` and exactly wrong for a moving `@v1` — so the consumers' shared CI workflow passes
`-U` to force a refresh. Repos that want strict reproducibility pin the full version instead and
ratchet on their own schedule.

## Assert directives, not prose

Rules that match text in a manifest must strip comments first — and the package carries a proof
that they do. The failure this prevents is self-inflicted: the comment *explaining why* `@main`
is a forbidden pin must not fail the check it documents. The general rule: a standards check
asserts what a file *directs its tools to do*, never what its prose happens to mention.

## CI notes from the field

- **Run the self-test on `main` and on the incubation branch.** During a spec change, consumers
  temporarily pin the incubation branch — an unrun tip of that branch is six repos' CI broken at
  once.
- **Pin the engine version in the workflow** — per a standards rule of its own. The
  [run-action](../running-prova/ci-and-output.md#the-github-action)'s built-in default trails
  releases; a fleet's bar should not move because an action's default did.
- Each rule carries `proves = r.id .. " — " .. r.why`, so the design story ships with the test —
  the same [`proves` discipline](../writing-tests/promises-and-burndown.md) as any kept promise —
  and `tags` per profile, so `--tags` selection can run one slice of the bar.
