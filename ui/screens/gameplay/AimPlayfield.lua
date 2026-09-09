local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.screens.gameplay.AimPlayfield: gui.View
---@operator call: ui.screens.gameplay.AimPlayfield
local AimPlayfield = View + {}

---@param game sphere.GameController
function AimPlayfield:new(game)
	View.new(self)
	self.game = game
end

---@return number scale
---@return number x
---@return number y
function AimPlayfield:getField()
	local scale = math.max(0.001, math.min(self.width / 640, self.height / 480))
	return scale, (self.width - 512 * scale) / 2, (self.height - 384 * scale) / 2
end

---@param x number
---@param y number
---@return number
---@return number
function AimPlayfield:toChart(x, y)
	x, y = self.world_transform:inverseTransformPoint(x, y)
	local scale, ox, oy = self:getField()
	return (x - ox) / scale, (y - oy) / scale
end

function AimPlayfield:draw()
	local re = self.game.rhythm_engine
	local rules = re and re.aim_rules
	if not rules then return end
	local scale, ox, oy = self:getField()
	local time = re.visual_info.time
	love.graphics.push("all")
	Painter.setColorRgb(0.04, 0.05, 0.08, 0.95)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
	love.graphics.translate(ox, oy)
	love.graphics.scale(scale)
	love.graphics.setFont(Resources.getFont("regular", 18))
	love.graphics.setLineWidth(2)
	local objects = rules.chart.objects
	for i = rules.next_index, #objects do
		local object = objects[i]
		if object.time - time > rules.preempt then break end
		if not rules.states[i] then
			Painter.setColorRgb(0.2, 0.65, 0.95, 0.45)
			love.graphics.circle("fill", object.x, object.y, rules.radius)
			Painter.setColorRgb(0.8, 0.92, 1)
			love.graphics.circle("line", object.x, object.y, rules.radius)
			local approach = 1 + 3 * math.max(0, (object.time - time) / rules.preempt)
			love.graphics.circle("line", object.x, object.y, rules.radius * approach)
			love.graphics.printf(tostring(i), object.x - 40, object.y - 10, 80, "center")
		end
	end
	for i = #rules.events, math.max(1, #rules.events - 20), -1 do
		local event = rules.events[i]
		local age = re.logic_info.time - event.time
		if age > 0.4 then break end
		local object = objects[event.index]
		if event.hit then Painter.setColorRgb(0.3, 1, 0.5, 1 - age / 0.4)
		else Painter.setColorRgb(1, 0.3, 0.3, 1 - age / 0.4) end
		love.graphics.printf(event.hit and "HIT" or "MISS", object.x - 40, object.y - 10, 80, "center")
	end
	Painter.setColorRgb(1, 0.85, 0.2)
	love.graphics.circle("line", rules.x, rules.y, 9)
	love.graphics.circle("fill", rules.x, rules.y, 3)
	Painter.setColorRgb(1, 1, 1)
	love.graphics.print(("Aim — experimental circles | Hit %d / Miss %d"):format(rules.hits, rules.misses), 0, -36)
	local state = self.game.pauseModel.state
	love.graphics.print("Z / X or mouse buttons | " .. state, 0, 400)
	love.graphics.pop()
end

return AimPlayfield
