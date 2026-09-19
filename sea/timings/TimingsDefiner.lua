local class = require("class")

---@type sea.ITimingValuesPreset[]
local presets = {
	require("sea.timings.osumania.OsuManiaV1Timings_v4"),
	require("sea.timings.osumania.OsuManiaV1Timings_v3"),
	require("sea.timings.osumania.OsuManiaV1Timings_v2"),
	require("sea.timings.osumania.OsuManiaV1Timings_v1"),

	require("sea.timings.osumania.OsuManiaV2Timings_v2"),
	require("sea.timings.osumania.OsuManiaV2Timings_v1"),

	require("sea.timings.stepmania.EtternaTimings_v2"),
	require("sea.timings.stepmania.EtternaTimings_v1"),

	require("sea.timings.sphere.SoundsphereTimings_v2"),
	require("sea.timings.sphere.SoundsphereTimings_v1"),
	require("sea.timings.quaver.QuaverTimings_v1"),
	require("sea.timings.bmsrank.LunaticRaveTimings_v2"),
	require("sea.timings.bmsrank.LunaticRaveTimings_v1"),
	require("sea.timings.iidx.IidxTimings_v1"),
	require("sea.timings.simple.SimpleTimings_v1"),
}

---@class sea.TimingsDefiner
---@operator call: sea.TimingsDefiner
local TimingsDefiner = class()

---@param tvs sea.TimingValues
---@return sea.Timings?
---@return sea.Subtimings?
function TimingsDefiner:match(tvs)
	for _, preset in ipairs(presets) do
		local timings, subtimings = preset:match(tvs)
		if timings then
			return timings, subtimings
		end
	end
end

return TimingsDefiner
