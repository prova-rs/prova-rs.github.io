--- What the docs teach, held to what the binary is.
---
--- Two kinds of item live here. The UNFLAGGED tests are standing guards: vocabulary and
--- consistency invariants the docs once violated (a whole section teaching the retired
--- `[plugins]` table, a section index silently omitting two of its own pages) — cheap greps
--- that keep those regressions impossible. The PROMISED tests are the coverage bar the docs
--- have not reached yet: whole feature layers of the binary (the evidence ledger, the
--- attention account, the quality account) with no pages. Each stays red — reported PROMISED,
--- never failing the build — until its section lands, then graduates to `proves` in the same
--- change. `prova tests --promises` in this repo is the docs backlog, and `prova tests burndown`
--- is the loop that empties it.
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
  proves = "the 0.16 package rename, the promises rename, and the 0.2x lane verbs each left "
    .. "pages stale; these strings are how the rot read",
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
    -- 0.2x: a state is a flag on its lane. The old top-level verbs print their replacement and
    -- exit; `prova watch` was removed outright (2026-08-25), so it now reads as a path.
    { needle = "prova promises",    was = "`prova tests --promises`" },
    { needle = "prova burndown",    was = "`prova tests burndown`" },
    { needle = "prova falsify",     was = "`prova tests falsify`" },
    { needle = "prova list ",       was = "`prova tests`" },
    { needle = "prova watch",       was = "a verb removed in 2026-08" },
    { needle = "`watch`",           was = "the removed verb, in a list of verbs" },
    -- `[claims]` became `[specs]`, and `docs = [...]` became `[[specs.source]]` (prova learn spec).
    { needle = "[claims]\ndocs",    was = "the `[[specs.source]]` table" },
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
  proves = "landed 2026-11-24: docs/quality — deputed verifiers, ratchets, lanes and "
    .. "reminders, against v0.30",
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

-- ── The v0.30 currency plan (2026-11-24) ─────────────────────────────────────────────────────
--
-- The docs were last brought current against v0.16 (2026-08-07); v0.30 shipped since. Each
-- promise below is one phase of bringing them current, stated as what a reader must be able to
-- find. They graduate to `proves` in the change that lands their pages.

