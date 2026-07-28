--- Version strings in the docs, checked against the things they claim to describe.
---
--- These rotted three separate ways in a single afternoon: this site advertised the run-action
--- default as v0.2.4, the action itself said v0.10.0, and the current release was v0.11.0. Three
--- sources, three answers, each drifting on its own schedule, every one fixed by hand only because
--- someone happened to look.
---
--- Not in the merge gate: these hit the network, and a docs build should not fail because GitHub
--- is slow. `prova --profile nightly` runs them on a schedule instead, so rot surfaces as a red
--- run the next morning rather than as a reader's confusion months later.
---
--- Only strings that CLAIM to track the current release belong here. A pinned plugin example
--- (`prova-postgres@v0.2.0`) is a fixed illustration and is supposed to stay put; asserting on it
--- would be asserting that documentation never uses a stable example.

local root = prova.root

--- The latest published prova release, straight from the source of truth.
local latest = prova.fixture("latest-release", Scope.File, function(ctx)
  local r = shell.run({ "gh", "release", "view", "--repo", "prova-rs/prova",
    "--json", "tagName", "--jq", ".tagName" }, { check = true })
  local tag = r.stdout:gsub("%s+$", "")
  assert(tag:match("^v%d+%.%d+%.%d+$"), "unexpected release tag: " .. tag)
  return tag
end)

--- Places that present themselves as "the current prova", and the pattern that finds the version.
local TRACKS_LATEST = {
  { file = "docs/getting-started/installation.md",
    pattern = "VERSION=(v%d+%.%d+%.%d+)",
    why = "the download example tells a reader to install this exact version" },
  { file = "docs/running-prova/ci-and-output.md",
    pattern = "version: (v%d+%.%d+%.%d+)",
    why = "the GitHub Action example pins a version for a reader to copy" },
  { file = ".github/workflows/deploy.yml",
    pattern = "version: (v%d+%.%d+%.%d+)",
    why = "this site's own gate should run the release its docs describe" },
}

prova.test("every version the docs present as current is the current release",
  { requires = { "gh" } }, function(t)
  local want = t:use(latest)

  t:expect_all(function()
    for _, site in ipairs(TRACKS_LATEST) do
      local body = fs.read(root .. "/" .. site.file)
      local found = body:match(site.pattern)
      t:expect(found, site.file .. " — " .. site.why):never():is_nil()
      if found then
        t:expect(found, site.file .. " tracks the latest release"):equals(want)
      end
    end
  end)
end)

prova.test("the run-action default is the current release",
  { requires = { "gh" } }, function(t)
  -- The drift that started this: the action's own default trailed two releases while three
  -- different documents each quoted a different number for it.
  local want = t:use(latest)
  -- Ask for the raw file rather than the base64 the contents API returns by default; decoding it
  -- through a pipe was an extra moving part with its own failure mode.
  local r = shell.run({ "gh", "api", "-H", "Accept: application/vnd.github.raw",
    "repos/prova-rs/run-action/contents/action.yaml?ref=v1" }, { check = true })
  local default = r.stdout:match('default:%s*"(v%d+%.%d+%.%d+)"')

  t:expect(default, "action.yaml declares a default version"):never():is_nil()
  t:expect(default, "run-action@v1 installs the current release by default"):equals(want)
end)
