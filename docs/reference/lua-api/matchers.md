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
| `:matches_snapshot(opts?)` | string, path | The subject equals a stored `.snap` file colocated with the test. See [Snapshots](#matches_snapshot) below. |

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

## `matches_snapshot`

```lua
t:expect(subject):matches_snapshot()                      -- auto-named
t:expect(subject):matches_snapshot("greeting")            -- named
t:expect(tree):matches_snapshot{ level = "layout" }       -- options table
t:expect(tree):matches_snapshot{ name = "scaffold", level = "content" }
```

Compare the subject against a stored `.snap` file colocated with the test:
`<test-file-dir>/snapshots/<file-stem>__<key>.snap`. The `key` is a
filesystem-safe slug of the given name, or (unnamed) of the test's node path
plus a per-test counter (`<slug>-1`, `<slug>-2`, …) so several unnamed
snapshots in one test stay distinct. The argument is `nil`, a name string, or
an options table `{ name?, level? }`.

- **On a mismatch** the test fails with a line diff against the stored snapshot.
- **On a missing snapshot** the test fails after writing a reviewable
  `.snap.new` next to where the `.snap` would live — inspect it, then accept.
- **`prova -u` / `--update-snapshots`** (re)writes the `.snap` files instead of
  comparing (and clears any pending `.snap.new`). Review the diff like code.
- **`prova --unreferenced warn|delete`** reconciles `.snap` files no test
  referenced on a full run — see the [CLI reference](../cli.md#options).

The subject may be a **string** (compared as-is) or a **path handle** — a path
string or any table with a `path` field, such as `archetect.render` output. For
a directory subject, `level` selects how much is captured:

| `level` | Captures |
|---|---|
| `"layout"` | The sorted relative paths — the tree's *shape*. The default for a directory subject. |
| `"content"` | The paths **and** each file's bytes. Keep `content` snapshots narrow — broad ones rot. |

A stored `.snap` is a small reviewable document: a header naming the source
test, a `---` line, then the raw captured body. `matches_snapshot` cannot be
negated with `:never()` (that is an error), and it requires a test-file context
(it needs a source file to colocate the snapshot with).
