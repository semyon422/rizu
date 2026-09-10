local NativeMode = require("chart.model.NativeMode")
local Gamemode = require("sea.chart.Gamemode")
local ChartBuilder = require("chart.format.notechart.ChartBuilder")
local ModeNotes = require("chart.model.ModeNotes")
local test = {}

---@param t testing.T
function test.metadata_selects_and_data_only_validates(t)
	local builder = ChartBuilder()
	local chart = builder.chart
	t:eq(NativeMode.get(chart, {mode = "mania"}), "mania")
	ModeNotes.write(chart, builder:createAbsoluteLayer(), builder:getVisual("main"), "osu", {objects = {{time = 1, kind = "circle"}}})
	t:eq(NativeMode.get(chart, {mode = "osu"}), "osu")
	t:has_error(function() NativeMode.get(chart, {mode = "mania"}) end)
	t:has_error(function() NativeMode.get(chart, {mode = "catch"}) end)
	t:has_error(function() NativeMode.get(chart, {}) end)
	t:has_error(function() NativeMode.get(chart, {mode = "bad"}) end)
end

---@param t testing.T
function test.enum_preserves_persisted_ids(t)
	for index, mode in ipairs({"mania", "taiko", "osu", "catch", "sdvx"}) do
		t:eq(Gamemode:encode(mode), index - 1)
		t:eq(Gamemode:decode(index - 1), mode)
	end
end

return test
