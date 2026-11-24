--- The docs describe a prova release; this watches the distance to the one actually running.
---
--- The site went fourteen minor releases without a currency pass (v0.16 → v0.30), and nothing
--- said so. The `[requires] prova` floor is the docs' own statement of which prova they describe:
--- once the running binary is more than two minors past it, a currency pass is due.

local function minor(version)
  return tonumber(version:match("^v?%d+%.(%d+)"))
end

prova.remind("the docs are within two minors of the running prova", {
  tags = { "currency" },
  when = function()
    local floor = fs.read(prova.root .. "/prova.toml"):match('prova%s*=%s*">=%s*([%d%.]+)"')
    if not floor then return "could not read [requires] prova from prova.toml" end
    local gap = minor(prova.version) - minor(floor)
    return gap > 2 and ("docs describe prova " .. floor .. "; running " .. prova.version
      .. " (" .. gap .. " minors ahead)")
  end,
}, "compare the docs against `prova learn`, capture the gaps as promises in "
  .. "proofs/docs_coverage.prova.lua, burn them down, then raise [requires] prova")
