---@class rizu.skin.base.osu.aim.AimRenderShared
local AimRenderShared = {}

AimRenderShared.circle_fade_in = 0.4
AimRenderShared.approach_fade_in = 0.8
AimRenderShared.slider_fade_out = 0.24
AimRenderShared.hit_fade_out = 0.24
AimRenderShared.miss_fade_out = 0.06

---@param age number Seconds since the object appeared.
---@return number
function AimRenderShared.circleAlpha(age)
	return math.min(1, math.max(0, age / AimRenderShared.circle_fade_in))
end

---@param age number Seconds since the object appeared.
---@param preempt number
---@return number
function AimRenderShared.approachAlpha(age, preempt)
	return math.min(0.9, math.max(0, age / math.min(preempt, AimRenderShared.approach_fade_in) * 0.9))
end

---@param end_age number Seconds since the slider ended.
---@return number
function AimRenderShared.sliderFadeOutAlpha(end_age)
	if end_age <= 0 then return 1 end
	return math.max(0, 1 - end_age / AimRenderShared.slider_fade_out)
end

---A hit head expands while fading; a missed one only fades, faster.
---@param state "hit"|"miss"
---@param age number Seconds since the head was resolved.
---@return number alpha
---@return number scale
function AimRenderShared.headFade(state, age)
	local hit = state == "hit"
	local progress = math.min(1, math.max(0, age) / (hit and AimRenderShared.hit_fade_out or AimRenderShared.miss_fade_out))
	return 1 - progress, hit and 1 + 0.4 * (2 * progress - progress * progress) or 1
end

return AimRenderShared
