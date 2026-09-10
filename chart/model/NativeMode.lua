local NativeNoteTypes = require("chart.model.NativeNoteTypes")
local Gamemode = require("sea.chart.Gamemode")

local NativeMode = {}

---@param chart chart.Chart
---@param chartmeta sea.Chartmeta
---@return sea.Gamemode
function NativeMode.get(chart, chartmeta)
	local mode = chartmeta.mode
	assert(mode and Gamemode:encode_safe(mode) ~= nil, "Missing or invalid native chart mode; re-read the chart source.")
	for _, note in chart.notes:iter() do
		local native = NativeNoteTypes[note.type]
		assert(not native or native == mode, "Native mode does not match note data")
	end
	return mode
end

return NativeMode
