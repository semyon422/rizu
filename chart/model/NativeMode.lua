local Gamemode = require("sea.chart.Gamemode")

local NativeMode = {}

---@type {[sea.Gamemode]: string}
local fields = {osu = "aim", catch = "catch", taiko = "taiko", sdvx = "sdvx"}

-- Metadata selects mechanics. DTO presence only validates that selection.
---@param chart chart.Chart
---@param chartmeta sea.Chartmeta
---@return sea.Gamemode
function NativeMode.get(chart, chartmeta)
	local mode = chartmeta.mode
	assert(mode and Gamemode:encode_safe(mode) ~= nil, "Missing or invalid native chart mode; re-read the chart source.")
	for candidate, field in pairs(fields) do
		assert((chart[field] ~= nil) == (mode == candidate), "Native mode does not match chart data: " .. candidate)
	end
	return mode
end

return NativeMode
