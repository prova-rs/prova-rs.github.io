---
sidebar_position: 4.5
---

# Locks, Flakes & Reruns

Once a suite runs in parallel, beside other suites, other agents and CI on the same machine, three
questions follow: what may not run at the same time, what to make of a test that passes only
sometimes, and how to avoid paying for a whole run again. `prova learn locks` and `prova learn
running` carry the same material in the binary.

## Locks: house rules held across every prova instance

A **lock** is a named token a test holds while it runs, with readers-writer semantics:

```lua
prova.test("builds the workspace", { locks = { prova.writes("cargo") } }, function(t)
  t:expect(shell.run({ "cargo", "build" }).code):equals(0)
end)
```

| Spelling | Hold |
|---|---|
| `prova.writes(token)` | exclusive |
| `prova.reads(token)` | shared with other readers |
| `prova.port(N)` | an exclusive hold on a host port (machine-scoped) |
| `prova.reads(prova.port(5432))` | re-moding composes: a port widened to a shared hold |

Declare them on a test or a group; they flow down. The scheduler runs everything whose locks are
compatible and queues the rest. Locks are inert at `--jobs 1` and enforced above it, and they are
also **file locks** (`flock`) under the package's `var/`, so `-j 10`, a second agent's run and CI on
the same box all obey one rule. The kernel releases a crashed holder's lock instantly: no daemon and
no stale-lock cleanup.

The canonical rule: cargo, like most build tools, takes process-wide locks of its own, so two suites
that both call it contend unpredictably. `locks = { prova.writes("cargo") }` on every proof that
compiles is the whole fix, and `prova.reads("cargo")` on proofs that only read workspace metadata.

**Scope.** A lock is package-scoped by default: two unrelated repositories never collide on a token
name. `prova.writes("gpu", { scope = "machine" })` spans every repository on the machine; ports are
machine-scoped by default.

**Joining from outside.** The lock file is the contract, so any tool can take part:

```shell
prova lock cargo -- cargo build          # a writer hold while the command runs
prova lock db --reads -- ./report.sh     # a reader hold
prova locks --machine                    # who holds what right now, with pid and command
```

A queued hold says who it is waiting on, by name, and repeats that every 60 seconds. Every run banks
`run.lock_wait_ms`, the time stalled on another instance's lock, in the timings baseline. `serial =
true` is different: whole-run exclusivity for this run only. A rule that must bind other instances
is a lock.

## FLAKY is a verdict, not green

A test that **failed and passed on the same tree and the same prova** is FLAKY, whether that happened
across two runs of a lane, within a `--resume`, or by a deputy's own retry (nextest's
`<flakyFailure>`). Prova treats it as a concurrency defect, never as load and never as green:

- the tally prints `K FLAKY`, and a recap names each one with both runs and a line to reproduce it;
- `last-run.json` records `"verdict": "flaky"`, and a flaky proof attests nothing;
- every event is appended to `.prova/var/flakes.jsonl`, which no run truncates;
- the exit code is 1 by default; `--flakes=warn` reports without failing.

To reproduce one on purpose, `prova stress` runs each selected nextest case as N isolated copies,
each with its own short `TMPDIR` and process group, optionally beside CPU burners:

```shell
prova stress -E 'test(slot_watcher)' --copies 32 --burners 4
```

Build flags come from `[stress] nextest = [...]` in the manifest, so the copies are built exactly as
the gate builds them. Results go to `var/stress/<run>/summary.json`, and cases whose copies disagree
join the flake ledger.

## Not paying for the same run twice

```shell
prova run all --resume   # rerun only what the previous run of this lane did not pass
prova --reuse            # carry forward passes whose declared inputs are byte-identical
```

- **`--resume`** runs only what the previous run of this lane, over the identical tree, did not pass.
  It refuses, and says why, when the tree, prova or the lane changed.
- **`--reuse`** carries forward a prior pass of any test that declares `inputs = { … }` whose inputs,
  declaring file and prova version are byte-identical, even across trees.

Both record carried tests as `reused` with the run that executed them, never as `passed`, and a
failure always runs again. `--last-failed` remains the everyday iteration verb: exactly what was red
last time.

## Bounding time

| | |
|---|---|
| `timeout = "30s"` on a test | its wall clock |
| `idle_timeout = "60s"` on a test | a liveness bound: fails only when no assertion lands for that long |
| `--timeout <dur>` on the command line | caps every test in this run, overriding what each declares |

`idle_timeout` suits a proof that is legitimately slow, because it measures silence rather than
duration. Under `prova tests falsify` a liveness bound applies by default; see
[Falsifiers](../evidence/falsifiers.md#a-mutant-that-hangs-vacuous-hang).

## Throughput never changes meaning

`-j/--jobs N` only sets how many units may run at once. Flows stay serial, locks stay held, and
dependency edges stay ordered at any job count.
