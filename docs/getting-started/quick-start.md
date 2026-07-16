---
sidebar_position: 4
---

# Quick Start

Write one file, run it, read the output. Five minutes, no project setup.

## 1. Write a test file

Create `hello_test.lua`. The name matters: Prova discovers files matching `*_test.lua` (or `*.test.lua`). Everything you need — `prova`, `shell`, `fs` — is already in scope:

```lua
-- hello_test.lua

prova.test("echo prints a greeting", function(t)
  local r = shell.run("echo hello prova")
  t:expect(r.code):equals(0)
  t:expect(r.stdout):contains("hello prova")
end)

prova.test("a failing command reports a non-zero exit", function(t)
  local r = shell.run("test -f does-not-exist.txt")
  t:expect(r.code):never():equals(0)
  t:expect(r:ok()):is_false()
end)
```

Two things to notice:

- `shell.run` returns a result object — `r.code`, `r.stdout`, `r.stderr`, `r.duration`, and `r:ok()`. A non-zero exit is *data to assert on*, not an error (pass `check = true` if you want non-zero to raise instead).
- `t:expect(subject)` starts a fluent assertion; `:never()` negates the matcher that follows.

## 2. Run it

```shell
prova hello_test.lua
```

You can also pass a directory (`prova .`) and Prova will discover every test file under it.

## 3. Read the output

```text
  PASS  echo prints a greeting  (9.8ms, 2 assert)
  PASS  a failing command reports a non-zero exit  (7.1ms, 2 assert)

2 passed, 0 failed, 0 skipped   in 17.4ms
```

Each line is one test: its outcome (`PASS`/`FAIL`/`SKIP`), its name, how long it took, and **how many assertions actually executed** — a test that asserted nothing is visible at a glance. The footer tallies the run.

When a test fails, the assertion's message is printed right under it:

```text
  FAIL  echo prints a greeting  (10.2ms, 2 assert)
          ↳ expected "hello\n" to contain "hello prova"

1 passed, 1 failed, 0 skipped   in 18.0ms
```

The exit code tells CI everything it needs: `0` when all tests pass, `1` when any fail, `2` for usage or harness errors (no files found, bad flag, broken manifest).

:::note Planned
Selecting tests by name (`-k`) and by tag expression is planned. Today, select what runs by pointing `prova` at files and directories. See the [Roadmap](../reference/roadmap.md).
:::

## Next steps

- Grow this into a real project — `prova init`, shared fixtures, parallel execution — in [Your First Test Suite](./your-first-test-suite.md).
- See every flag and exit code in the [CLI reference](../reference/cli.md).
- Explore the full assertion vocabulary in [Assertions](../writing-tests/assertions.md).
