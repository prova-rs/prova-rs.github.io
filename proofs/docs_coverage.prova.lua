--- What the docs teach, held to what the binary is.
---
--- Two kinds of item live here. The UNFLAGGED tests are standing guards: vocabulary and
--- consistency invariants the docs once violated (a whole section teaching the retired
--- `[plugins]` table, a section index silently omitting two of its own pages) — cheap greps
--- that keep those regressions impossible. The PROMISED tests are the coverage bar the docs
--- have not reached yet: whole feature layers of the binary (the evidence ledger, the
--- attention account, the quality account) with no pages. Each stays red — reported PROMISED,
--- never failing the build — until its section lands, then graduates to `proves` in the same
--- change. `prova promises` in this repo is the docs backlog.
---
--- Everything here is offline: fs + string matching, no network, no build. The nightly
--- freshness suite owns version strings; this file owns coverage and vocabulary.

local root = prova.root

--- Every docs page, once per run.
local pages = prova.fixture("docs-pages", Scope.File, function()
  local files = fs.glob(root .. "/docs", "**/*.md")
  table.sort(files)
  local out = {}
  for _, f in ipairs(files) do
    out[#out + 1] = { path = f:sub(#root + 2), body = fs.read(f) }
  end
  return out
end)

--- Repo-relative paths of every page whose body contains `needle` (plain find, no patterns).
local function containing(t, needle)
  local hits = {}
  for _, page in ipairs(t:use(pages)) do
    if page.body:find(needle, 1, true) then hits[#hits + 1] = page.path end
  end
  return hits
end

-- ── Standing guards ──────────────────────────────────────────────────────────────────────────

prova.test("no page teaches retired vocabulary", {
  proves = "the 0.16 package rename and the promises rename left ~30 pages stale; "
    .. "these strings are how the rot read",
}, function(t)
  -- Each needle is a spelling the binary no longer has. The exact strings matter: the
  -- GitHub Action's real `plugins:` input and `~/.cache/prova/plugins` path are still true
  -- and must not trip this, so the needles carry their distinguishing punctuation.
  local RETIRED = {
    { needle = "[plugins]",         was = "the [dependencies] table's old name" },
    { needle = "--plugin",          was = "the -P/--package flag's old name" },
    { needle = "prova plugin lint", was = "the package lint verb's old spelling" },
    { needle = 'spec = "',          was = "the promises flag's old spelling" },
    { needle = "--strict-specs",    was = "burndown's old primitive" },
    { needle = "prova-plugin.toml", was = "a separate package manifest that never shipped" },
    -- "backlog" now names the cold tier below a claim; promises are the executable SPEC.
    -- One word, one meaning — the PM/UI layer says "add this to our backlog" and must not
    -- collide with the promise vocabulary.
    { needle = "executable backlog", was = "the promise surface's old nickname" },
  }
  t:expect_all(function()
    for _, r in ipairs(RETIRED) do
      local hits = containing(t, r.needle)
      t:expect(#hits, r.needle .. " (" .. r.was .. ") survives in: "
        .. table.concat(hits, ", ")):equals(0)
    end
  end)
end)

prova.test("the packages section exists and the plugins section is gone", {
  proves = "everything is a package (0.16) — one vocabulary, one section",
}, function(t)
  t:expect(root .. "/docs/packages/index.md"):is_file()
  t:expect(root .. "/docs/plugins", "the old section directory lingers"):never():exists()
end)

prova.test("every writing-tests page is on its section's learning path", {
  proves = "the index once silently omitted two of its own pages — an index that lies "
    .. "about its own directory is worse than none",
}, function(t)
  local index = fs.read(root .. "/docs/writing-tests/index.md")
  local siblings = fs.glob(root .. "/docs/writing-tests", "*.md")
  t:expect_all(function()
    for _, f in ipairs(siblings) do
      local name = f:match("([^/]+)%.md$")
      if name ~= "index" then
        t:expect(index:find("(./" .. name .. ".md)", 1, true),
          "writing-tests/index.md does not link " .. name .. ".md"):never():is_nil()
      end
    end
  end)
end)

-- ── The coverage bar — the docs backlog, as promises ─────────────────────────────────────────

prova.test("the evidence ledger has its own section", {
  proves = "landed 2026-08-07: docs/evidence — the lifecycle, claims & covers, the run "
    .. "record & attestation, and falsifiers, each grounded in the binary's own semantics",
}, function(t)
  t:expect(root .. "/docs/evidence", "no Evidence section directory"):is_dir()
  t:expect_all(function()
    t:expect(#containing(t, 'covers = "'), "no page shows a covers binding"):gt(0)
    t:expect(#containing(t, "<!-- claim:"), "no page shows a claim anchor"):gt(0)
    t:expect(#containing(t, "prova owed"), "no page teaches the owed ledger"):gt(0)
    t:expect(#containing(t, "last-run.json"), "no page documents the run record"):gt(0)
    t:expect(#containing(t, "falsified_by"), "no page documents falsifiers"):gt(0)
  end)
end)

prova.test("the attention and quality accounts have their own section", {
  promises = "wave 3 (reminders, junit/sarif deputed verifiers, measurements/ratchets, "
    .. "lanes) ships with the next prova release — its section lands with it",
}, function(t)
  t:expect(root .. "/docs/quality", "no Quality section directory"):is_dir()
  t:expect_all(function()
    t:expect(#containing(t, "prova.remind"), "no page teaches reminders"):gt(0)
    t:expect(#containing(t, "junit.verify"), "no page teaches deputed verification"):gt(0)
    t:expect(#containing(t, "sarif.verify"), "no page teaches SARIF ingestion"):gt(0)
    t:expect(#containing(t, "measure.ratchet"), "no page teaches ratchets"):gt(0)
  end)
end)

prova.test("a reader can ramp from first test to the full practice", {
  proves = "landed 2026-08-07: docs/workflows (the four-depth ramp) and docs/patterns "
    .. "(the production-tested shapes) — both grow further with the next release's features",
}, function(t)
  t:expect(root .. "/docs/workflows", "no Workflows section"):is_dir()
  t:expect(root .. "/docs/patterns", "no Patterns section"):is_dir()
end)
