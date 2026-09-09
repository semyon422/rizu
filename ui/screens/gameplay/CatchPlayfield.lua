local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.screens.gameplay.CatchPlayfield: gui.View
---@operator call: ui.screens.gameplay.CatchPlayfield
local CatchPlayfield = View + {}

---@param game sphere.GameController
function CatchPlayfield:new(game)
	View.new(self)
	self.game = game
end

function CatchPlayfield:draw()
	local re = self.game.rhythm_engine
	local rules = re and re.catch_rules
	if not rules then return end
	love.graphics.push("all")
	Painter.setColorRgb(0.04, 0.05, 0.08)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
	local scale = math.min(self.width / 640, self.height / 480)
	love.graphics.translate((self.width - 512 * scale) / 2, (self.height - 400 * scale) / 2)
	love.graphics.scale(scale)
	love.graphics.setFont(Resources.getFont("regular", 16))
	love.graphics.setLineWidth(2)
	Painter.setColorRgb(0.7, 0.8, 1)
	love.graphics.line(0, 360, 512, 360)
	for i = rules.next_index, #rules.chart.objects do
		local object = rules.chart.objects[i]
		local left = object.time - re.visual_info.time
		if left > rules.preempt then break end
		local y = 360 - left / rules.preempt * 340
		local radius = 9
		if object.kind == "tiny" then Painter.setColorRgb(0.5, 0.8, 1); radius = 3
		elseif object.kind == "droplet" then Painter.setColorRgb(0.4, 0.7, 1); radius = 6
		elseif object.kind == "banana" then Painter.setColorRgb(1, 0.85, 0.2)
		else Painter.setColorRgb(1, 0.4, 0.4) end
		love.graphics.circle("fill", object.x, y, radius)
		if rules.hyper_targets[i] then
			Painter.setColorRgb(1, 1, 1)
			love.graphics.circle("line", object.x, y, radius + 3)
		end
	end
	if rules.time < rules.hyper_until then Painter.setColorRgb(1, 0.3, 0.8)
	elseif rules:isDash() then Painter.setColorRgb(1, 0.85, 0.2)
	else Painter.setColorRgb(0.4, 1, 0.65) end
	love.graphics.setLineWidth(10)
	love.graphics.line(rules.x - rules.half_width, 365, rules.x + rules.half_width, 365)
	Painter.setColorRgb(1, 1, 1)
	love.graphics.print(("Catch | Hit %d / Miss %d | Extras %d / %d"):format(rules.hits, rules.misses, rules.bonus_hits, rules.bonus_misses), 0, -25)
	love.graphics.print("Left/Right or A/D | Shift: dash", 0, 400)
	love.graphics.pop()
end

return CatchPlayfield
