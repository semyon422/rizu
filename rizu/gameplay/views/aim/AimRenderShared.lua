---@class rizu.gameplay.views.aim.AimRenderShared
local AimRenderShared = {}

AimRenderShared.circle_fade_in = 0.4
AimRenderShared.approach_fade_in = 0.8
AimRenderShared.slider_fade_out = 0.24

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

return AimRenderShared
