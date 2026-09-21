local Shared = require("rizu.gameplay.views.aim.AimRenderShared")

---@class rizu.gameplay.views.aim.CircleRenderer
local CircleRenderer = {}

---@param object chart.osu.AimObject
---@param radius number
---@param time number
---@param preempt number
function CircleRenderer.draw(object, radius, time, preempt)
	local remaining = object.time - time
	local age = preempt - remaining
	local alpha = Shared.circleAlpha(age)
	if alpha <= 0 then return end
	local border_width = 2
	love.graphics.setColor(0.16, 0.4, 0.58, alpha)
	love.graphics.circle("fill", object.x, object.y, radius)
	-- LÖVE centres line strokes on their radius. Offset the stroke radius
	-- inward so its outer edge remains within the hit circle.
	love.graphics.setLineWidth(border_width)
	love.graphics.setColor(0.8, 0.92, 1, alpha)
	love.graphics.circle("line", object.x, object.y, radius - border_width / 2)
	if remaining > 0 then
		local approach_alpha = Shared.approachAlpha(age, preempt)
		local approach = 1 + 3 * remaining / preempt
		love.graphics.setColor(0.8, 0.92, 1, approach_alpha)
		love.graphics.circle("line", object.x, object.y, radius * approach)
	end
end

return CircleRenderer
