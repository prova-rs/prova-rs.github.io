---
sidebar_position: 2
---

# The Proof-Driven Change

The everyday loop, for a change you are implementing *now*. In proof-driven development, "done"
is not a claim — it is a proof that runs. You don't tell your reviewer it works; you hand them
an executable proof that does, in the same commit as the code that earned it.

## The loop

1. **Write the proof first.** In a `*.prova.lua` file where the manifest points, state the new
   behavior as assertions at the system's boundary. Run it. **Red is correct at this stage** —
   a proof that passes before you implement proves nothing about your change.
2. **Probe unknowns with `prova eval`.** Not sure what a response looks like, what a module
   returns, what a container's URL will be? A one-shot snippet answers in seconds, in the same
   environment your tests get — no guessing, no throwaway test files.
3. **Implement.**
4. **Iterate with `prova --last-failed`** — re-run exactly what was red, nothing else — until
   the run is green.
5. **Commit proof and implementation together.** This is a *proof-carrying change*: the diff
   states the new bar and clears it in one motion, and the reviewer reads both at once.

Pushed, CI runs the **same suite, byte-identical** to your local run —
`uses: prova-rs/run-action@v1` installs the released binary and invokes the manifest exactly as
you did (see [The GitHub Action](../running-prova/ci-and-output.md#the-github-action)). There
is no translation step and no second harness to drift: the bar you set locally holds without
you.

```shell
prova eval 'return http.get(base .. "/orders/42").status'   # probe the unknown
# write the proof — run it — red, as it should be
prova --last-failed        # implement, re-run, repeat
prova                      # the whole suite, once, before you commit
```

## Never weaken a proof to pass it

Sooner or later a proof fails and the tempting fix is to adjust the assertion. Stop. A proof is
a bar someone set on purpose; quietly lowering it converts the suite from evidence into
decoration. If the bar genuinely seems wrong — the contract changed, the assertion was
over-specified — **renegotiate it** with whoever owns the contract, and let the diff show the
bar moving. The failure mode this forbids is the silent one: an assertion loosened at 5pm to
make a run green, indistinguishable in the report from a proof that still checks something.

## The right layer

Prova does not replace your language's own test harness — the two prove different things, and a
change often needs both. **Prove the contract with prova; prove the internals with the
language's own tests.** The tell is simple: *could a real caller observe the bug?*

| The thing to prove | Where it belongs |
|---|---|
| Behavior at the system boundary — API responses, CLI output, config taking effect, "it actually boots" | a prova proof |
| Pure logic: algorithms, edge cases, error paths of one function | the language's unit tests — the fast inner loop that refactors freely |
| Internal seams the boundary can't reach cheaply — concurrency, teardown-under-failure, storage invariants | the language's integration tests |
| The same behavior twice | pick **one** home — a proof re-checking a pinned unit case is noise; a unit test mocking what a proof observes for real is false confidence |

A typical proof-driven change carries both halves: a unit test pinning the tricky branch that
caused the bug, and a prova proof at the boundary that exposed it. The proof is what stops the
bug from ever being *observable* again; the unit test is what makes the next refactor fast.

## What makes it a proof, not just a test

The loop above only pays off if the artifact at its center has a few properties — worth
checking your proof against before you commit:

- **Black-box** — it drives the system where a caller would, so green means the system works.
- **Self-provisioning** — [fixtures](../writing-tests/fixtures.md) bring the system into
  existence and tear it down; the proof reproduces from nothing on any machine, including CI's.
- **Durable** — it lives with the system and re-runs on every future change, holding the bar
  long after you've forgotten setting it.

[Testing Real Systems](../writing-tests/testing-real-systems.md) shows the full shape —
render, provision, boot, probe — for a change whose proof needs real infrastructure.

## Where this loop opens out

Two situations stretch past this workflow, and each has its own page. If you can state the
contract but you're *not* implementing it yet, don't park it in a TODO — author the proof
anyway, flagged as a promise: that's [Spec-First](./spec-first.md). And if the contract lives
in a design doc that people are supposed to keep honoring, bind the proof to the prose itself:
that's [Docs That Cannot Drift](./docs-that-cannot-drift.md).

The binary carries this whole page as a screenful: `prova learn pdd`, rendered with your own
package's facts.
