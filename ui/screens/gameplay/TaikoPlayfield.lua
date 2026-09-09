local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.screens.gameplay.TaikoPlayfield: gui.View
---@operator call: ui.screens.gameplay.TaikoPlayfield
local TaikoPlayfield = View + {}

---@param game sphere.GameController
function TaikoPlayfield:new(game)
	View.new(self)
	self.game = game
end

function TaikoPlayfield:draw()
	local re = self.game.rhythm_engine
	local rules = re and re.taiko_rules
	if not rules then return end
	love.graphics.push("all")
	Painter.setColorRgb(0.04, 0.05, 0.08)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
	local scale = math.min(self.width / 800, self.height / 450)
	love.graphics.translate((self.width - 800 * scale) / 2, (self.height - 450 * scale) / 2)
	love.graphics.scale(scale)
	love.graphics.setFont(Resources.getFont("regular", 16))
	Painter.setColorRgb(0.7, 0.8, 1)
	love.graphics.setLineWidth(2)
	love.graphics.line(80, 210, 760, 210)
	love.graphics.circle("line", 100, 210, 28)
	local time = re.visual_info.time
	for i = rules.first_index, #rules.chart.objects do
		local object, state = rules.chart.objects[i], rules.states[i]
		if object.time > time + rules.preempt then break end
		if not state.result then
			local x = 100 + (object.time - time) / rules.preempt * 640
			if object.kind == "note" then
				if object.color == "don" then Painter.setColorRgb(1, 0.35, 0.35) else Painter.setColorRgb(0.35, 0.7, 1) end
				love.graphics.circle("fill", x, 210, object.big and 25 or 17)
				if state.first_time then
					Painter.setColorRgb(1, 1, 1)
					love.graphics.circle("line", x, 210, 29)
				end
			else
				local ending = math.min(760, 100 + (object.end_time - time) / rules.preempt * 640)
				x = math.max(100, x)
				if object.kind == "roll" then Painter.setColorRgb(1, 0.8, 0.25) else Painter.setColorRgb(0.75, 0.4, 1) end
				love.graphics.setLineWidth(object.big and 28 or 18)
				love.graphics.line(x, 210, ending, 210)
				love.graphics.print(("%s %d/%d"):format(object.kind, state.count, object.target), x, 250)
			end
		end
	end
	Painter.setColorRgb(1, 1, 1)
	love.graphics.print(("Taiko | Hit %d / Miss %d | Double %d / Single %d"):format(rules.hits, rules.misses, rules.doubles, rules.singles), 40, 40)
	local labels = {"F: don L", "J: don R", "D: kat L", "K: kat R"}
	for id, text in ipairs(labels) do
		if rules.buttons[id] then Painter.setColorRgb(1, 0.85, 0.3) else Painter.setColorRgb(0.7, 0.75, 0.85) end
		love.graphics.print(text, 70 + (id - 1) * 180, 360)
	end
	love.graphics.pop()
end

return TaikoPlayfield
