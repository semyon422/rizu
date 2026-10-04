local View = require("rizu.skin.View")

local lg = love.graphics
local PROGRESS_VIEW_SIZE = 24
local PROGRESS_RADIUS = 10
local SPRITE_SCALE = 480 / 768
local PROGRESS_POSITION_OFFSET = 24
local NEGATIVE_PROGRESS_COLOR = {0.78, 1, 0.18, 0.6}
local POSITIVE_PROGRESS_COLOR = {1, 1, 1, 0.6}

---@class rizu.skin.osu.mania.views.OsuManiaProgressView : rizu.skin.View
---@operator call: rizu.skin.osu.mania.views.OsuManiaProgressView
---@field progress number
---@field graphics rizu.skin.osu.mania.OsuManiaSkinGraphics?
---@field progress_image love.Image?
local OsuManiaProgressView = View + {}

---@param graphics rizu.skin.osu.mania.OsuManiaSkinGraphics?
function OsuManiaProgressView:new(graphics)
	self.graphics = graphics
	self.progress_image = nil
	self.progress = 0
	View.new(self, {
		anchor = "top_right",
		origin = "center",
		x = -20,
		y = 18,
		width = PROGRESS_VIEW_SIZE,
		height = PROGRESS_VIEW_SIZE,
	})
end

---@param accuracy_view rizu.skin.osu.mania.views.OsuManiaAccuracyView
function OsuManiaProgressView:setAccuracyView(accuracy_view)
	-- osu! positions the pie 24 pixels to the left of the accuracy
	-- display's left edge (ScoreDisplay.LeftOfDisplay).
	self.x = accuracy_view.x - accuracy_view.width - PROGRESS_POSITION_OFFSET
	self.y = accuracy_view.y + accuracy_view.height / 2
end

---@param game sphere.GameController
function OsuManiaProgressView:load(game)
	View.load(self, game)
	local graphics = self.graphics
	local frames = graphics and graphics.getFallbackFrames
		and graphics:getFallbackFrames("circularmetre") or nil
	self.progress_image = frames and frames[1] or nil
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
	if not self.progress_image and self.graphics then
		local frames = self.graphics:getFallbackFrames("circularmetre")
		self.progress_image = frames[1]
	end
	local cx, cy, radius = self.width / 2, self.height / 2, PROGRESS_RADIUS
	local previous_mode, previous_alpha = lg.getBlendMode()
	lg.setBlendMode("add", "alphamultiply")
	lg.setColor(1, 1, 1, 0.16)
	lg.circle("line", cx, cy, radius)
	if self.progress ~= 0 then
		local color = self.progress < 0 and NEGATIVE_PROGRESS_COLOR or POSITIVE_PROGRESS_COLOR
		lg.setColor(color[1], color[2], color[3], color[4])
		local angle = math.min(math.abs(self.progress), 1) * math.pi * 2
		local segments = math.max(2, math.ceil(angle * 10))
		lg.arc("fill", "pie", cx, cy, radius, -math.pi / 2, -math.pi / 2 + angle, segments)
	end
	if self.progress_image then
		local width, height = self.progress_image:getDimensions()
		lg.setColor(1, 1, 1, 1)
		lg.draw(self.progress_image, cx, cy, 0, SPRITE_SCALE, SPRITE_SCALE, width / 2, height / 2)
	end
	lg.setBlendMode(previous_mode, previous_alpha)
end

return OsuManiaProgressView