--- Every page that `containing` should find a needle in, as one failing list.
local function expect_taught(t, needles)
  t:expect_all(function()
    for _, n in ipairs(needles) do
      t:expect(#containing(t, n.needle), "no page teaches " .. n.what .. " (" .. n.needle .. ")"):gt(0)
    end
  end)
end

prova.test("the roadmap lists only unshipped work", {
  proves = "phase 0 (2026-11-24): the backlog tier and reverse traceability (`prova specs "
    .. "backfill`) shipped while the roadmap still listed them as Designed",
}, function(t)
  local roadmap = fs.read(root .. "/docs/reference/roadmap.md")
  t:expect_all(function()
    t:expect(roadmap:find("The **backlog tier**", 1, true), "backlog tier still planned"):is_nil()
    t:expect(roadmap:find("reverse traceability query", 1, true), "backfill still planned"):is_nil()
  end)
end)

prova.test("the bigger picture: one page introduces every capability as a unit", {
  proves = "phase 1 (2026-11-24): an overview a team can read before a meeting, each "
    .. "capability in a few lines with a link to its section",
}, function(t)
  local page = root .. "/docs/getting-started/the-bigger-picture.md"
  t:expect(page, "no overview page"):is_file()
  local body = fs.read(page)
  t:expect_all(function()
    for _, link in ipairs({
      "../evidence/index.md", "../quality/index.md", "../writing-tests/topologies.md",
      "../writing-tests/mocking-and-proxies.md", "../packages/index.md",
      "../patterns/shared-standards-package.md", "../running-prova/manifest-and-profiles.md",
      "../running-prova/ci-and-output.md",
    }) do
      t:expect(body:find("(" .. link, 1, true), "the overview does not link " .. link):never():is_nil()
    end
  end)
end)

prova.test("the quality account is taught end to end", {
  proves = "phase 2 (2026-11-24): ratchets, deputies, kept reports, lanes and the "
    .. "rust-project retrofit had shipped with no page",
}, function(t)
  t:expect(root .. "/docs/quality/index.md", "no Quality section"):is_file()
  expect_taught(t, {
    { needle = "measure.ratchet", what = "ratchets" },
    { needle = "--update-baseline", what = "raising a floor" },
    { needle = '"goal"', what = "ratchet goals" },
    { needle = "junit.verify", what = "deputed verification" },
    { needle = "cargo nextest", what = "the nextest deputy" },
    { needle = "report.publish", what = "kept reports" },
    { needle = "prova run --list", what = "lanes" },
    { needle = "prova init rust-project", what = "the Rust retrofit" },
  })
end)

prova.test("the backlog tier and reminders are taught", {
  proves = "phase 3 (2026-11-24): the cold tier below a claim, its verbs, and reminders "
    .. "that draw it down",
}, function(t)
  expect_taught(t, {
    { needle = "<!-- backlog:", what = "backlog anchors" },
    { needle = "prova specs capture", what = "verified capture" },
    { needle = "prova specs promote", what = "promotion" },
    { needle = "prova specs backfill", what = "proof-to-claim traceability" },
    { needle = "prova.remind", what = "reminders" },
    { needle = "--heed", what = "heeding reminders" },
    { needle = "VACUOUS-HANG", what = "hangs under falsify" },
  })
end)

prova.test("running at scale is taught", {
  proves = "phase 4 (2026-11-24): locks, flakes, resume/reuse, dependency overrides and the "
    .. "capabilities table had shipped after v0.16 with no page",
}, function(t)
  expect_taught(t, {
    { needle = "prova.writes(", what = "locks" },
    { needle = "prova lock ", what = "joining a lock from outside prova" },
    { needle = "FLAKY", what = "the flaky verdict" },
    { needle = "prova stress", what = "reproducing a flake" },
    { needle = "--resume", what = "resuming a run" },
    { needle = "--reuse", what = "reusing passes" },
    { needle = "--dep ", what = "dependency overrides" },
    { needle = "[capabilities]", what = "declared capabilities" },
    { needle = "idle_timeout", what = "liveness bounds" },
  })
end)

prova.test("environments and packages are current", {
  proves = "phase 5 (2026-11-24): topology registration, startup and scope, the stdio driver "
    .. "and doubles, and the package list as of v0.30",
}, function(t)
  expect_taught(t, {
    { needle = 'startup = "', what = "topology startup budgets" },
    { needle = 'scope = "run"', what = "run-scoped topologies" },
    { needle = "stdio.spawn", what = "the stdio driver" },
    { needle = "stdio.mock", what = "spawnable doubles" },
    { needle = "prova packages add", what = "adding a package from the registry" },
  })
  local official = fs.read(root .. "/docs/packages/official-packages.md")
  t:expect_all(function()
    for _, name in ipairs({ "kind", "vault", "parallels", "xcodebuild", "aegis" }) do
      t:expect(official:find(name, 1, true), "official-packages.md omits " .. name):never():is_nil()
    end
  end)
end)

--- Where each `prova learn` topic lives on the site. A topic the binary teaches with no row here
--- is a feature the docs do not know exists.
local TOPIC_HOMES = {
  pdd = "workflows/the-proof-driven-change.md",
  promises = "writing-tests/promises-and-burndown.md",
  reminders = "quality/reminders.md",
  verifiers = "quality/deputed-verifiers.md",
  reports = "quality/deputed-verifiers.md",
  falsify = "evidence/falsifiers.md",
  spec = "evidence/claims-and-covers.md",
  claims = "evidence/claims-and-covers.md",
  backlog = "evidence/backlog.md",
  record = "evidence/record-and-attest.md",
  evidence = "evidence/index.md",
  project = "running-prova/manifest-and-profiles.md",
  init = "running-prova/scaffolding.md",
  authoring = "writing-tests/tests-and-grouping.md",
  fixtures = "writing-tests/fixtures.md",
  doubles = "writing-tests/mocking-and-proxies.md",
  proxies = "writing-tests/mocking-and-proxies.md",
  drivers = "writing-tests/testing-real-systems.md",
  topologies = "writing-tests/topologies.md",
  packages = "packages/using-packages.md",
  ["package-authoring"] = "packages/authoring-packages.md",
  running = "running-prova/command-line.md",
  locks = "running-prova/locks-and-scale.md",
  capabilities = "running-prova/capabilities.md",
  mcp = "running-prova/agents-and-mcp.md",
}

prova.test("every prova learn topic has a home page that names it", {
  proves = "phase 6 (2026-11-24): the guard that keeps the docs from falling a release behind "
    .. "again — a new topic in the binary is a page the docs owe",
}, function(t)
  local r = shell.run({ "prova", "learn" }, { check = true })
  local topics = {}
  for name in r.stdout:gmatch("\n  ([%w%-]+)%s") do topics[#topics + 1] = name end
  t:expect(#topics, "parsed no topics from `prova learn`"):gt(10)
  t:expect_all(function()
    for _, topic in ipairs(topics) do
      local home = TOPIC_HOMES[topic]
      t:expect(home, "topic `" .. topic .. "` has no home page"):never():is_nil()
      if home then
        local path = root .. "/docs/" .. home
        t:expect(path, topic .. ": " .. home .. " is missing"):is_file()
        if fs.exists(path) then
          t:expect(fs.read(path):find("prova learn " .. topic, 1, true),
            home .. " does not point readers at `prova learn " .. topic .. "`"):never():is_nil()
        end
      end
    end
  end)
end)

-- ── Phase 7: the Reference tier (2026-11-24) ─────────────────────────────────────────────────
--
-- The guides caught up with v0.30 in phases 0–6; the Reference did not. These hold the reference
-- to the API surface the binary itself reports.

--- The concatenated text of every page under docs/reference.
local function reference_text()
  local out = {}
  for _, f in ipairs(fs.glob(root .. "/docs/reference", "**/*.md")) do out[#out + 1] = fs.read(f) end
  return table.concat(out, "\n")
end

prova.test("every function and method prova introspect reports is in the reference", {
  promises = "phase 7a: str, path, socket, websocket, terminal, stdio, report and dozens of "
    .. "methods have no reference entry",
}, function(t)
  local r = shell.run({ "prova", "introspect" }, { check = true })
  local ref = reference_text()
  local missing = {}
  for line in r.stdout:gmatch("[^\n]+") do
    -- "  ns.fn(" is a namespace function; "  Class:method(" is a method. Types ("prova.Foo{") are
    -- documented by the functions that take them, so they are not entries of their own.
    local ns, fn = line:match("^  ([a-z_]+)%.([a-z_][%w_]*)%(")
    local cls, m = line:match("^  ([A-Z][%w]*):([a-z_][%w_]*)%(")
    if ns and not ref:find(ns .. "." .. fn, 1, true) then
      missing[#missing + 1] = ns .. "." .. fn
    elseif cls and not ref:find(":" .. m, 1, true) then
      missing[#missing + 1] = cls .. ":" .. m
    end
  end
  t:expect(#missing, "not in the reference: " .. table.concat(missing, ", ")):equals(0)
end)

prova.test("the reference covers the namespaces the stubs do not describe", {
  promises = "phase 7a: sarif, measure and date are live in the binary but absent from "
    .. "`prova introspect`, so the guard above cannot see them",
}, function(t)
  local ref = reference_text()
  t:expect_all(function()
    for _, needle in ipairs({ "sarif.verify", "sarif.load", "measure.ratchet", "measure.record",
      "date.past", "date.days_since", "junit.ingest", "report.publish" }) do
      t:expect(ref:find(needle, 1, true), "the reference does not document " .. needle):never():is_nil()
    end
  end)
end)

prova.test("the prova.toml reference covers every manifest key", {
  proves = "phase 7b (2026-11-24): topology startup/scope, switches, heed, budget, and the "
    .. "[capabilities], [modules], [stress], [resume], [runner] and [placement] tables were "
    .. "missing from the manifest reference",
}, function(t)
  local toml = fs.read(root .. "/docs/reference/prova-toml.md")
  t:expect_all(function()
    for _, needle in ipairs({ "## `[capabilities]`", "## `[topologies]`", 'startup = "',
      'scope = "run"', "switches", "heed", "## `[stress]`", "## `[runner]`", "## `[specs]`" }) do
      t:expect(toml:find(needle, 1, true), "prova-toml.md omits " .. needle):never():is_nil()
    end
  end)
end)

prova.test("the smaller features are taught where they belong", {
  proves = "phase 7c (2026-11-24): barrier, run-scoped identity, module proofs, and TLS "
    .. "options had no guide coverage (as of v0.30.12; advise, infra and run show were not yet "
    .. "released, so they wait for the release that ships them)",
}, function(t)
  expect_taught(t, {
    { needle = "prova.barrier", what = "the concurrency assertion" },
    { needle = "Scope.Run", what = "run-scoped fixtures" },
    { needle = "fs.digest", what = "conduct identity" },
    { needle = "insecure = true", what = "TLS without verification" },
    { needle = "ca_cert", what = "a private CA" },
    { needle = "prova.cargo", what = "module proofs and the conduct cache" },
    { needle = "--uncached", what = "the audit run" },
  })
end)
