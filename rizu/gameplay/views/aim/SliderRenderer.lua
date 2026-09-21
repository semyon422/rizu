local Shared = require("rizu.gameplay.views.aim.AimRenderShared")

---@class rizu.gameplay.views.aim.SliderRenderer
local SliderRenderer = {}

---@param object chart.osu.AimObject
---@param slider rizu.aim.Slider
---@param radius number
---@param time number
---@param preempt number
function SliderRenderer.draw(object, slider, radius, time, preempt)
	local end_age = time - slider.timing.end_time
	if end_age >= Shared.slider_fade_out then return end
	local alpha = Shared.circleAlpha(preempt - (object.time - time)) * Shared.sliderFadeOutAlpha(end_age)
	if alpha <= 0 then return end

	local points = slider.path.points
	love.graphics.setLineWidth(radius * 2)
	love.graphics.setColor(0.16, 0.33, 0.46, alpha)
	for j = 2, #points do love.graphics.line(points[j - 1][1], points[j - 1][2], points[j][1], points[j][2]) end
	for _, point in ipairs(points) do love.graphics.circle("fill", point[1], point[2], radius) end

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
