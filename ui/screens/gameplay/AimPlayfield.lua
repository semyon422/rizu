local Spinner = require("rizu.gameplay.aim.Spinner")
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
	local objects = rules.objects
	local last_visible = 0
	for i, object in ipairs(objects) do
		if object.time - time > rules.preempt then break end
		last_visible = i
	end
	-- Earlier heads must remain on top of later members of a stack.
	for i = last_visible, 1, -1 do
		local object = objects[i]
		local spinner = rules.spinners[i]
		if spinner and not rules.states[i] then
			local x, y = Spinner.center_x, Spinner.center_y
			local progress = math.min(1, spinner:getTurns() / spinner.required_turns)
			Painter.setColorRgb(0.12, 0.2, 0.3)
			love.graphics.circle("fill", x, y, 150)
			Painter.setColorRgb(0.8, 0.9, 1)
			love.graphics.circle("line", x, y, 150)
			local remaining = math.max(0, math.min(1, (spinner.end_time - time) / (spinner.end_time - spinner.start_time)))
			love.graphics.circle("line", x, y, 40 + 100 * remaining)
			Painter.setColorRgb(0.3, 1, 0.6)
			if progress > 0 then love.graphics.arc("line", "open", x, y, 155, -math.pi / 2, -math.pi / 2 + 2 * math.pi * progress) end
			love.graphics.printf(("SPIN — hold + rotate\n%.1f / %.1f turns"):format(spinner:getTurns(), spinner.required_turns), x - 140, y - 20, 280, "center")
			Painter.setColorRgb(1, 0.8, 0.3)
			love.graphics.circle("line", x, y, Spinner.dead_radius)
			local angle = spinner.last_angle or 0
			love.graphics.line(x, y, x + 100 * math.cos(angle), y + 100 * math.sin(angle))
		end
		local slider = rules.sliders[i]
		if slider and not rules.states[i] then
			local points = slider.path.points
			love.graphics.setLineWidth(rules.radius * 2)
			Painter.setColorRgb(0.16, 0.33, 0.46)
			for j = 2, #points do
				love.graphics.line(points[j - 1][1], points[j - 1][2], points[j][1], points[j][2])
			end
			for _, p in ipairs(points) do love.graphics.circle("fill", p[1], p[2], rules.radius) end
			love.graphics.setLineWidth(2)
			Painter.setColorRgb(0.85, 0.95, 1)
			for _, checkpoint in ipairs(slider.timing.checkpoints) do
				if checkpoint.time >= time then
					local x, y = slider.path:position(checkpoint.progress)
					if checkpoint.kind == "tick" then love.graphics.circle("fill", x, y, 4)
					elseif checkpoint.kind == "repeat" then love.graphics.circle("line", x, y, rules.radius * 0.6) end
				end
			end
			if time >= object.time then
				local x, y = slider.path:position(slider.timing:progress(time))
				Painter.setColorRgb(1, 0.75, 0.2)
				love.graphics.circle("line", x, y, rules.radius)
				love.graphics.circle("fill", x, y, 6)
				Painter.setColorRgb(1, 0.85, 0.5, 0.3)
				love.graphics.circle("line", x, y, rules.radius * 2.4)
			end
		end
		if not spinner and not rules.heads[i] then
			Painter.setColorRgb(0.16, 0.4, 0.58)
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
		local x, y = object.x, object.y
		if object.kind == "spinner" then x, y = Spinner.center_x, Spinner.center_y end
		if event.hit then Painter.setColorRgb(0.3, 1, 0.5, 1 - age / 0.4)
		else Painter.setColorRgb(1, 0.3, 0.3, 1 - age / 0.4) end
		love.graphics.printf(event.hit and "HIT" or "MISS", x - 40, y - 10, 80, "center")
	end
	Painter.setColorRgb(1, 0.85, 0.2)
	love.graphics.circle("line", rules.x, rules.y, 9)
	love.graphics.circle("fill", rules.x, rules.y, 3)
	Painter.setColorRgb(1, 1, 1)
	love.graphics.print(("Aim — experimental | Hit %d / Miss %d | Ticks %d / %d"):format(rules.hits, rules.misses, rules.checkpoint_hits, rules.checkpoint_misses), 0, -36)
	local state = self.game.pauseModel.state
	love.graphics.print("Z / X or mouse buttons | " .. state, 0, 400)
	love.graphics.pop()
end

return AimPlayfield
