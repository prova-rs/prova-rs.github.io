---
sidebar_position: 10
---

# Data & Encoding

Small, dependency-free modules for the formats and identities that turn up between a proof and the
system it probes: parse a response body, build a fixture payload, sign a request, mint an id.
All are globals — no `require`, no capability, nothing to provision.

[`yaml`](yaml.md) is the sibling of these with a page of its own.

## `json`

```lua
json.decode(s)          --> any
json.encode(v, opts?)   --> string
json.array(t)           --> table   -- same table, marked as an array
json.null                           -- an explicit null
```

`json.decode` parses JSON into a Lua value. **`null` decodes to `nil`**, top-level or nested, so
absent and null read identically — which matters when the difference is the thing you are asserting.
To pin an explicit null, assert a shape containing `json.null` with
[`:matches`](../lua-api/matchers.md) rather than comparing the decoded value.

`json.encode` is compact by default. Two shapes need naming, because Lua cannot distinguish them:

- a bare empty table encodes as an **object** (`{}`); wrap it in `json.array` to force `[]`
- `json.null` emits an explicit null

```lua
json.encode({ x = json.null })        --> '{"x":null}'
json.encode(json.array({}))           --> '[]'
json.encode({})                       --> '{}'
```

## `toml`

```lua
toml.decode(s)   --> table
toml.encode(v)   --> string
```

Raises on invalid TOML. TOML has no null, so `json.null` is an **encode error** here rather than
being silently dropped — the same value being unrepresentable in one format and meaningful in
another is exactly the case worth failing loudly.

## `csv`

```lua
csv.decode(s, opts?)     --> table<string, string>[]
csv.encode(rows, opts?)  --> string
```

Header-aware in both directions. The first record names the columns; every remaining record becomes
a map keyed by header — the same row shape `prova.parse.table` produces, so tabular CLI output and
CSV files assert the same way.

**Values stay strings.** Decoding does not guess types, so a `"0042"` column stays `"0042"` and a
comparison against a number is a failure you can see rather than a coercion you cannot.

Encoding writes a header line and quotes per RFC 4180 automatically.

## `base64`

```lua
base64.encode(s)   --> string
base64.decode(s)   --> string
```

Standard alphabet, padded, binary-safe. `decode` raises on invalid input.

## `hash`

```lua
hash.sha256(s)              --> string   -- lowercase hex
hash.hmac_sha256(key, msg)  --> string   -- lowercase hex
```

For asserting content digests and for signing requests a system under test expects to be signed —
a webhook receiver verifying an HMAC header, say, where the proof has to produce a real signature
rather than a placeholder.

## `uuid`

```lua
uuid.v4()   --> string   -- hyphenated lowercase, RFC 4122
```

A fresh random id per call. Useful for making a fixture's records collision-proof across parallel
runs without coordinating names.

## `url`

```lua
url.parse(s)    --> UrlParts
url.encode(s)   --> string
```

`url.parse` splits a URL into structured parts and raises on an invalid one. `url.encode`
percent-encodes a single **component**: everything outside RFC 3986 unreserved characters is
escaped, and a space becomes `%20`, not `+`. Encoding a whole URL with it will escape the
separators too — that is a component encoder, by design.
