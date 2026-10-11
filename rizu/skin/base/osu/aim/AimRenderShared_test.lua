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

---@param t testing.T
function test.hit_heads_expand_while_fading_and_missed_heads_only_fade(t)
	t:tdeq({Shared.headFade("hit", -1)}, {1, 1})
	local alpha, scale = Shared.headFade("hit", Shared.hit_fade_out / 2)
	t:aeq(alpha, 0.5, 1e-9)
	t:aeq(scale, 1.3, 1e-9)
	t:tdeq({Shared.headFade("hit", 1)}, {0, 1.4})
	t:tdeq({Shared.headFade("miss", Shared.miss_fade_out / 2)}, {0.5, 1})
	t:tdeq({Shared.headFade("miss", 1)}, {0, 1})
end

return test
