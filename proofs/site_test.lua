-- The build gate: the site compiles, typechecks, and emits what the config
-- promises. This is the slow half — it shells out to the real pnpm commands
-- rather than reimplementing them, so there is nothing here to drift from what
-- a developer runs by hand.

local root = prova.root

-- One build, shared by every test in this file.
local site = prova.fixture("site", Scope.File, function(ctx)
  local r = shell.run("pnpm build", { cwd = root, timeout = "900s" })
  return { build = r, dir = root .. "/build" }
end)

-- The "is the toolchain here?" guard is NOT a test. `must_run` in prova.toml
-- does it properly: as a precondition, before anything executes, reporting the
-- probe's own answer — so a runner missing pnpm fails up front rather than
-- reporting all-green having built nothing. A hand-rolled test could only
-- notice after the suite was already under way, and only if it ran at all.

prova.test("typecheck passes", { requires = { "pnpm" }, timeout = "300s" }, function(t)
  local r = shell.run("pnpm typecheck", { cwd = root, timeout = "300s" })
  t:expect(r:ok(), "pnpm typecheck exits 0"):is_true()
  if not r:ok() then t:expect(r.stdout .. r.stderr, "tsc output"):equals("") end
end)

prova.test("the site builds", { requires = { "pnpm" }, timeout = "900s", serial = true }, function(t)
  local s = t:use(site)
  t:expect(s.build:ok(), "pnpm build exits 0"):is_true()
  t:expect(s.dir .. "/index.html", "index.html emitted"):is_file()
end)

prova.test("the build emits every brand asset", { requires = { "pnpm" }, timeout = "900s", serial = true }, function(t)
  local s = t:use(site)
  for _, name in ipairs({ "logo.svg", "logo-fail.svg", "favicon.svg",
                          "favicon-pass.svg", "favicon-fail.svg",
                          "prova-social-card.png" }) do
    t:expect(s.dir .. "/img/" .. name, name .. " shipped"):is_file()
  end
end)

prova.test("the built page advertises the social card", { requires = { "pnpm" }, timeout = "900s", serial = true }, function(t)
  -- Docusaurus emits unquoted attributes, so match loosely on the tag.
  local s = t:use(site)
  local html = fs.read(s.dir .. "/index.html")

  t:expect(html, "og:image present"):matches("og:image")
  t:expect(html, "twitter:image present"):matches("twitter:image")
  t:expect(html, "og:image points at the card"):contains("prova-social-card.png")
end)

prova.test("the built CSS carries both brand states", { requires = { "pnpm" }, timeout = "900s", serial = true }, function(t)
  -- A logo that swaps over a stylesheet that does not is a half-applied brand.
  local s = t:use(site)
  local css = ""
  for _, f in ipairs(fs.glob(s.dir .. "/assets/css", "**/*.css")) do
    css = css .. fs.read(f)
  end

  t:expect(css, "light text value"):contains("#047857")
  t:expect(css, "light hero fill"):contains("#059669")
  t:expect(css, "dark text value"):contains("#f87171")
  t:expect(css, "dark hero fill"):contains("#ef4444")
end)

prova.test("no unresolved conflict markers reach main", function(t)
  -- PR #1 conflicted in docs/reference/cli.md. A half-resolved merge is easy to
  -- commit and invisible in a rendered diff.
  for _, dir in ipairs({ "docs", "blog", "src" }) do
    for _, f in ipairs(fs.glob(root .. "/" .. dir, "**/*")) do
      if f:match("%.md$") or f:match("%.mdx$") or f:match("%.tsx?$") or f:match("%.css$") then
        local body = fs.read(f)
        t:expect(body:find("\n<<<<<<<"), f:gsub(".*/", "") .. " has no conflict marker"):is_nil()
        t:expect(body:find("\n>>>>>>>"), f:gsub(".*/", "") .. " has no conflict marker"):is_nil()
      end
    end
  end
end)
