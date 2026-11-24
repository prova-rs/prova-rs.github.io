---
sidebar_position: 12
---

# Promises & Burndown

A **promise** is a proof written before the behavior exists. In proof-driven vocabulary, a proof
not yet kept *is* the specification — the test states, in its own voice, what it will prove
someday and does not prove today. There is no `pending`, no `todo`, no `skip("not implemented")`.

The point is that `git grep TODO` lies and `prova tests --promises` cannot. A contract you can state but
are not implementing right now is still worth writing down executably.

```lua
prova.test("json.null encodes an explicit null", { promises = "api-freeze §1" }, function(t)
  t:expect(json.encode({ x = json.null })):equals('{"x":null}')
end)
```

The reason is **mandatory**. It carries the context while the proof is red, and it graduates into
`proves` later — so it is worth writing as a sentence, not a ticket number alone.

## The three states

Semantics are xfail-strict, per test:

| Body | Outcome | What it means |
|---|---|---|
| red | **`PROMISED`** — its own outcome | Open work. CI stays green; every reporter names it (TAP `# TODO`, JUnit skipped + message, JSONL `"spec"`, console reason + first error line). |
| green | **FAILURE** | *"promise kept — change `promises` to `proves = "<reason>"` (keep the context) or remove the flag."* |
| unflagged | pass / fail | A full proof, holding the line immediately. |

That middle row is the mechanism, and it is worth sitting with: **a promise that starts passing
fails the run.** An implementation cannot land while still flagged, so graduation happens in the
same commit as the code that earned it. There is no drift window where a finished feature sits
behind a flag that quietly hides a later regression.

It also catches a subtler mistake — promising something that already works. The run tells you
immediately rather than leaving a permanently-green flag in the tree.

## `proves` — the kept promise

Graduation is a tense change: **`promises` → `proves`**. When a promise is kept, **prefer
converting over deleting**:

```lua
prova.test("json.null encodes an explicit null",
  { proves = "api-freeze §1: agents need a spellable null distinct from absent" }, function(t)
  t:expect(json.encode({ x = json.null })):equals('{"x":null}')
end)
```

The design story then lives next to the assertions it explains, read every time the test is
reviewed, instead of in a doc that can drift or a commit message nobody opens.

- `proves` is runtime-inert — the test is a full proof: pass is pass, fail is fail.
- Its value must be a non-empty string. A bare flag says nothing, which is the whole objection.
- `promises` and `proves` never share a test — open work keeps its context in the promise.
- Invisible to `prova tests --promises` — kept is not open.
- **Retrofitting is welcome.** Any existing test can gain a `proves` to capture the context behind
  it after the fact.

## Where the flags are legal

`promises` and `proves` are **test- and flow-level only**. On a group or in `suite.config` they
are a validation error — a group is a container, and flagging one would silently sweep in tests
nobody meant to flag.

`promises = false` is not a thing (an unflagged test is already a full proof), and neither is a
bare `promises = true` — the reason is the point.

## Driving the burndown

```shell
prova tests --promises   # enumerate the open surface; nothing runs, empty means burndown complete
prova tests burndown     # run ONLY promised tests, open promises failing loud with full detail
```

`prova tests --promises` is the executable spec's open surface. `prova tests burndown` is the implementing loop: promises
fall due — it inverts the CI-friendly behavior so open promises report as real failures with
their full error, which is what you want while you are driving them green.

Both compose with [selection](../running-prova/command-line.md), so `prova tests burndown -k websocket`
narrows to one area. Underneath, the composable primitives are `--promises` (select only promised
tests — it composes with `--list` and the rest of selection) and `--due` (promises fall due: open
ones count as failures). `prova tests burndown` is `--promises --due`; `prova tests --promises`
lists the same surface without running it.

An empty surface under `burndown` means **complete** — exit `0`, not a selection error.

## When to write one

Whenever you can state a contract the system does not honor yet:

- A design doc or plan names behavior that is not implemented — encode it.
- You notice a gap mid-task that is out of scope. A promise files it *executably*, with the
  reason as the flag's value, instead of a comment that rots.
- A whole feature is being designed. Author the suite ahead as the definition of done, one
  promise per behavior, each carrying its own reason.

Prova nudges agents toward this by default; a package that is not run this way can opt out with
[`[agent] spec_first = false`](../reference/prova-toml.md#agent--how-prova-learn-addresses-an-agent).
