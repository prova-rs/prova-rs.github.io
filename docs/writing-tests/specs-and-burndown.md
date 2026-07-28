---
sidebar_position: 12
---

# Specs & Burndown

A **spec** is a proof written before the behavior exists. In proof-driven vocabulary, a proof not
yet honored *is* the specification — so the flag is named for what the thing **is**, not for its
state. There is no `pending`, no `todo`, no `skip("not implemented")`.

The point is that `git grep TODO` lies and `prova specs` cannot. A contract you can state but are
not implementing right now is still worth writing down executably.

```lua
prova.test("json.null encodes an explicit null", { spec = "api-freeze §1" }, function(t)
  t:expect(json.encode({ x = json.null })):equals('{"x":null}')
end)
```

The reason is **mandatory**. It carries the context while the proof is red, and it graduates into
`proves` later — so it is worth writing as a sentence, not a ticket number alone.

## The three states

Semantics are xfail-strict, per test:

| Body | Outcome | What it means |
|---|---|---|
| red | **`spec`** — its own outcome | Open work. CI stays green; every reporter names it (TAP `# TODO`, JUnit skipped + message, JSONL `"spec"`, console reason + first error line). |
| green | **FAILURE** | *"spec honored — convert the spec flag to `proves = "<reason>"` or remove it."* |
| unflagged | pass / fail | A full proof, holding the line immediately. |

That middle row is the mechanism, and it is worth sitting with: **a spec that starts passing
fails the run.** An implementation cannot land while still flagged `spec`, so graduation happens in
the same commit as the code that earned it. There is no drift window where a finished feature sits
behind a flag that quietly hides a later regression.

It also catches a subtler mistake — writing a "spec" for something that already works. The run
tells you immediately rather than leaving a permanently-green flag in the tree.

## `proves` — the context, kept

When a spec graduates, **prefer converting over deleting**:

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
- `spec` and `proves` never share a test.
- Invisible to `prova specs` — proven is not open.
- **Retrofitting is welcome.** Any existing test can gain a `proves` to capture the context behind
  it after the fact.

## Where the flags are legal

`spec` and `proves` are **test- and flow-level only**. On a group or in `suite.config` they are a
validation error — a group is a container, and flagging one would silently sweep in tests nobody
meant to flag.

`spec = false` is not a thing (an unflagged test is already a full proof), and neither is a bare
`spec = true` — the reason is the point.

## Driving the burndown

```shell
prova specs        # enumerate the open surface; empty means burndown complete
prova burndown     # run ONLY spec-flagged tests, open specs failing loud with full detail
```

`prova specs` is the executable backlog. `prova burndown` is the implementing loop: it inverts the
CI-friendly behavior so open specs report as real failures with their full error, which is what you
want while you are driving them green.

Both compose with [selection](../running-prova/command-line.md), so `prova burndown -k websocket`
narrows to one area. Underneath, the composable primitives are `--specs` (select only spec-flagged
tests) and `--strict-specs` (open specs count as failures); the verbs are the memorable spellings.

An empty surface under `burndown` means **complete** — exit `0`, not a selection error.

## When to write one

Whenever you can state a contract the system does not honor yet:

- A design doc or plan names behavior that is not implemented — encode it.
- You notice a gap mid-task that is out of scope. A spec files it *executably*, with the reason as
  the flag's value, instead of a comment that rots.
- A whole feature is being designed. Author the suite ahead as the definition of done, one spec per
  behavior, each carrying its own reason.

Prova nudges agents toward this by default; a package that is not run this way can opt out with
[`[agent] spec_first = false`](../reference/prova-toml.md#agent--how-prova-learn-addresses-an-agent).
