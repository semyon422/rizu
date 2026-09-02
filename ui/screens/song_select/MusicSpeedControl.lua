local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Color = require("ui.Color")

---@class ui.screens.song_select.MusicSpeedControl : gui.View
---@operator call: ui.screens.song_select.MusicSpeedControl
---@field time_rate_model sphere.TimeRateModel
---@field modifier_select_model sphere.ModifierSelectModel
local MusicSpeedControl = View + {}

local DRAG_RANGE = 360
local MIN_RATE = 0.25
local MAX_RATE = 4
local STEP = 0.05

---@param time_rate_model sphere.TimeRateModel
---@param modifier_select_model sphere.ModifierSelectModel
function MusicSpeedControl:new(time_rate_model, modifier_select_model)
	View.new(self)
	self.time_rate_model = time_rate_model
	self.modifier_select_model = modifier_select_model
	self.circle = Resources.sprites.rate_circle
	self.thumb = Resources.sprites.rate_thumb
	self.circle_w, self.circle_h = self.circle:getDimensions()
	self.orbit_r = math.floor(self.circle_w / 2) - 2
	self.value_font = Resources.getFont("bold", 24)
	self.text_color = {1, 1, 1, 1}
	self.handles_mouse_input = true
	self.drag_axis = "horizontal"
	self:setSize(148, 64)
end

---@param rate number
function MusicSpeedControl:setRate(rate)
	rate = math.max(MIN_RATE, math.min(MAX_RATE, math.floor(rate / STEP + 0.5) * STEP))
	if self.time_rate_model.replayBase.rate_type == "exp" then
		self.time_rate_model:set(math.log(rate) / math.log(2) * 10)
	else
		self.time_rate_model:set(rate)
	end
	self.modifier_select_model:change()
end

---@return number rate
function MusicSpeedControl:getRate()
	return self.time_rate_model.replayBase.rate
end

---@param e gui.ScrollEvent
function MusicSpeedControl:onScroll(e)
	self:setRate(self:getRate() + (e.direction_y > 0 and STEP or -STEP))
	return true
end

---@param e gui.DragStartEvent
function MusicSpeedControl:onDragStart(e)
	if e.button ~= 1 then return end
	self.drag_start_x = e.press_x or e.x
	self.drag_start_rate = self:getRate()
	return true
end

---@param e gui.DragEvent
function MusicSpeedControl:onDrag(e)
	if e.button ~= 1 or not self.drag_start_x then return end
	self:setRate(self.drag_start_rate + (e.x - self.drag_start_x) / DRAG_RANGE * (MAX_RATE - MIN_RATE))
	return true
end

function MusicSpeedControl:draw()
	local rate = self:getRate()
	local circle_x = self.width - self.circle_w - 15
	local circle_y = (self.height - self.circle_h) / 2
	local progress = (rate - MIN_RATE) / (MAX_RATE - MIN_RATE)
	local angle = progress * math.pi * 2

	Painter.setColorRgb(1, 1, 1)
	self.circle:draw(circle_x, circle_y)
	self.thumb:draw(
		circle_x + math.sin(angle) * self.orbit_r + self.circle_w / 2,
		circle_y - math.cos(angle) * self.orbit_r + self.circle_h / 2,
		0,
		1,
		1,
		2.5,
		2.5
	)

	local value = ("%.2fx"):format(self:getRate())
	Color.linearRateToColor(rate, self.text_color)
	Painter.setColorTable(self.text_color)
	love.graphics.setFont(self.value_font)
	Painter.snapToPixel()
	local text_x = (circle_x - self.value_font:getWidth(value)) / 2
	local text_y = (self.height - self.value_font:getHeight()) / 2
	love.graphics.print(value, text_x, text_y)
end

return MusicSpeedControl
