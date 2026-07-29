local View = require("gui.View")
local loop = require("rizu.loop.Loop")
local Settings = require("rizu.config.schemas.Settings")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

local WIDTH = 240
local HEIGHT = 144
local PADDING = 12
local HITCH_MIN_FRAME_TIME = 0.004
local HITCH_BASELINE_MULTIPLIER = 1.75
local HITCH_HIGHLIGHT_DURATION = 0.032
local BASELINE_ALPHA = 0.05

---@class ui.views.FpsView : gui.View
---@operator call: ui.views.FpsView
---@field game sphere.GameController
---@field font love.Font
---@field fps integer
---@field frame_time_baseline number
---@field hitch_highlight_remaining number
local FpsView = View + {}

---@param game sphere.GameController
function FpsView:new(game)
	View.new(self)
	self.game = game
	self.font = Resources.getFont("regular", 20)
	self.fps = 0
	self.frame_time_baseline = 0
	self.hitch_highlight_remaining = 0
	self:setSize(WIDTH, HEIGHT)
	self:setVisible(game.settings:getBoolean(Settings.misc.application.show_fps))
end

---@param dt number
function FpsView:update(dt)
	local show_fps = self.game.settings:getBoolean(Settings.misc.application.show_fps)
	if self.visible ~= show_fps then
		self:setVisible(show_fps)
	end
	if not show_fps then
		return
	end

	self.fps = dt > 0 and math.floor(1 / dt + 0.5) or 0
	self.hitch_highlight_remaining = math.max(self.hitch_highlight_remaining - dt, 0)

	local baseline = self.frame_time_baseline
	if baseline > 0 and dt > HITCH_MIN_FRAME_TIME and dt > baseline * HITCH_BASELINE_MULTIPLIER then
		self.hitch_highlight_remaining = HITCH_HIGHLIGHT_DURATION
	end
	self.frame_time_baseline = baseline == 0 and dt or baseline * (1 - BASELINE_ALPHA) + dt * BASELINE_ALPHA
end

function FpsView:draw()
	local timings = loop.timings
	if self.hitch_highlight_remaining > 0 then
		Painter.setColorRgb(0.8, 0, 0, 0.85)
	else
		Painter.setColorRgb(0, 0, 0, 0.75)
	end
	love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.font)
	love.graphics.print((
		"FPS      %4d\n" ..
		"event    %6.2f ms\n" ..
		"update   %6.2f ms\n" ..
		"draw     %6.2f ms\n" ..
		"present  %6.2f ms"
	):format(
		self.fps,
		timings.event * 1000,
		timings.update * 1000,
		timings.draw * 1000,
		timings.present * 1000
	), PADDING, PADDING)
end

return FpsView
