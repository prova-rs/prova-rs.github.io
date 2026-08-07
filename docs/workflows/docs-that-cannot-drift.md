---
sidebar_position: 4
---

# Docs That Cannot Drift

The deep end. Every workflow so far keeps the *suite* honest; this one keeps the **prose**
honest too. A design doc makes promises — "must", "never", "always" — and nothing in an
ordinary repo connects those sentences to the tests that supposedly back them. The doc drifts,
the suite drifts, and six months later nobody can say which sentences are still true. This
workflow makes that connection mechanical, with machinery that is all released today.

## The pieces

A normative sentence in a doc gains a **claim anchor** — an HTML comment, so the prose still
reads as prose ([Claims & Covers](../evidence/claims-and-covers.md#anchoring-a-claim)):

```markdown
<!-- claim: busy-not-absent -->
Contention and absence are different answers and must never be conflated.
```

The manifest opts the docs in
([the `[claims]` table](../evidence/claims-and-covers.md#opting-in--the-claims-table)):

```toml
[claims]
docs = ["docs/design", "README.md"]
```

A proof **covers** the claim — and where the exact wording *is* the contract, a
[pin](../evidence/claims-and-covers.md#pinning--catching-drift-that-stays-green)
(`#busy-not-absent@8c211392`, written by `prova owed --pin`) makes any edit to the sentence
report as STALE until someone re-accepts it:

```lua
prova.test("a saturated pool is never reported as unsatisfiable", {
  covers = "docs/design.md#busy-not-absent",
}, function(t) ... end)
```

**`prova owed`** is then the one what-is-owed question: unproven claims, dangling covers, open
promises, and stale pins in a single list, because an answer living in two places has one that
goes stale. And in CI, the [run record](../evidence/record-and-attest.md#the-record) plus a
bare **`prova attest`** close the last gap: attest fails on any claim whose covering proof was
skipped, deselected, red, still promised, or absent from the recorded run — because "0 failed"
is not evidence, and neither is a proof that never executed.

Where a claim guards an *absence* — no anonymous controls, no unencrypted field, nothing
logged at rest — add a [falsifier](../evidence/falsifiers.md): `prova falsify` applies the
declared mutation and a body that survives it is reported vacuous. An assertion that a bad
thing is absent is exactly the kind that can silently check nothing.

## The thread, worked once

Say the design doc for a placement broker gains a new sentence. The whole lifecycle, in order:

1. **Anchor it.** `<!-- claim: drain-not-preemption -->` above *"A drain must never be
   reported as a preemption."* The sentence is now an obligation; `prova owed` reports it
   UNPROVEN.
2. **Cover it — ahead of the implementation.** One proof, carrying both bindings:

   ```lua
   prova.test("draining a node reports drain, not preemption", {
     covers   = "docs/design.md#drain-not-preemption",
     promises = "broker v2: drains were indistinguishable from preemptions",
   }, function(t)
     ...
     t:expect(evt.reason):equals("drain")
     t:expect(evt.reason):never():equals("preemption")
   end)
   ```

   The claim is now bound and the work is on the open surface: `prova owed` shows it PROMISED.
3. **Burn it down.** `prova burndown` fails loud on the open promise; you implement; the
   promise is kept and the run demands graduation.
4. **Graduate in the same commit.** `promises` becomes
   `proves = "broker v2: drains were indistinguishable from preemptions"` — the reason
   survives as permanent context, and the proof now holds the line.
5. **Attest in CI.** The pipeline runs the suite, then gates on the account:

   ```yaml
   - run: prova --profile ci    # holds the line, and writes the run record
   - run: prova attest          # every claim evidenced by an executed, passing proof — or fail
   ```

   If a runner is ever missing the capability that proof needs, the proof skips — and `attest`
   withholds the attestation, because a proof that didn't run evidences nothing
   ([wiring the CI gate](../evidence/record-and-attest.md#wiring-the-ci-gate)).

From here on, every way this thread can rot is caught by name: delete the anchor and the
binding reports DANGLING; edit a pinned sentence and it reports STALE; skip the proof and
`attest` fails the pipeline. `prova evidence` reports the whole account at any time —
CLAIMED / BOUND / PROMISED / ATTESTED, then what is owed
([the question verbs](../evidence/index.md#the-question-verbs)).

## The payoff

Stated plainly: the doc, the open work, the suite, and the run stop being four artifacts that
drift apart. They become **one ledger with four views** — the prose says what must be true, the
promises say what is not yet, the proofs say what is, and the record says what was actually
demonstrated, this run, on this machine. Any sentence in the doc that matters is one
`prova attest <id>` away from a yes or a no; anything owed is one `prova owed` away from a
list. That is the deep end of the ramp as it stands today — and the mechanics of every piece
are covered in [Evidence & Obligations](../evidence/index.md).
