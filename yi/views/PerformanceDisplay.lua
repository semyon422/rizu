local View = require("ui.View")
local Colors = require("yi.Colors")
local Painter = require("yi.Painter")

---@class yi.PerformanceDisplay : ui.View
---@overload fun(resources: yi.Resources, game: sphere.GameController): yi.PerformanceDisplay
local PerformanceDisplay = View + {}

PerformanceDisplay.padding_x = 12
PerformanceDisplay.padding_y = 10
PerformanceDisplay.margin_top = 16
PerformanceDisplay.margin_right = 16
PerformanceDisplay.font_name = "regular"
PerformanceDisplay.font_size = 24

---@param fps integer
---@param delta number
---@return string
function PerformanceDisplay.formatStats(fps, delta)
	return ("%dfps\n%0.1fms"):format(fps, delta * 1000)
end

---@param resources yi.Resources
---@param game sphere.GameController
function PerformanceDisplay:new(resources, game)
	View.new(self)
	self.resources = assert(resources)
	self.game = assert(game)
	self.pivot = {1, 0}
	self.x = -PerformanceDisplay.margin_right
	self.y = PerformanceDisplay.margin_top
	self.font_name = PerformanceDisplay.font_name
	self.font_size = PerformanceDisplay.font_size
	self.padding_x = PerformanceDisplay.padding_x
	self.padding_y = PerformanceDisplay.padding_y
	self.text = ""
	self.text_width = 0
	self.text_height = 0
	self.font = nil
	self.text_batch = nil
	self.background_color = Colors.black_50
	self.text_color = Colors.white_90
end

function PerformanceDisplay:onLayoutUpdate()
	self.font = self.resources:getScaledFont(self.font_name, self.font_size, self.ui_scale)
end

---@return boolean
function PerformanceDisplay:isEnabled()
	return self.game.configModel.configs.settings.miscellaneous.showFPS
end

function PerformanceDisplay:update(_dt)
	self.visible = self:isEnabled()
	if not self.visible then
		return
	end

	local fps = love.timer.getFPS()
	local delta = love.timer.getDelta()
	self.text = self.formatStats(fps, delta)
	self.text_batch = love.graphics.newText(self.font, self.text)

	local width = math.max(
		self.font:getWidth(("%dfps"):format(fps)),
		self.font:getWidth(("%0.1fms"):format(delta * 1000))
	)
	local height = self.font:getHeight() * 2
	self.text_width = width
	self.text_height = height
	self:setSize(
		self:toLogicalSize(width + self.padding_x * 2),
		self:toLogicalSize(height + self.padding_y * 2)
	)
	self:updateTransform()
end

function PerformanceDisplay:draw()
	if not self.visible then
		return
	end

	local lg = love.graphics
	lg.setColor(self.background_color)
	lg.rectangle("fill", 0, 0, self.width, self.height)

	lg.setFont(self.font)
	lg.setColor(self.text_color)
	Painter.drawText(
		self.text_batch,
		self.width - self:toLogicalSize(self.padding_x) - self:toLogicalSize(self.text_width),
		self:toLogicalSize(self.padding_y)
	)
end

return PerformanceDisplay
