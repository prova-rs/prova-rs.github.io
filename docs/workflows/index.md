---
sidebar_position: 3
sidebar_label: "Workflows"
---

# Workflows

Prova meets you where you are. You can use it as a test runner for one throwaway Lua file, as
the discipline behind every change you ship, as an executable spec for work you haven't
started, or as the ledger that keeps a design doc, its proofs, and its CI runs from ever
drifting apart. Those are not four products — they are four depths of the same pool, and this
section is the ramp between them.

Each page below describes a **complete way of working**: a loop you can run every day and stop
at. None of them is a lesser version of the next — a bare test file with sharp black-box
assertions is a finished practice, not a compromise. But each workflow's ceiling is the next
one's floor: the habit you build at one depth is exactly the entry requirement of the one
after. Black-box assertions at the boundary are the whole discipline of the shallow end — and
the property that makes a proof-first change meaningful. Writing the proof before the
implementation is the everyday loop — and remove the deadline and it becomes a promise. A
promise discharges an obligation someone stated — and once obligations can come from prose,
your docs join the ledger too.

Enter wherever your situation puts you. Nothing requires visiting the shallower pages first —
each one names what it assumes and links back — and nothing at a shallower depth needs to be
unlearned later: the file you write in the first workflow is, unchanged, a valid proof in every
workflow after it.

## The map

| Workflow | Start here if | The loop |
|---|---|---|
| [Just Write Some Tests](./just-write-some-tests.md) | You want assertions on a script or a service *today* — no project, no concepts | write one file → `prova <file>` → read the tally |
| [The Proof-Driven Change](./the-proof-driven-change.md) | You are implementing a change right now | proof first (red) → implement → `--last-failed` → commit both together |
| [Spec-First: Promises & Burndown](./spec-first.md) | You can state the contract before the implementation exists | promise each behavior → `prova tests burndown` → graduate to `proves` |
| [Docs That Cannot Drift](./docs-that-cannot-drift.md) | Your design docs make promises someone has to keep | anchor a claim → cover it → `prova owed` → `prova attest` in CI |

**Just Write Some Tests** is the shallow end: one `*.prova.lua` file, `shell.run` and
`t:expect`, no manifest anywhere. It exists because the fastest way to learn what a proof feels
like is to write two of them in the next five minutes.

**The Proof-Driven Change** is the everyday loop — the workflow most changes live in. The proof
comes first and fails, the implementation makes it pass, and both land in one commit that CI
re-runs byte-identically. Done stops being a claim and becomes a proof that runs.

**Spec-First** points the same loop at work that hasn't started. A proof flagged
`promises = "reason"` is red by design and reports without breaking CI — the open work becomes
executable, and `prova tests burndown` becomes the implementing loop that empties it.

**Docs That Cannot Drift** closes the last gap: prose. A normative sentence in a design doc
gains a claim anchor, a proof covers it, and CI attests that the covering proof actually ran
and passed. Prose, open work, suite, and run stop being four artifacts that drift apart.

Everything on these pages is also in the binary itself — `prova learn pdd` is the one-screen
version of the middle of this ramp, rendered with your own package's facts. The pages here
carry what one screen cannot: the reasoning, the worked examples, and the links sideways into
[Writing Tests](../writing-tests/index.md) and [Evidence & Obligations](../evidence/index.md).

The ramp does not end at the deep end shown here: workflows arriving with upcoming releases
extend it further — quality lanes, and a fully agentic loop over the whole lifecycle.
