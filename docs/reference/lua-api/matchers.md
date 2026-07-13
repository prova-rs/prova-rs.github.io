---
sidebar_position: 3
sidebar_label: "Matchers"
---

# Matchers

`t:expect(subject, label?)` returns a matcher; calling any matcher method
performs one assertion. By default a failed assertion fails the test
immediately; inside [`t:expect_all`](./context.md#texpect_all) failures are
collected instead. Every matcher call — pass or fail — increments the test's
assertion count in the report.

```lua
t:expect(r.code):equals(0)
t:expect(r.stdout):contains("Compiling")
t:expect(r.stdout):matches("Finished .+ in %d")
t:expect(out.path .. "/Cargo.toml"):exists()
t:expect(res.status):is_one_of({ 200, 204 })
t:expect(body):never():contains("secret")
```

## Matcher table

| Matcher | Subject | Passes when ... |
|---|---|---|
| `:equals(x)` / `:eq(x)` | any | Deep structural equality with `x`: recurses into tables (same key set, values recursively equal); integers and floats compare numerically; strings byte-wise. |
| `:is(x)` | any | Identity: the *same* table/function/userdata by reference, or an equal primitive. Use over `equals` when you mean "the same object" — including tables with function fields, which deep equality cannot compare. |
| `:is_truthy()` | any | Lua truthiness — anything but `nil` and `false`. |
| `:is_falsy()` | any | `nil` or `false`. |
| `:is_true()` | any | Strictly the boolean `true`. |
| `:is_false()` | any | Strictly the boolean `false`. |
| `:is_nil()` | any | The value is `nil`. |
| `:contains(x)` | string, table | Strings: `x` is a substring. Tables: some value in the table deep-equals `x` (any key shape). Other subjects fail. |
| `:matches(pattern)` | string | Lua-pattern match (via `string.find`). A non-string subject fails. |
| `:has_length(n)` | string, table | Strings: byte length (Lua `#`) equals `n`. Tables: sequence length equals `n`. Other subjects fail. |
| `:is_one_of(options)` | any | The subject deep-equals some element of the `options` sequence. |
| `:gt(n)` / `:gte(n)` / `:lt(n)` / `:lte(n)` | number | Numeric comparison. A non-numeric subject fails. |
| `:exists()` | path | The path exists on disk. |
| `:is_file()` | path | The path is a regular file. |
| `:is_dir()` | path | The path is a directory. |
| `:is_empty()` | path | An existing directory with no entries, or a zero-byte file. A missing path (or non-path subject) fails. |
| `:is_fully_rendered()` | path | No leftover template markers — `{{`, `{%`, or `{#` — in any file's contents or path segments under the subject. GitHub Actions `${{ ... }}` expressions are excluded; binary/unreadable files are skipped; a missing path fails. Failure lists each offender as `relpath:line: snippet` (up to 10, then a count). The signature archetype check. |

**Path subjects.** The filesystem matchers accept a path **string**, or a table
handle carrying a `path` field — such as the tree handle returned by
`archetect.render{...}`.

## Negation — `:never()`

```lua
t:expect(out.path .. "/target"):never():exists()
```

`:never()` returns a negated matcher: the following check passes when the
underlying check would fail. Negated failure messages are prefixed with `not:`.
Calling `:never()` twice negates twice.

## Labels

The optional second argument to `expect` names the subject in the failure
message:

```lua
t:expect(order.id, "order id"):is_truthy()
-- on failure: order id: expected a truthy value, got nil
```

## Soft assertions

Inside `t:expect_all(function() ... end)`, failed matcher calls do not abort;
they are collected and reported together when the block ends. See
[`t:expect_all`](./context.md#texpect_all).

:::note Planned
`:matches_snapshot(name?)` and `--update-snapshots` are not yet implemented. Read
files with `fs` and assert with `:equals()` / `:contains()` / `:matches()`
instead. See the [Roadmap](../roadmap.md).
:::
