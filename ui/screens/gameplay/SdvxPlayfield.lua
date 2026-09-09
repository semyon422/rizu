local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---@class ui.screens.gameplay.SdvxPlayfield: gui.View
---@operator call: ui.screens.gameplay.SdvxPlayfield
local SdvxPlayfield = View + {}

---@param game sphere.GameController
function SdvxPlayfield:new(game)
	View.new(self)
	self.game = game
end

function SdvxPlayfield:draw()
	local re = self.game.rhythm_engine
	local rules = re and re.sdvx_rules
	if not rules then return end
	love.graphics.push("all")
	Painter.setColorRgb(0.04, 0.05, 0.08)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
	local scale = math.min(self.width / 800, self.height / 600)
	love.graphics.translate((self.width - 800 * scale) / 2, (self.height - 600 * scale) / 2)
	love.graphics.scale(scale)
	love.graphics.setFont(Resources.getFont("regular", 16))
	local time = re.visual_info.time
	---@param t number
	---@return number
	local function y(t) return 480 - (t - time) / rules.preempt * 390 end
	Painter.setColorRgb(0.3, 0.35, 0.45)
	love.graphics.setLineWidth(2)
	for lane = 0, 4 do love.graphics.line(240 + lane * 80, 80, 240 + lane * 80, 480) end
	for pass = 1, 2 do
		for i = rules.button_rules.first_index, #rules.chart.buttons do
			local object, state = rules.chart.buttons[i], rules.button_rules.states[i]
			if object.time > time + rules.preempt then break end
			if not state.result and (object.lane > 4) == (pass == 1) then
				local lane = object.lane
				local x = lane <= 4 and 240 + (lane - 1) * 80 or 240 + (lane - 5) * 160
				local width = lane <= 4 and 72 or 152
				if state.failed then Painter.setColorRgb(0.5, 0.2, 0.2)
				elseif lane <= 4 then Painter.setColorRgb(0.9, 0.95, 1) else Painter.setColorRgb(1, 0.65, 0.2) end
				local bottom, top = math.min(480, y(object.time)), math.max(80, y(object.end_time))
				if object.kind == "chip" then top = bottom - 8 end
				if bottom >= 80 then Resources.sprites.pixel:draw(x + 4, top, 0, width, math.max(5, bottom - top)) end
			end
		end
	end
	local tick_hits, tick_misses, slam_hits, slam_misses = 0, 0, 0, 0
	for _, laser in ipairs(rules.lasers) do
		local chain = laser.chain
		tick_hits, tick_misses = tick_hits + laser.hits, tick_misses + laser.misses
		slam_hits, slam_misses = slam_hits + laser.slam_hits, slam_misses + laser.slam_misses
		---@param pos number
		---@return number
		local function x(pos) return 240 + (chain.extended and (pos * 2 - 0.5) or pos) * 320 end
		if chain.lane == 1 then Painter.setColorRgb(0.2, 0.7, 1) else Painter.setColorRgb(1, 0.3, 0.75) end
		love.graphics.setLineWidth(7)
		for _, segment in ipairs(chain.segments) do
			if segment.time > time + rules.preempt then break end
			if segment.end_time >= time - 0.08 then
				local a, b = math.max(segment.time, time), math.min(segment.end_time, time + rules.preempt)
				local duration = segment.end_time - segment.time
				local from = duration > 0 and segment.from + (segment.to - segment.from) * (a - segment.time) / duration or segment.from
				local to = duration > 0 and segment.from + (segment.to - segment.from) * (b - segment.time) / duration or segment.to
				love.graphics.line(x(from), y(a), x(to), y(b))
			end
		end
		local segments = chain.segments
		if time >= segments[1].time and time <= segments[#segments].end_time + 0.075 then
			love.graphics.circle(laser.captured and "fill" or "line", x(laser.position), 480, 11)
		end
	end
	Painter.setColorRgb(1, 1, 1)
	love.graphics.setLineWidth(2)
	love.graphics.line(200, 480, 600, 480)
	love.graphics.print(("SDVX | Buttons %d/%d | Laser %d/%d | Slam %d/%d"):format(rules.hits, rules.misses, tick_hits, tick_misses, slam_hits, slam_misses), 40, 25)
	for lane = 1, 6 do
		if rules.button_rules.buttons[lane] then
			Painter.setColorRgb(1, 0.85, 0.3)
			local x = lane <= 4 and 280 + (lane - 1) * 80 or 320 + (lane - 5) * 160
			love.graphics.circle("fill", x, lane <= 4 and 500 or 514, 6)
		end
	end
	Painter.setColorRgb(1, 1, 1)
	love.graphics.print("BT: D F J K | FX: C M | Lasers: W E / O P", 160, 530)
	local warnings = rules.chart.warnings
	if #warnings > 0 then love.graphics.printf(table.concat(warnings, "\n"), 40, 560, 720) end
	love.graphics.pop()
end

return SdvxPlayfield
