local Spinner = require("rizu.gameplay.aim.Spinner")

---@class rizu.gameplay.views.aim.SpinnerRenderer
local SpinnerRenderer = {}

---@param spinner rizu.aim.Spinner
---@param time number
function SpinnerRenderer.draw(spinner, time)
	local x, y = Spinner.center_x, Spinner.center_y
	local progress = math.min(1, spinner:getTurns() / spinner.required_turns)
	love.graphics.setColor(0.12, 0.2, 0.3)
	love.graphics.circle("fill", x, y, 150)
	love.graphics.setColor(0.8, 0.9, 1)
	love.graphics.circle("line", x, y, 150)
	local remaining = math.max(0, math.min(1, (spinner.end_time - time) / (spinner.end_time - spinner.start_time)))
	love.graphics.circle("line", x, y, 40 + 100 * remaining)
	love.graphics.setColor(0.3, 1, 0.6)
	if progress > 0 then love.graphics.arc("line", "open", x, y, 155, -math.pi / 2, -math.pi / 2 + 2 * math.pi * progress) end
	love.graphics.setColor(1, 0.8, 0.3)
	love.graphics.circle("line", x, y, Spinner.dead_radius)
	local angle = spinner.last_angle or 0
	love.graphics.line(x, y, x + 100 * math.cos(angle), y + 100 * math.sin(angle))
end

return SpinnerRenderer
