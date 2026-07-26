local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Color = require("ui.Color")

---@class ui.screens.song_select.TimeRate : gui.View
---@operator call: ui.screens.song_select.TimeRate
---@field model sphere.TimeRateModel?
---@field orbit_r number
local TimeRate = View + {}

---@param time_rate_model sphere.TimeRateModel
---@param modifier_select_model sphere.ModifierSelectModel
function TimeRate:new(time_rate_model, modifier_select_model)
	View.new(self)

	self.time_rate_model = time_rate_model
	self.modifier_select_model = modifier_select_model
	self.circle_quad = Resources.quads.rate_circle
	self.thumb_quad = Resources.quads.rate_thumb

	self.circle_w = Painter.getQuadWidth(self.circle_quad)
	self.circle_h = Painter.getQuadHeight(self.circle_quad)
	self.thumb_w = Painter.getQuadWidth(self.thumb_quad)
	self.thumb_h = Painter.getQuadHeight(self.thumb_quad)
	self.font = Resources.getFont("bold", 24)

	self:setSize(140, 50)
	self.orbit_r = math.floor(self.circle_w / 2) - 2
	self.handles_mouse_input = true
	self.text_color = {1, 1, 1, 1}
	self.text = "1.00x"
end

function TimeRate:load()
	self:updateText()
end

function TimeRate:onScroll(e)
	self.time_rate_model:increase(e.direction_y)
	self.modifier_select_model:change()
	self:updateText()
	return true
end

function TimeRate:updateText()
	Color.linearRateToColor(self.time_rate_model:get(), self.text_color)
	self.text = ("%0.02fx"):format(self.time_rate_model:get())
end

function TimeRate:draw()
	local cx, cy = self.width - self.circle_w - 10, (self.height - self.circle_h) / 2

	local model = self.time_rate_model
	local value = model:get()
	local range = model.range[model.replayBase.rate_type]
	local normalized = (value - range[1]) / (range[2] - range[1])
	local angle = normalized * math.pi * 2

	Painter.setColorTable(Colors.elements)
	love.graphics.draw(Resources.atlas, Resources.quads.time_rate_bg)
	Painter.setColorRgb(1, 1, 1)
	love.graphics.draw(Resources.atlas, self.circle_quad, cx, cy)
	love.graphics.draw(
		Resources.atlas,
		self.thumb_quad,
		cx + math.sin(angle) * self.orbit_r + self.circle_w / 2,
		cy - math.cos(angle) * self.orbit_r + self.circle_h / 2,
		0,
		1,
		1,
		2.5,
		2.5
	)

	love.graphics.setFont(self.font)
	Painter.setColorTable(self.text_color)
	love.graphics.print(self.text, 15, 11)
end

return TimeRate
