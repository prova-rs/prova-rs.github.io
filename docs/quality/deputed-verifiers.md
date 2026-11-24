---
sidebar_position: 1
---

# Deputed Verifiers

Prova does not replace a language's test framework. Unit tests stay with cargo, JUnit, pytest or
Jest; Prova **conducts** them and adopts their verdict into the same account as its black-box
proofs. `prova learn verifiers` and `prova learn reports` carry the same material in the binary.

The rule for choosing a layer: if a real caller could observe the bug, it deserves a proof; if only
the implementation can, it deserves a unit test. A change often needs both.

## JUnit XML: the seam for test frameworks

JUnit XML is what nearly every framework can emit: the JVM natively, `pytest --junitxml`,
gotestsum, cargo-nextest, Jest and Playwright reporters, .NET loggers. One tolerant parser lets
Prova adopt all of them.

```lua
prova.test("the service's own suite holds", { tags = { "unit" } }, function(t)
  junit.verify(t, { run = "mvn -q test", results = "target/surefire-reports/*.xml" })
end)
```

`junit.verify` does four things a hand-rolled wrapper usually gets wrong:

- It runs the deputy **tolerantly**: the exit code is not the verdict, the results are.
- It enforces **freshness**: a results file older than this run is refused, so a stale artifact
  never stands in for this run's evidence.
- It refuses **vacuity**: zero parsed cases fails, because a glob that matched nothing must not read
  as green.
- It fails with the **deputed cases' own names and messages**, so the red report names the unit
  test that broke.

`junit.load(pattern)` is the primitive underneath: it parses without running or recording, which
is what you want in `prova eval` or when another CI step produced the XML.

Deputed cases are not Prova nodes. The deputy owns selection and reruns; the conducting proof is the
node. Cases land in the run record with their provenance, and `prova attest junit:<suite>#<case>`
answers "did this upstream case actually run and pass?" with one exit code.

### Conduct once, read many: cargo nextest

Compiling a Rust workspace is expensive, so the `ut` lane runs `cargo nextest` once in a
file-scoped fixture and lets every proof in the file read the same junit artifact:

```lua
local deputy = prova.fixture("nextest-junit", Scope.File, function()
  local artifact = prova.root .. "/target/nextest/prova/junit.xml"
  fs.remove_all(artifact)   -- a deputy that dies before emitting leaves nothing to misread
  shell.run({ "cargo", "nextest", "run", "--workspace", "--profile", "prova",
    "--tool-config-file", "prova:" .. prova.root .. "/.prova/nextest.toml" },
    { cwd = prova.root, merge_stderr = true, timeout = "1800s" })
  return artifact
end)

prova.test("the workspace's unit tests pass", { switch = "ut", locks = { prova.writes("cargo") } },
function(t)
  junit.verify(t, { results = t:use(deputy) })
end)
```

Because the artifact is shared, a second proof can bind a [claim](../evidence/claims-and-covers.md)
to one named unit test without compiling anything again:

```lua
prova.test("unterminated input is rejected", {
  covers = "docs/parser.md#rejects-unterminated",
  requires = { "cargo-nextest" },
}, function(t)
  for _, c in ipairs(junit.load(t:use(deputy)).cases) do
    if c.name == "parser::tests::rejects_unterminated_input" then
      return t:expect(c.outcome, c.name):equals("passed")
    end
  end
  t:expect(false, "the unit test is missing from the account"):is_true()
end)
```

The junit-emitting nextest profile ships as *tool* config, so it composes under the project's own
`.config/nextest.toml` instead of competing with it. A case nextest retried and then passed is
reported **FLAKY**, never green.

## SARIF: the seam for linters

SARIF is to static-analysis findings what JUnit is to test results: clippy, ESLint and many other
linters emit it, and GitHub code scanning consumes it.

```lua
prova.test("eslint is clean", { tags = { "lint" } }, function(t)
  sarif.verify(t, {
    run = "npx eslint . --format @microsoft/eslint-formatter-sarif -o eslint.sarif",
    results = "eslint.sarif",
    level = "warning",   -- fail on warnings and errors (default: "error")
    max = 0,             -- findings tolerated at or above that level
  })
end)
```

`sarif.verify` follows the same shape as `junit.verify`: a tolerant run, freshness enforced,
findings recorded with their provenance, and a failure that lists each finding's rule, file and line.
The one difference is deliberate: **zero findings is a clean pass**, so there is no vacuity guard.
`sarif.load` and `sarif.ingest` are the primitives.

## Kept reports

A deputy usually produces an artifact a person wants to open: an HTML coverage report, the junit
file with every case's detail. Left under `target/`, it is swept by the next build, and a ratchet that
refuses a coverage drop cannot show which lines moved. `report.publish` takes custody of it:

```lua
report.publish{
  name = "coverage",                        -- the address: `prova reports coverage`
  summary = "unit 73.5% · merged 86.4%",    -- the gist, readable without opening anything
  explains = "rust.coverage.unit",          -- the measurement this is evidence for
  forms = { json = json_path, html = html_dir .. "/index.html" },
}
```

The files are copied into `.prova/var/reports/<name>/` immediately. Each form is a rendering of the
same fact: an agent reads the `json`, a person opens the `html`.

```shell
prova reports                        # what exists, each summary and its forms
prova reports coverage --kind json   # that one path alone, for $(…)
prova reports -c                     # pick one from a menu and open it (terminals only)
```

Prova never renders an artifact; the deputy already did. It keeps it, summarizes it in one line, and
makes it addressable.

## Every conduct dies as a tree

Each conduct runs in its own process group, so a timeout or `proc:stop()` kills the whole tree: a
pipeline's grandchildren cannot outlive the red report. If you see a `prova reap` process, it is the
run's janitor. It holds a pipe the kernel closes when the spawning `prova` dies, by Ctrl-C or
`kill -9`, and then sweeps any conduct still running.

## Next

- [Ratchets](./ratchets.md): what to do with the measurements a deputy produces.
- [Lanes](./lanes.md): giving the unit-test leg its own command, `prova run ut`.
