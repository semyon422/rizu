local CircleRenderer = require("rizu.skin.base.osu.aim.CircleRenderer")

---@class rizu.skin.base.osu.aim.SliderOverlayRenderer
local SliderOverlayRenderer = {}

---@param object chart.osu.AimObject
---@param radius number
---@param time number
---@param preempt number
function SliderOverlayRenderer.drawHead(object, radius, time, preempt)
	CircleRenderer.draw(object, radius, time, preempt)
end

---@param slider rizu.aim.Slider
---@param radius number
---@param time number
---@param alpha number
---@param snake_end number
function SliderOverlayRenderer.drawBodyOverlays(slider, radius, time, alpha, snake_end)
	if alpha <= 0 then return end

	love.graphics.setLineWidth(2)
	love.graphics.setColor(0.85, 0.95, 1, alpha)
	snake_end = math.min(1, math.max(0, snake_end))
	for _, checkpoint in ipairs(slider.timing.checkpoints) do
		if checkpoint.time >= time then
			if checkpoint.kind == "tick" and checkpoint.progress <= snake_end then
				local x, y = slider.path:position(checkpoint.progress)
				love.graphics.circle("fill", x, y, 4)
			elseif checkpoint.kind == "repeat" then
				-- Repeat markers travel with the snaking edge instead of appearing
				-- immediately at the far end of the slider path.
				local progress = checkpoint.progress == 0 and 1 - snake_end or snake_end
				local x, y = slider.path:position(progress)
				love.graphics.circle("line", x, y, radius * 0.6)
			end
		end
	end

	if time >= slider.timing.start_time and time <= slider.timing.end_time then
		local x, y = slider.path:position(slider.timing:progress(time))
		love.graphics.setColor(1, 0.75, 0.2, alpha)
		love.graphics.circle("line", x, y, radius)
		love.graphics.circle("fill", x, y, 6)
		love.graphics.setColor(1, 0.85, 0.5, 0.3 * alpha)
		love.graphics.circle("line", x, y, radius * 2.4)
	end
end

return SliderOverlayRenderer
