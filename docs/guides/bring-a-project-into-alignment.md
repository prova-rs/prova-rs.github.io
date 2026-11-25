---
sidebar_position: 4
---

# Bring a Project into Alignment

The previous guides started clean. A real codebase has history: hundreds of warnings, a few
`#![allow(warnings)]` that made them go away, `.unwrap()` in production paths, a file nobody wants
to open. Demanding all of that be fixed before the gate turns on means the gate never turns on.

The approach here is: measure the debt, freeze it so it cannot grow, record each exception with a
date, and pay it down on a schedule. The project is green on day one and cannot get worse on any
day after.

## 1. Retrofit without touching what exists

```shell
prova init rust-project
```

The retrofit keeps every file the project already has (README, `.gitignore`, `clippy.toml`, its
own `.config/nextest.toml`) and lists what it kept. Nothing about the project's own build changes.

## 2. Freeze the debt

```shell
prova run quality --update-baseline
```

On a legacy codebase the floors land wherever the project stands. If there are 31 production
`.unwrap()` calls today, the floor is 31: the 32nd is a red test, and the existing 31 are standing
debt with a number on it. Commit `.prova/baselines/` and the quality lane is green.

The clippy gate is different: it runs at `-D warnings`, so existing warnings make it red. If
`cargo clippy --fix` and a short cleanup clear them, do that. If there are too many for one change,
ratchet the count instead of the wall: replace `proofs/quality/clippy.prova.lua` with a proof that
counts warnings and holds the count to a floor.

```lua
-- proofs/quality/clippy.prova.lua — while legacy warnings are paid down. At zero, restore the
-- -D warnings wall from `prova init rust-project` and drop the cargo/clippy-gated waiver.
prova.test("clippy warnings do not grow", {
  switch = "quality",
  locks = { prova.writes("cargo") },
}, function(t)
  local r = shell.run(
    { "cargo", "clippy", "--workspace", "--all-targets", "--all-features", "--message-format=json" },
    { cwd = prova.root }
  )
  t:expect(r.code, "clippy ran to completion:\n" .. (r.stderr or "")):equals(0)
  local warnings = 0
  for line in (r.stdout or ""):gmatch("[^\n]+") do
    local ok, m = pcall(json.decode, line)
    if ok and type(m) == "table" and m.reason == "compiler-message"
      and m.message.level == "warning" and #m.message.spans > 0 then
      warnings = warnings + 1
    end
  end
  measure.ratchet(t, "rust.clippy.warnings", warnings, { set = "quality" })
end)
```

Re-run `prova run quality --update-baseline` to record the count. From then on, one more warning
fails the lane:

```text
  FAIL  clippy warnings do not grow
        ↳ rust.clippy.warnings regressed to 7 (baseline ceiling 5.0, lower is better)
```

Do not add `#![allow(warnings)]` to get the same green: the standards package fails on it, because
it makes the wall pass by not looking.

## 3. Adopt the standards and triage the red

Pin the standards package and add the proof file as in [Adopt a Standards
Package](./adopt-a-standards-package.md), then run `prova`. A legacy project typically shows
several failures. Sort them:

| Kind | Examples | Do |
|---|---|---|
| Minutes to fix | missing README, `target/` not ignored, a proof named `*_test.lua`, a branch-pinned dependency | fix now, in this change |
| One mechanical change | `cargo fmt` over the whole workspace, an edition bump | waive with an end date; land it as its own change so the reformat does not hide real edits |
| Real work | blanket `allow`s hiding many warnings; the clippy wall replaced by a ratchet in step 2 | waive with an owner and an end date; narrow them file by file |

```lua
require("project-standards").check {
  except = {
    ["cargo/formatted"]         = { why = "reformat lands as its own change, TICKET-101", owner = "jdoe", ends = "2026-12-15" },
    ["cargo/no-blanket-allows"] = { why = "src/legacy/ allows warnings; narrowing per module, TICKET-102", owner = "jdoe", ends = "2027-02-01" },
    ["cargo/clippy-gated"]      = { why = "warnings ratcheted (rust.clippy.warnings) until zero, TICKET-103", owner = "jdoe", ends = "2027-03-01" },
  },
}
```

The run is now green, and every exception is printed on every run with its reason and its date.

## 4. Watch it hold

Once aligned, regressions are mechanical:

A new warning fails the quality lane:

```text
  FAIL  clippy is clean (-D warnings, whole workspace)
          error: unused variable: `unused`
```

Silencing warnings wholesale fails the standards:

```text
    FAIL  no attribute switches off a whole lint group
              src/lib.rs:1: #![allow(warnings)]: expected 0, got 1
```

A new `.unwrap()` in production code moves the census past its floor and fails the lane. None of
these depend on a reviewer noticing.

## 5. Pay the debt down

Add a `goal` and a `deadline` beside a floor in `.prova/baselines/quality.json`:

```json
"rust.unwrap.production": { "value": 31, "direction": "lower_is_better", "goal": 15, "deadline": "2027-03-01" }
```

The lane stays green while the count is between the floor and the goal, and reports the gap.
Reaching the goal fails once, asking you to bank the gain with `--update-baseline`; missing the
deadline fails because the debt came due. Waivers work the same way: each one turns red on its end
date. [Ratchets](../quality/ratchets.md) has the details.

## 6. Gate it in CI

The retrofit rendered `.github/workflows/proofs.yaml`, which runs the `ci`, `quality` and `ut` lanes
through `prova-rs/run-action`. Add the standards proof to the default suite (it already is, in
`proofs/`) and every pull request is held to the same bar as `prova run all` on a laptop.

## Where to go next

- [Ratchets](../quality/ratchets.md) and [Lanes](../quality/lanes.md): the mechanics behind steps 2
  and 5.
- [The Shared Standards Package](../patterns/shared-standards-package.md): write or extend your
  organization's own rules.
- [Spec-First: Promises & Burndown](../workflows/spec-first.md): the same freeze-then-burn-down
  shape, applied to behavior instead of hygiene.
