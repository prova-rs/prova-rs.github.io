---
sidebar_position: 2
---

# Ratchets

Some quality is a number: line coverage, the count of `.unwrap()` calls in production code, the
number of functions past a length limit. A hard limit on a legacy project is a wall of red on day
one, and a dashboard is ignored by week two. A **ratchet** does neither. It measures the number,
compares it to a floor committed in the repository, and refuses any regression, while the existing
debt stands as a known quantity.

## The shape

```lua
prova.test("production .unwrap() count does not regress", {
  switch = "quality", locks = { prova.writes("cargo") },
}, function(t)
  local count = count_unwraps(t)   -- any Lua that produces a number
  measure.ratchet(t, "rust.unwrap.production", count, { set = "quality" })
end)
```

`measure.ratchet(t, name, value, opts)` records the value and asserts it against
`.prova/baselines/<set>.json`:

| Option | Meaning |
|---|---|
| `set` | the baseline file, `.prova/baselines/<set>.json` (default `default`) |
| `direction` | `"lower_is_better"` (the default: counts, sizes) or `"higher_is_better"` (coverage) |

The baseline is committed with the code, so it is reviewed like code:

```json
{
  "schema": 1,
  "metrics": {
    "rust.coverage.lines":     { "value": 75.5, "direction": "higher_is_better" },
    "rust.unwrap.production":  { "value": 2,    "direction": "lower_is_better" },
    "rust.functions.too_long": { "value": 0,    "direction": "lower_is_better" }
  }
}
```

A metric may also carry a `tolerance`, for a measurement with honest noise in it.
`measure.record(name, value, opts)` files a value without asserting anything, for numbers you want
in the run record but do not gate on.

## Moving the floor

```shell
prova run quality --update-baseline
```

`--update-baseline` moves each floor toward this run's measurement, and **only** toward better: it
tightens, and it refuses to loosen. Making a floor worse means editing the committed file by hand,
where a reviewer sees it. Reading a baseline happens anywhere; writing one goes through this one
guarded path, which is what keeps a ratchet from being gamed by whoever is in a hurry.

A metric with no floor passes nothing. The first run establishes the floors and reports red while
it does, because a gate that turns green before anything is measured has proven nothing. Run the
ritual once, commit the baselines, and the next run is the green ratchet.

## Goals: from standing debt to a burndown

A floor only stops things getting worse. To schedule a paydown, add a `goal`, and optionally a
`deadline`, beside the value:

```json
"rust.unwrap.production": { "value": 31, "direction": "lower_is_better", "goal": 15, "deadline": "2027-03-01" }
```

- While the value is between the floor and the goal, the run stays green and the gap is reported.
- **Reaching the goal fails the run**, asking you to bank the gain with `--update-baseline` and
  then retire or lower the goal. A target reached is a decision point, never a silent pass.
- Past the `deadline` with the goal unmet, the run fails: the debt came due.

## What you can ratchet

Anything that produces a number. The [Rust retrofit](./lanes.md#the-rust-retrofit) ships these:

| Metric | Measured by |
|---|---|
| Line coverage | `cargo llvm-cov nextest --json --summary-only`, direction higher-is-better |
| `.unwrap()` and `.expect()` in production code | clippy's `unwrap_used` and `expect_used` restriction lints over `--lib --bins`, so tests stay idiomatic |
| Functions past a length limit | `clippy::too_many_lines`, threshold in `clippy.toml` |
| Files past 1,500 lines | a line count over the source roots from `cargo metadata`, each offender named |
| Duplicated code | `jscpd` token-level clone count over production source (min 100 tokens) |

The pattern extends to any lint that has a threshold, such as `clippy::cognitive_complexity` for
method complexity: run clippy once in a file-scoped fixture with the lints enabled, count each
lint's diagnostics, and ratchet each count. Other ecosystems work the same way with their own
tools: an ESLint rule count, a `radon` complexity score, a bundle size.

Every run also banks `run.duration_ms` and `run.lock_wait_ms` in a `timings` baseline, so a
reminder can notice when the suite has become slower than it used to be.

## Exceptions are explicit

When a panic is the design (a build script with a missing cargo-provided variable, an invariant
where panicking beats a silent wrong answer), it leaves the count through a targeted
`#[allow(clippy::unwrap_used)]` on the item, with its argument in a comment. Never a blanket allow:
the floor keeps measuring the debt, not the design.

## A refusal points at a seam

A ratchet does not suggest; it refuses. When one goes red, the first question is what it is pointing
at, not how to get past it. In Prova's own development, `too_many_lines` firing twice produced two
functions that wanted names; the file-size limit split a test module out of a 1,600-line file; and
paying down the coverage floor with real tests found six defects nobody had reported, one of which
killed the whole runner. Rebaselining is available, and it is almost never the answer. When it is, the
reasoning goes in the commit.

## Next

- [Lanes](./lanes.md): put the quality gates behind `prova run quality` so a casual `prova` never
  recompiles the workspace.
