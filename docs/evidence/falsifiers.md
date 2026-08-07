---
sidebar_position: 3
---

# Falsifiers

A proof that has only ever been green is not evidence. It may be checking the contract, or it
may be checking nothing — an assertion over a value that cannot vary, a rule whose subject the
implementation refuses in every case, a bar a stub already satisfies. Those read exactly like a
working proof: same color, same duration, same line in the report. The difference surfaces in
production, in the thing the suite swore was covered.

`falsified_by` makes the negative case declarable instead of remembered:

```lua
prova.test("no control is anonymous", {
  proves = "accessible and testable are the same property",
  falsified_by = function(t) fs.write(view, unlabelled_button(fs.read(view))) end,
}, function(t)
  t:expect(anonymous_controls(t)):is_empty()
end)
```

```bash
prova falsify      # select only tests declaring a mutation; apply it; INVERT the verdict
```

Red under mutation is the passing result — what is being proven is the body's **capacity to
fail**. A body that survives its falsifier is reported **vacuous** and fails the run:

```text
FAIL  two plus two
  ↳ vacuous — the body still passed with its falsifier applied, so it is not asserting what
    the mutation breaks. Sharpen the assertion, or fix the falsifier.
```

## The semantics

- **The verb is the selection**, exactly like `burndown`: a proof without a falsifier is not a
  failure (most never declare one) — it is simply not what this pass is about. `prova falsify`
  is `--falsify --allow-empty`, and the flag composes with any selection
  (`prova falsify -k rendering`).
- **A declared falsifier costs nothing on the ordinary path.** The mutation runs only under the
  verb that asks for it — because if a bare `prova` started perturbing systems, nobody would
  ever declare one.
- **A falsifier that raises is a failure of the *mutation***, not of the proof — otherwise a
  broken falsifier would masquerade as a body that correctly went red.
- `falsified_by` is **test-level only**, like `promises` and `proves`: a group or flow has no
  assertion of its own for a mutation to invalidate.

## When to reach for one

Falsifiers earn their keep where a proof asserts an **absence** — no anonymous control, no
leaked handle, no missing header — because absence is exactly what a broken or vacuous check
reports just as confidently as a working one. Reach for one when:

- a proof has **never been seen red** — it was written after the implementation, so the red →
  green transition never demonstrated it can discriminate;
- the thing under proof was implemented *after* the proof was written — a stub that refuses
  everything satisfies a great many carelessly-written assertions;
- the assertion guards a policy (a lint-like rule over rendered output, a security invariant)
  whose violation you can cheaply synthesize.

A good falsifier is the **smallest mutation that violates the contract** — write the broken
artifact, flip the header, register the unlabelled control — applied to a copy or fixture the
test already owns. It documents, executably, what "this proof is about" means.

## Where this fits

The [run record](./record-and-attest.md) tells you a proof executed; a falsifier tells you the
proof can *discriminate*. Together they close the two vacuity holes a green tally leaves open:
the proof that never ran, and the proof that ran but asserts nothing. Teams typically run
`prova falsify` as an occasional lane (a nightly, a pre-release check) rather than in the merge
gate — the mutations are real work, and the property they check drifts slowly.
