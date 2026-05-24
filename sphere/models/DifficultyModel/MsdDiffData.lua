local class = require("class")
local ffi = require("ffi")
local minacalc = require("chart.scoring.minacalc")

---@class sphere.MsdDiffData: minacalc.Ssr
---@operator call: sphere.MsdDiffData
local MsdDiffData = class()

---@param ssr minacalc.Ssr
---@return string
function MsdDiffData.encode(ssr)
	---@type ffi.cdata*
	local p = ffi.new("Ssr", ssr)
	local s = ffi.string(p, ffi.sizeof(p))
	return s
end

---@param s string
---@return minacalc.Ssr
function MsdDiffData.decode(s)
	---@type ffi.cdata*
	local p = ffi.new("Ssr")
	ffi.copy(p, s, math.min(#s, ffi.sizeof(p)))
	---@cast p -ffi.cdata*, +minacalc.Ssr
	return {
		overall = p.overall,
		stream = p.stream,
		jumpstream = p.jumpstream,
		handstream = p.handstream,
		stamina = p.stamina,
		jackspeed = p.jackspeed,
		chordjack = p.chordjack,
		technical = p.technical,
	}
end

return MsdDiffData
