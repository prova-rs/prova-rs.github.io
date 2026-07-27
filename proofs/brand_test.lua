-- The brand invariants, asserted against source. No build required, so this is
-- the fast half of the bar — it answers in under a second.
--
-- Every proof here is a defect this repo actually shipped: an XML comment that
-- silently broke both logos, a link color that sat under the AA floor for
-- months, a mark whose failing form outweighed its passing one.

local root = prova.root
local img = root .. "/static/img"

-- WCAG 2.x relative luminance and contrast ratio.
local function lin(c)
  c = c / 255
  if c <= 0.04045 then return c / 12.92 end
  return ((c + 0.055) / 1.055) ^ 2.4
end

local function luminance(hex)
  return 0.2126 * lin(tonumber(hex:sub(2, 3), 16))
       + 0.7152 * lin(tonumber(hex:sub(4, 5), 16))
       + 0.0722 * lin(tonumber(hex:sub(6, 7), 16))
end

local function contrast(a, b)
  local la, lb = luminance(a), luminance(b)
  local hi, lo = math.max(la, lb), math.min(la, lb)
  return (hi + 0.05) / (lo + 0.05)
end

-- Total stroke length of an SVG path made only of M/L segments, in viewBox
-- units. Enough for these marks; not a general path parser.
local function polyline_length(d)
  local total, px, py = 0, nil, nil
  for cmd, x, y in d:gmatch("([ML])%s*(-?%d+%.?%d*)%s+(-?%d+%.?%d*)") do
    x, y = tonumber(x), tonumber(y)
    if cmd == "L" and px then
      total = total + math.sqrt((x - px) ^ 2 + (y - py) ^ 2)
    end
    px, py = x, y
  end
  return total
end

-- Is this path the inner glyph rather than a bracket? Decided on the path's
-- bounding box, not on how its `d` string happens to start: the X's second arm
-- runs right-to-left (`M79 49 L49 79`), so matching on leading coordinates
-- silently measured half the mark and the proof passed either way.
local function is_glyph(d)
  local minx, miny, maxx, maxy
  for x, y in d:gmatch("(-?%d+%.?%d*)%s+(-?%d+%.?%d*)") do
    x, y = tonumber(x), tonumber(y)
    minx = math.min(minx or x, x); maxx = math.max(maxx or x, x)
    miny = math.min(miny or y, y); maxy = math.max(maxy or y, y)
  end
  if not minx then return false end
  -- The brackets span y 26..102; every glyph sits inside the 40..92 box.
  return minx >= 40 and maxx <= 92 and miny >= 40 and maxy <= 92
end

--------------------------------------------------------------------------------

