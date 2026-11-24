---
sidebar_position: 2
---

# Backlog

A defect surfaces mid-task, or a section of a design doc is worth shaping but not now. It should be
captured, in the document where it belongs, without becoming something the project owes today. A
**backlog** anchor does that. `prova learn backlog` carries the same material in the binary.

```markdown
<!-- backlog: flaky-teardown recorded=2026-11-24 -->
Teardown occasionally leaves a container behind; investigate.
```

Backlog and claim are the **two states of one prose obligation**: the same anchor shape, one keyword
apart, sharing one id namespace and the same [spec sources](./claims-and-covers.md#opting-in--spec-sources).

| | `<!-- claim: id -->` | `<!-- backlog: id -->` |
|---|---|---|
| In `prova owed` | yes, UNPROVEN until covered | no |
| Fails `prova attest` | when unbound or its proof did not run | never |
| Read by a bare `prova` run | no | no |
| A proof may `covers` it | yes | no: the ledger reports BACKLOGGED |

So a backlog item can sit inside a document that is being actively driven without adding anything to
what that document owes. The muting is the point.

## Capturing one

Write the anchor by hand, or let Prova do a verified write:

```shell
prova specs capture flaky-teardown "Teardown occasionally leaves a container behind." --file docs/design/runner.md
```

`capture` refuses a path no spec source scans and an id that already exists, stamps `recorded=` with
today's date, and rescans to prove the anchor landed. `--claim` writes a claim instead. Agents
connected over MCP use the `capture` tool, which is the same operation.

## Properties

After the id come `key=value` properties. Two are validated as ISO dates:

- `recorded=`: when the item was written down. The capture verb stamps it; put it on every anchor.
- `due=`: a hard external deadline.

Any other key is yours and passes through untouched (`owner=`, `area=`). Properties survive
promotion.

## Promoting one

Backlog is human-driven: nothing in the runtime moves a cold item across the line. When its time
comes, promotion flips the keyword in place.

```shell
prova specs --backlog                # the cold shelf
prova specs promote flaky-teardown   # now a claim: owed, and bindable
```

The id and the prose do not move, so the diff reads as exactly "this became active", and the address
a proof will name (`docs/design/runner.md#flaky-teardown`) is the one the reader already sees.
Demotion is deliberately not a verb: cooling a claim is safe only while nothing binds it, so edit the
anchor by hand when you know it is unbound.

The intended rhythm: burn down to green, open the backlog, pick a theme, and promote the few items
you are ready to take on. That stages the next burndown without owing anything before you choose it.
A green `prova owed` with a non-empty shelf prints a one-line pointer to it.

## Drawing it down

Backlog is data and a query; it enforces nothing on its own. A deadline is a
[reminder](../quality/reminders.md) over `account.specs`:

```lua
prova.remind("backlog-drawdown", { tags = { "backlog" }, when = function(a)
  local late = {}
  for _, o in ipairs(a.specs) do
    if o.kind == "backlog" and ((o.due and date.past(o.due))
      or (o.recorded and date.days_since(o.recorded) > 30)) then
      late[#late + 1] = o.address
    end
  end
  if #late > 0 then return #late .. " backlog item(s) owed attention" end
end }, "promote, remove, or reschedule (`prova specs --backlog`)")
```

It is WATCHING while every item is inside its window and DUE once one is not. A lane that heeds it
(`heed = ["backlog"]`) turns that into a gate. `prova specs --undated` lists items missing a
`recorded=` stamp, which this policy cannot age.
