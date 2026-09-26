local Shared = require("rizu.skin.base.osu.aim.AimRenderShared")
local test = {}

---@param t testing.T
function test.circle_fade_in_is_clamped(t)
	t:aeq(Shared.circleAlpha(-1), 0, 1e-9)
	t:aeq(Shared.circleAlpha(0.2), 0.5, 1e-9)
	t:aeq(Shared.circleAlpha(1), 1, 1e-9)
end

---@param t testing.T
function test.approach_fade_in_and_slider_fade_out_are_clamped(t)
	t:aeq(Shared.approachAlpha(0.4, 1.2), 0.45, 1e-9)
	t:aeq(Shared.approachAlpha(2, 1.2), 0.9, 1e-9)
	t:aeq(Shared.sliderFadeOutAlpha(0), 1, 1e-9)
	t:aeq(Shared.sliderFadeOutAlpha(Shared.slider_fade_out / 2), 0.5, 1e-9)
	t:aeq(Shared.sliderFadeOutAlpha(Shared.slider_fade_out), 0, 1e-9)
end

return test
