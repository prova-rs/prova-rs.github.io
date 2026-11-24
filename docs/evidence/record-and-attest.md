---
sidebar_position: 3
---

# The Run Record & Attestation

`0 failed` is the last thing an honest agent can say that is true and worthless. It is equally
true of a suite that proved everything and a suite in which every proof **skipped** for want of
a docker daemon, or was **deselected** by a narrow `-k`. The failure count answers "did anything
go red". Nobody was asking that — they were asking "is this covered", and that answer lives in
the negative space.

## The record

Every run writes a record of what happened — including what did *not*:

```text
.prova/var/last-run.json     # always; prova's own gitignored state
prova --record run.json      # ALSO here, for CI to keep as an artifact
```

It carries the counts, and then — individually, not summed — the paths behind the two outcomes
that mean *no evidence was produced*:

- **skipped** — reached a gate before the body (a `requires` capability unavailable, a failed
  dependency), with the gate's own words for why.
- **deselected** — never in the run at all (`-k`, `--tags`, `--node`, `--promises`,
  `--falsify`). Narrowing a selection is the cheapest way there is to report green having
  tested nothing.

The record is plain JSON and stable across runs, so a reviewer or a script reads it without
prova:

```bash
jq '.summary, (.skipped[] | .path)' .prova/var/last-run.json
```

## `prova attest` — the question `owed` cannot answer

[`prova owed`](./claims-and-covers.md) is static: it reconciles anchors against `covers`
bindings and reports that an obligation *has* a proof. Whether that proof ever **ran** is a fact
about a run — and that is what `attest` reads from the record:

```bash
prova                                          # produces the record
prova attest docs/design.md#drain-not-preemption
prova attest drain-not-preemption              # a unique bare id resolves too
```

```text
prova: attest docs/design.md#drain-not-preemption
  ↳ NOT attested — a drain is not a preemption did not execute in the recorded run
    (requires "placement_broker" ("placement_broker" is unavailable))
```

**Only an executed, passing proof attests.** Skipped, deselected, absent from the record, red,
still an open promise, or covered by nothing at all — every one of those is the absence of
evidence, and exiting `0` on "I found nothing to check" is the vacuous pass this whole ledger
refuses. Where several proofs cover one claim they are all obligations, not a menu: one skipped
sibling is enough to withhold the attestation.

Exit codes are CI-shaped: `1` when the obligation is not attested (a real finding), `2` for a
usage error (a broken pipeline is not a finding).

## Wiring the CI gate

```yaml
- run: prova --profile ci    # the suite holds the line, and writes the run record
- run: prova attest          # then: every claim evidenced, or exit non-zero
```

Bare `attest` gates **every** claim: it fails on any claim that is unbound, or whose covering
proof was skipped, deselected, red, still promised, or absent from the recorded run. A package
with no claims exits `0` and says so. Pair it with a profile whose
[`must_run`](../reference/prova-toml.md#must_run) guarantees the environment — the two close
different halves of the same hole ("we answered everything" reading identically to "we could
not ask anything").

`prova evidence` is the same account as a report instead of a gate — the counts, then what is
owed — safe on any machine, exit `0` always.

## What the record is not

- **Not signed.** The threat model is a careless agent, not a malicious one. An agent that
  would forge a record would equally write a falsifier that mutates nothing; a signature buys
  key management, not truth.
- **Not a gate.** Recording never changes a run's verdict, output, or exit code. Machinery that
  taxes the ordinary path is machinery people switch off.
- **Not a coverage metric.** It says what executed, not what was worth executing. Pair it with
  [falsifiers](./falsifiers.md) — a proof that ran and cannot fail is its own kind of nothing.
