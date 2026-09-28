local View = require("rizu.skin.View")

local lg = love.graphics

---@class rizu.skin.osu.mania.OsuManiaProgressView : rizu.skin.View
---@operator call: rizu.skin.osu.mania.OsuManiaProgressView
---@field progress number
local OsuManiaProgressView = View + {}

function OsuManiaProgressView:new()
	self.progress = 0
	View.new(self, {anchor = "top_right", origin = "center", x = -20, y = 18, width = 24, height = 24})
end

---@param dt number
---@param game sphere.GameController
function OsuManiaProgressView:update(dt, game)
	local engine = game and game.rhythm_engine
	self.progress = engine and engine.getProgress and engine:getProgress() or 0
	if type(self.progress) ~= "number" or self.progress ~= self.progress then self.progress = 0 end
	self.progress = math.max(-1, math.min(1, self.progress))
end

function OsuManiaProgressView:draw()
	local cx, cy, radius = self.width / 2, self.height / 2, 10
	local previous_mode, previous_alpha = lg.getBlendMode()
	lg.setBlendMode("add", "alphamultiply")
	lg.setColor(1, 1, 1, 0.16)
	lg.circle("line", cx, cy, radius)
	if self.progress ~= 0 then
		local color = self.progress < 0 and {0.78, 1, 0.18, 0.6} or {1, 1, 1, 0.6}
		lg.setColor(color)
		local angle = math.min(math.abs(self.progress), 1) * math.pi * 2
		local segments = math.max(2, math.ceil(angle * 10))
		lg.arc("fill", "pie", cx, cy, radius, -math.pi / 2, -math.pi / 2 + angle, segments)
	end
	lg.setBlendMode(previous_mode, previous_alpha)
end

return OsuManiaProgressView