prova.test("every brand SVG is well-formed XML", { requires = { "python3" } }, function(t)
  local files = fs.glob(img, "**/*.svg")
  table.sort(files)
  t:expect(#files, "svg count"):gte(5)

  for _, f in ipairs(files) do
    local r = shell.run({ "python3", "-c",
      "import sys,xml.dom.minidom as m; m.parse(sys.argv[1])", f })
    t:expect(r:ok(), f:gsub(".*/", "") .. " parses"):is_true()
  end
end)

prova.test("no XML comment contains a double hyphen", function(t)
  -- `--` is illegal inside an XML comment. Writing `--ifm-color-primary` in a
  -- comment turned both logos into broken images, and nothing failed: the build
  -- passed, the file served 200, and only the rendered page showed it. Checked
  -- without python3 on purpose, so this one can never skip.
  for _, f in ipairs(fs.glob(img, "**/*.svg")) do
    for body in fs.read(f):gmatch("<!%-%-(.-)%-%->") do
      t:expect(body:find("%-%-"), f:gsub(".*/", "") .. " comment is clean"):is_nil()
    end
  end
end)

prova.test("brand text colors clear the AA contrast floor", function(t)
  -- emerald-600 (#059669) shipped as the light link color at 3.77:1, under the
  -- 4.5:1 bar, for the life of the emerald palette. The floor is the proof.
  local css = fs.read(root .. "/src/css/custom.css")

  local light = css:match("^.-%-%-ifm%-color%-primary:%s*(#%x%x%x%x%x%x)")
  local dark = css:match("%[data%-theme='dark'%].-%-%-ifm%-color%-primary:%s*(#%x%x%x%x%x%x)")

  t:expect(light, "light primary found"):never():is_nil()
  t:expect(dark, "dark primary found"):never():is_nil()

  t:expect(contrast(light, "#ffffff"), light .. " on white"):gte(4.5)
  t:expect(contrast(dark, "#1b1b1d"), dark .. " on dark page"):gte(4.5)
  t:expect(contrast(dark, "#242526"), dark .. " on dark card/sidebar"):gte(4.5)
end)

prova.test("hero fills carry white at matched weight", function(t)
  -- The two heroes should read as one brand flipped, not as one shouting. Both
  -- fills are large solid color under white type, so match them on contrast.
  local css = fs.read(root .. "/src/css/custom.css")
  local fills = {}
  for hex in css:gmatch("%-%-ifm%-hero%-background%-color:%s*(#%x%x%x%x%x%x)") do
    fills[#fills + 1] = hex
  end

  t:expect(#fills, "hero fills declared"):equals(2)
  for _, hex in ipairs(fills) do
    t:expect(contrast(hex, "#ffffff"), hex .. " under white"):gte(3.0)
  end

  local a, b = contrast(fills[1], "#ffffff"), contrast(fills[2], "#ffffff")
  t:expect(math.abs(a - b), "difference in hero weight"):lt(0.5)
end)

prova.test("the failing mark does not outweigh the passing one", function(t)
  -- Two full diagonals carry ~1.5x the ink of a checkmark at equal stroke
  -- width, which made the dark-mode logo read heavier than the light one.
  -- Compare ink -- stroke length times width -- not width alone.
  local function ink(path)
    local svg = fs.read(path)
    -- The group's stroke-width is the default; a path may override it.
    local group_w = tonumber(svg:match('<g[^>]-stroke%-width="([%d%.]+)"')) or 12
    local total, arms = 0, 0
    for d, attrs in svg:gmatch('<path d="([^"]*)"([^/>]*)') do
      if is_glyph(d) then
        local w = tonumber(attrs:match('stroke%-width="([%d%.]+)"')) or group_w
        total = total + polyline_length(d) * w
        arms = arms + 1
      end
    end
    return total, arms
  end

  local pass, pass_arms = ink(img .. "/logo.svg")
  local fail, fail_arms = ink(img .. "/logo-fail.svg")

  -- Guard the measurement itself. Without this the ratio can look healthy
  -- because a stroke went uncounted rather than because the marks balance.
  t:expect(pass_arms, "checkmark paths measured"):equals(1)
  t:expect(fail_arms, "X paths measured"):equals(2)
  t:expect(pass, "passing glyph ink"):gt(0)
  t:expect(fail / pass, "fail:pass ink ratio"):lte(1.25)
end)

prova.test("both brand states ship as assets", function(t)
  for _, name in ipairs({ "logo.svg", "logo-fail.svg", "favicon.svg",
                          "favicon-pass.svg", "favicon-fail.svg",
                          "prova-social-card.png" }) do
    t:expect(img .. "/" .. name, name):is_file()
  end

  -- A dark-mode logo that exists but is never wired up is the same as no
  -- dark-mode logo. Assert the config actually reaches for it.
  local cfg = fs.read(root .. "/docusaurus.config.ts")
  t:expect(cfg, "navbar logo declares srcDark"):contains("srcDark")
  t:expect(cfg, "favicon declared"):contains("img/favicon.svg")
end)

prova.test("the social card is exactly 1200x630", { requires = { "file" } }, function(t)
  -- og:image wants 1200x630; platforms crop or reject anything else. fs.read is
  -- UTF-8 only and a PNG is not, so read the header through `file` rather than
  -- parsing IHDR ourselves.
  local card = img .. "/prova-social-card.png"
  t:expect(card, "card exists"):is_file()

  local out = shell.run({ "file", "-b", card }, { check = true }).stdout
  t:expect(out, "is a PNG"):contains("PNG image data")

  local w, h = out:match("(%d+)%s*x%s*(%d+)")
  t:expect(tonumber(w), "card width"):equals(1200)
  t:expect(tonumber(h), "card height"):equals(630)
end)
