local class = require("class")
local ffi = require("ffi")

---@class chart.MsdDiffRates: minacalc.Ssr
---@operator call: chart.MsdDiffRates
local MsdDiffRates = class()

---@param t number[]
---@return string
function MsdDiffRates.encode(t)
	---@type ffi.cdata*
	local p = ffi.new("float[?]", 14)
	for i = 0, 13, 1 do
		p[i] = t[i + 1]
	end

	local s = ffi.string(p, ffi.sizeof(p))
	return s
end

---@param s string
---@return number[]
function MsdDiffRates.decode(s)
	---@type ffi.cdata*
	local p = ffi.new("float[?]", 14)
	ffi.copy(p, s, math.min(#s, ffi.sizeof(p)))

	local t = {}
	for i = 0, 13, 1 do
		table.insert(t, p[i])
	end

	return t
end

return MsdDiffRates
