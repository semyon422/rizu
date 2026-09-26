local Shared = require("rizu.skin.base.osu.aim.AimRenderShared")

---@class rizu.skin.base.osu.aim.SliderRenderer
local SliderRenderer = {}

---@param object chart.osu.AimObject
---@param time number
---@param preempt number
---@return number progress
function SliderRenderer.getSnakeEnd(object, time, preempt)
	return math.min(1, math.max(0, (time - (object.time - preempt)) / math.max(preempt / 3, 1e-9)))
end

---@param object chart.osu.AimObject
---@param slider rizu.aim.Slider
---@param time number
---@param preempt number
---@return number alpha
function SliderRenderer.getBodyAlpha(object, slider, time, preempt)
	local end_age = time - slider.timing.end_time
	if end_age >= Shared.slider_fade_out then return 0 end
	return Shared.circleAlpha(preempt - (object.time - time)) * Shared.sliderFadeOutAlpha(end_age)
end

---@param object chart.osu.AimObject
---@param slider rizu.aim.Slider
---@param time number
---@param preempt number
---@param graphics rizu.skin.base.osu.aim.SliderGraphics
---@param index integer
---@return number alpha
function SliderRenderer.drawBody(object, slider, time, preempt, graphics, index)
	local alpha = SliderRenderer.getBodyAlpha(object, slider, time, preempt)
	if alpha <= 0 then return alpha end

	local snake_end = SliderRenderer.getSnakeEnd(object, time, preempt)
	graphics:draw(index, alpha, 0, snake_end)
	return alpha
end

return SliderRenderer
