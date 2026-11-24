---
sidebar_position: 4
---

# Reminders

A proof guards the past; a **reminder** watches the future. `prova.remind` states an obligation
whose trigger is a condition of the world and whose discharge is an act: an upstream cuts the
release you were waiting for, a dependency drifts past your pin, a backlog item passes its date.
`prova learn reminders` carries the same material in the binary.

```lua
prova.remind("stay current with prova-redis", {
  when = function(account)
    local latest = latest_tag("prova-rs/prova-redis")   -- plain Lua over shell, http, fs
    -- Falsy: WATCHING. Truthy: DUE, and a string becomes the report's "why".
    return semver_gt(latest, PINNED) and (latest .. " is out; we pin " .. PINNED)
  end,
}, "integrate the new release and bump [dependencies]")
```

- The **message is the instruction**: what to do when it fires. A reminder is discharged by an act,
  so nothing about it graduates.
- A **standing** reminder compares two observables, as above, and goes quiet once you act. A
  **one-shot** reminder ("v1 exists") stays due until you act and delete it. One rule covers both: a
  reminder is due whenever its condition holds.
- `requires = { "network" }` gates evaluation the way it gates a test, except that unmet means
  **UNEVALUATED**, never WATCHING: a watcher that could not look stays visibly disarmed.

## Two accounts, kept apart

A reminder looks like a test and is not one. It never enters the tally, the selection, the promise
surface or burndown. Fired reminders get their own section after the run headline, and a WATCHING
reminder is silence.

**A due reminder never fails a run by default**, because the world moving is not a defect in the
change under test. A lane whose job is keeping the project current opts in:

```toml
[profiles.maintenance]
heed = true                         # every DUE reminder fails this lane
# heed = ["deps", "currency"]       # or only reminders matching these names or tags
```

`--heed` does the same for one invocation (`--heed=deps` heeds a selection). Like `must_run`, `heed`
only tightens: the union of `[run]` and the profile wins. Give a reminder `tags = {...}` to make it
addressable by tag.

## Conditions over the run's own account

The condition receives this run's account, evaluated after the proofs:
`a.passed`, `a.failed`, `a.skipped`, `a.promised`, `a.owed`, `a.duration_ms`, this run's
`a.measurements[name]`, the banked `a.baselines[name]`, and `a.specs` (every claim and backlog
anchor with its properties). That makes common policies one line each:

```lua
-- the terminal item of a checklist: due exactly once, when deletion is all that is left
prova.remind("checklist complete", { when = function(a)
  return a.owed == 0 and a.failed == 0
end }, "delete this checklist")

-- the suite got slow compared with what was banked
prova.remind("suite runtime", { tags = { "perf" }, when = function(a)
  local banked = a.baselines["run.duration_ms"]
  return banked and a.duration_ms > banked * 1.5 and "50% slower than the banked run"
end }, "find what got slow before it becomes normal")
```

The account carries no reminder state, so reminders cannot observe reminders. Drawing down a backlog
by date is covered in [Backlog](../evidence/backlog.md#drawing-it-down).

## Reading them

```shell
prova reminders            # every declared reminder: DUE first, then WATCHING, then not yet evaluated
prova reminders --due      # only what is due; exits non-zero when anything is
prova reminders -k deps    # the usual selectors narrow it
```

`prova reminders` works before any run: it loads the declarations without executing anything and
overlays the state the last run recorded. Due reminders also appear in `prova owed`, and `prova
evidence` carries the counts. Prova is a runner, not a daemon, so a reminder is evaluated when a run
happens: give CI a scheduled run if you want the wall clock. Filtered runs (`-k`, `--promises`,
`--falsify`) do not re-evaluate, since a partial account would fire conditions early.
