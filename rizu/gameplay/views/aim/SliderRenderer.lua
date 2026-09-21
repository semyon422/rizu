local Shared = require("rizu.gameplay.views.aim.AimRenderShared")

---@class rizu.gameplay.views.aim.SliderRenderer
local SliderRenderer = {}

---@param object chart.osu.AimObject
---@param slider rizu.aim.Slider
---@param radius number
---@param time number
---@param preempt number
---@param graphics rizu.gameplay.views.aim.SliderGraphics
---@param index integer
function SliderRenderer.draw(object, slider, radius, time, preempt, graphics, index)
	local end_age = time - slider.timing.end_time
	if end_age >= Shared.slider_fade_out then return end
	local alpha = Shared.circleAlpha(preempt - (object.time - time)) * Shared.sliderFadeOutAlpha(end_age)
	if alpha <= 0 then return end

	local snake_end = math.min(1, math.max(0, (time - (object.time - preempt)) / math.max(preempt / 3, 1e-9)))
	graphics:draw(index, alpha, 0, snake_end)

	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.85, 0.95, 1, alpha)
	for _, checkpoint in ipairs(slider.timing.checkpoints) do
		if checkpoint.time >= time then
			local x, y = slider.path:position(checkpoint.progress)
			if checkpoint.kind == "tick" then love.graphics.circle("fill", x, y, 4)
			elseif checkpoint.kind == "repeat" then love.graphics.circle("line", x, y, radius * 0.6) end
		end
	end

	if time >= object.time and time <= slider.timing.end_time then
		local x, y = slider.path:position(slider.timing:progress(time))
		love.graphics.setColor(1, 0.75, 0.2, alpha)
		love.graphics.circle("line", x, y, radius)
		love.graphics.circle("fill", x, y, 6)
		love.graphics.setColor(1, 0.85, 0.5, 0.3 * alpha)
		love.graphics.circle("line", x, y, radius * 2.4)
	end
end

return SliderRenderer
