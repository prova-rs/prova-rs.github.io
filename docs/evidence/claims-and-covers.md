---
sidebar_position: 1
---

# Claims & Covers

Specs do not only come from prova. They come from design docs, READMEs, and tickets — and an
implementer (increasingly an agent) can say it implemented one without ever having done so.
Claims make that checkable: a sentence in prose becomes an obligation the ledger reconciles
against the suite.

## Anchoring a claim

A claim anchor is a deliberate act: *this sentence is normative and I intend it to be proven*.
It is an HTML comment, so prose carrying a machine-readable obligation still reads as prose:

```markdown
<!-- claim: busy-not-absent -->
Contention and absence are different answers and must never be conflated.
```

**Unanchored prose stays invisible.** Most prose is reasoning, not contract, and inferring
claims from unmarked text is how this pattern would turn into ritual and get routed around. Only
the sentences you anchor become obligations.

## Opting in — the `[claims]` table

```toml
[claims]
docs = ["docs/design", "README.md"]
```

Files and directories scanned for anchors, package-relative. **Absent by default**: no section
means no scan, no cost, and no lecture about a subsystem the package never asked for. Scanning
belongs to the query verbs — a bare `prova` does not parse markdown to run a test, and an
unproven claim never turns a green suite red.

## Binding a proof — `covers`

```lua
prova.test("a saturated pool is never reported as unsatisfiable", {
  covers = "docs/design.md#busy-not-absent",
}, function(t)
  -- drive the system at its boundary; assert the claim's contract
end)
```

The address is `<path>#<id>`, package-relative. One claim may be covered by several proofs —
they are then all obligations, not a menu (see [attestation](./record-and-attest.md)). A proof
authored before its implementation carries `covers` *and* [`promises`](../writing-tests/promises-and-burndown.md);
the binding is how the intake (a claim someone wrote) meets the open surface (a proof someone owes).

## What the ledger reports

`prova owed` reconciles anchors against bindings. The outcomes are reported, never fatal — with
one exception:

| Outcome | Meaning |
|---|---|
| **UNPROVEN** | An anchored claim nothing covers. The intake half: work someone scoped in prose. |
| **DANGLING** | A `covers` naming no anchor. Two situations produce this identical state — prose not written yet, and prose deleted once the proof captured the contract. Both are unfinished work; for the second, retire the claim's context into `proves` so deleting a design doc is lossless. |
| **STALE** | A *pinned* claim whose text changed since the pin (below). |
| **Duplicate id in one file** | An **error** — unlike the rest, this is a defect: an ambiguous address cannot be discharged by anything. |

External addresses (`jira:PROVA-142`) are opaque here — unresolvable is not unbound, and saying
otherwise would send an agent hunting for prose that was never local.

```text
$ prova owed
UNPROVEN  docs/design.md#never-preempt      docs/design.md:6 — no proof covers it
DANGLING  docs/design.md#not-written-yet
          contract_test › … covers it, but no anchor exists — write the prose, or
          retire the reference into `proves`
PROMISED  contract_test › leases expire     not built yet
```

## Pinning — catching drift that stays green

The nastiest drift keeps everything green: the anchor survives, its prose is edited, the proof
still passes — and now discharges a claim it no longer matches. Every id still resolves, so
nothing above sees it.

A **pin** records the claim's text in the binding:

```lua
covers = "docs/design.md#busy-not-absent@8c211392"
```

written for you by `prova owed --pin`. An edit to the anchored text is then reported **STALE**
until re-confirmed (re-run `--pin` to accept the new wording).

- **Opt-in per binding**, so you pin the claims whose exact wording *is* the contract and leave
  the rest loose.
- Whitespace is normalized before hashing — a pin that fired when someone reflowed a paragraph
  would be switched off within a week — but case and punctuation count, because "must" and "may"
  are the whole content of a normative claim.
- The pin lives in the proof source rather than a lockfile: in a diff it reads as *"this claim's
  text changed and someone re-accepted it"* — which is exactly the signal a reviewer wants.

## Where this fits

Claims are the **intake** side of the [lifecycle](./index.md): prose → obligation. The
[run record and `prova attest`](./record-and-attest.md) are the **discharge** side: obligation →
evidence that the covering proof actually ran. In between sits the ordinary authoring loop —
[promises](../writing-tests/promises-and-burndown.md) while the work is open, `proves` once it
lands.
