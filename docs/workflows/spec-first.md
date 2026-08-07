---
sidebar_position: 3
---

# Spec-First: Promises & Burndown

[The proof-driven change](./the-proof-driven-change.md) assumes you implement the moment you
write the proof. This workflow drops that assumption: you can state a contract long before
anyone builds it, and a contract you can state is worth writing down *executably*. A proof
authored ahead of its implementation is a **promise** — red by design, reported distinctly, and
impossible to forget, because the runner itself carries it forward.

## State the contract as promises

One promise per behavior, each flagged `promises = "reason"` — the reason is **mandatory**, and
it should be a sentence worth keeping, because it graduates into the proof's permanent context
later:

```lua
prova.test("json.null encodes an explicit null", { promises = "api-freeze §1" }, function(t)
  t:expect(json.encode({ x = json.null })):equals('{"x":null}')
end)

prova.test("absent keys are omitted, not nulled", { promises = "api-freeze §1" }, function(t)
  t:expect(json.encode({ x = nil })):equals('{}')
end)
```

An open promise (body red) reports as the distinct `PROMISED` outcome — CI stays green, every
reporter names it. An unflagged test holds the line immediately. The full semantics — including
why a promise that *starts passing* fails the run — are in
[Promises & Burndown](../writing-tests/promises-and-burndown.md#the-three-states).

## The spec you cannot lose

```shell
prova promises     # enumerate the open surface; nothing runs
```

This is the executable spec — and it cannot go stale. `git grep TODO` lies — comments rot, move, and describe work
nobody scoped — but `prova promises` cannot: every line on it is a real contract, stated as
assertions, carrying its own reason, and checked by the same binary that runs the suite. When
the list is empty, the work is *done*, in the only sense that survives contact with a reviewer.

This also changes what you do with gaps you notice mid-task. Out of scope? Don't leave a TODO
comment — file the gap as a promise, with the ticket or reason as the flag's value. It costs
one test's worth of writing now, and it turns "someone should handle this someday" into a line
on a list the runner re-presents until someone does.

## The implementing loop

```shell
prova burndown     # promises fall due: open ones fail LOUD, with full detail
  # ...implement...
prova burndown     # each promise you satisfy now fails as "promise kept" — graduate it
prova promises     # empty ⇒ burndown complete
```

`prova burndown` inverts the CI-friendly behavior: open promises report as real failures with
their full error, which is exactly what you want while driving them green. It composes with
[selection](../running-prova/command-line.md#run-a-subset), so `prova burndown -k encode`
narrows to one area.

Graduation is a tense change, and it happens **in the same commit as the implementation**: a
kept promise fails the run until you change `promises = "reason"` to `proves = "reason"` (keep
the context) or remove the flag. An implementation cannot land still flagged, so there is no
drift window where a finished feature hides behind a flag that would swallow a later
regression. Prefer converting over deleting — the design story stays in the test, next to the
assertions it explains
([the kept promise](../writing-tests/promises-and-burndown.md#proves--the-kept-promise)).

## A feature's suite as the definition of done

Scale this up and it becomes a way to design. When a whole feature is being planned, author its
suite ahead: one promise per behavior in the design, each carrying its reason. That suite *is*
the definition of done — not a prose checklist someone interprets, but a bar the implementation
either clears or doesn't. Scope disputes surface at authoring time, while they're cheap: a
behavior you can't state as a promise is a behavior you haven't actually designed.

## The hand-off shape

This is also how work changes hands cleanly — between teammates, and especially from a team to
an implementing agent. The promises **are** the assignment: the agent runs `prova promises` to
see what is owed, `prova burndown` to drive it, and graduates each flag in the commit that
keeps it. Nothing about the intent travels out-of-band — the reasons are in the flags, the
contracts are in the assertions, and "finished" is a fact (`prova promises` prints nothing)
rather than a report. The same suite, flags graduated, then holds the line in CI via the
[run-action](../running-prova/ci-and-output.md#the-github-action) — the bar the designer set is
the bar the reviewer checks, verbatim.

One depth remains on the ramp: promises answer for contracts stated *in the suite*, but design
docs make promises too, and prose can drift away from the proofs that once matched it. Binding
the two together is [Docs That Cannot Drift](./docs-that-cannot-drift.md).
