local View = require("gui.View")
local loop = require("rizu.loop.Loop")
local Settings = require("rizu.config.schemas.Settings")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

local WIDTH = 240
local HEIGHT = 144
local PADDING = 12

---@class ui.views.FpsView : gui.View
---@operator call: ui.views.FpsView
---@field game sphere.GameController
---@field font love.Font
---@field fps integer
local FpsView = View + {}

---@param game sphere.GameController
function FpsView:new(game)
	View.new(self)
	self.game = game
	self.font = Resources.getFont("regular", 20)
	self.fps = 0
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
end

function FpsView:draw()
	local timings = loop.timings
	Painter.setColorRgb(0, 0, 0, 0.75)
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
