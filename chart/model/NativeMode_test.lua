local NativeMode = require("chart.model.NativeMode")
local Gamemode = require("sea.chart.Gamemode")
local test = {}

---@param t testing.T
function test.metadata_selects_and_data_only_validates(t)
	t:eq(NativeMode.get({}, {mode = "mania"}), "mania")
	for mode, field in pairs({osu = "aim", catch = "catch", taiko = "taiko", sdvx = "sdvx"}) do
		t:eq(NativeMode.get({[field] = {}}, {mode = mode}), mode)
		t:has_error(function() NativeMode.get({[field] = {}}, {mode = "mania"}) end)
		t:has_error(function() NativeMode.get({}, {mode = mode}) end)
	end
	t:has_error(function() NativeMode.get({aim = {}, catch = {}}, {mode = "osu"}) end)
	t:has_error(function() NativeMode.get({}, {}) end)
	t:has_error(function() NativeMode.get({}, {mode = "bad"}) end)
end

---@param t testing.T
function test.enum_preserves_persisted_ids(t)
	for index, mode in ipairs({"mania", "taiko", "osu", "catch", "sdvx"}) do
		t:eq(Gamemode:encode(mode), index - 1)
		t:eq(Gamemode:decode(index - 1), mode)
	end
end

return test
