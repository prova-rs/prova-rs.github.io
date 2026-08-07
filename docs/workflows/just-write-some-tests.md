---
sidebar_position: 1
---

# Just Write Some Tests

The shallow end. No manifest, no fixtures, no vocabulary to learn first — one file, a handful
of assertions, one command. If you have a script you don't quite trust or a service you want to
poke at repeatedly, this workflow is complete on its own, and you can be running it before your
coffee cools.

## One file, one command

Create a file matching `*.prova.lua`. Everything you need — `prova`, `shell`, `http`, `fs` —
is already in scope; there is nothing to import:

```lua
-- sanity.prova.lua

prova.test("the backup script exits clean and says what it did", function(t)
  local r = shell.run("./backup.sh --dry-run")
  t:expect(r.code):equals(0)
  t:expect(r.stdout):contains("would archive")
  t:expect(r.stderr):never():contains("error")
end)

prova.test("the staging service is up and reports healthy", function(t)
  local res = http.get("https://staging.internal.example/health")
  t:expect(res.status):equals(200)
  t:expect(res:json().status):equals("ok")
end)
```

Run it by path — explicit paths need no project at all:

```shell
prova sanity.prova.lua
```

```text
  PASS  the backup script exits clean and says what it did  (212ms, 3 assert)
  PASS  the staging service is up and reports healthy  (48ms, 2 assert)

2 passed, 0 failed, 0 skipped   in 261ms
```

That's the whole workflow. `shell.run` returns a result object where a non-zero exit is data to
assert on, not an error; `http.get` returns a response for *any* status code. The
[Quick Start](../getting-started/quick-start.md) walks this same shape line by line, and
[Assertions](../writing-tests/assertions.md) has the full matcher vocabulary when `contains`
and `equals` stop being enough.

When you're not sure what something returns, don't guess — probe it with a one-shot
[`prova eval`](../running-prova/command-line.md#probing-with-prova-eval) and then write the
assertion with confidence.

## When this is all you need

Plenty of real situations end here, and should:

- **A script's sanity checks.** A deploy script, a migration, a cron job — five assertions in
  one file catch the regressions that matter, and the file lives next to the script it guards.
- **A repo you don't own.** You can't add a test harness to a vendor's codebase, but nothing
  stops you from keeping a proof file that drives its CLI or API from outside.
- **A standing question.** "Is staging healthy, and does the seed data still look right?" as a
  file you run, instead of a checklist you follow.

You can pass a directory too — `prova checks/` discovers every test file under it — and the
usual [selection flags](../running-prova/command-line.md#run-a-subset) work unchanged, so even
a loose pile of files iterates with `prova checks/ --last-failed`.

## The one habit worth keeping

Even in the shallow end, one discipline pays for itself immediately: **assert at the boundary a
real caller would use**. Run the script the way an operator runs it; hit the endpoint the way a
client hits it. A green result then means the *system* works — not that an internal function
agreed with your mental model of it. Every deeper workflow on this ramp is built on that habit;
this is the place to acquire it, while the stakes are one file.

## The exit ramp

The moment you want setup and teardown — a temp directory, a container, a service booted before
the tests and torn down after — or the moment a second file wants to share state with the
first, you have outgrown bare files. That is what the manifest is for:

```shell
prova init project
```

scaffolds a `prova.toml` and a proofs directory, and a plain `prova` (no path) now runs the
declared suite from anywhere in the repo. [Your First Test
Suite](../getting-started/your-first-test-suite.md) grows exactly this file into that shape —
shared [fixtures](../writing-tests/fixtures.md), parallel execution — without discarding
anything you wrote here.

And when the file you're about to write is for a change you're implementing *right now*, write
the proof before the code: that's [The Proof-Driven Change](./the-proof-driven-change.md), the
next depth on this ramp.
