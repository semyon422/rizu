local DanBadge = require("ui.screens.song_select_v2.DanBadge")

local test = {}

---@param t testing.T
function test.parse_splits_the_mark_off(t)
	t:tdeq({DanBadge.parse("Beta+")}, {"Beta", "+"})
	t:tdeq({DanBadge.parse("5th-")}, {"5th", "-"})
	t:tdeq({DanBadge.parse("Intro")}, {"Intro"})
end

---@param t testing.T
function test.image_names(t)
	t:eq(DanBadge.imageName("Beta"), "dan_4k_reform_beta")
	t:eq(DanBadge.imageName("9th"), "dan_4k_reform_9")
	t:eq(DanBadge.imageName("10th"), "dan_4k_reform_10")
end

---@param t testing.T
function test.glitch_intensity_grows_from_gamma(t)
	t:eq(DanBadge.glitchIntensity("Beta"), 0)
	t:eq(DanBadge.glitchIntensity("5th"), 0)
	t:eq(DanBadge.glitchIntensity("Intro"), 0)
	t:eq(DanBadge.glitchIntensity("Theta"), 1)
	local last = 0
	for _, name in ipairs({"Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta"}) do
		local intensity = DanBadge.glitchIntensity(name)
		t:assert(intensity > last, name)
		last = intensity
	end
end

return test
