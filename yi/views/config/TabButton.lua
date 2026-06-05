local View = require("gui.View")
local Resources = require("yi.Resources")

---@class yi.ConfigTabButton : gui.View
---@operator call: yi.ConfigTabButton
local TabButton = View + {}

local padding_x = 24
local padding_y = 6
local padding_x_half = padding_x / 2
local padding_y_half = padding_y / 2

---@param text_batch love.TextBatch
---@param text string
---@param on_click fun(self: yi.ConfigTabButton)
function TabButton:new(text_batch, text, on_click)
	View.new(self)
	self.text_batch = text_batch
	self.text = text
	self.on_click = on_click
	self.handles_mouse_input = true
	self.active = false

	self:setWidth(text_batch:getFont():getWidth(self.text) + padding_x)
	self:setHeight(text_batch:getFont():getHeight() + padding_y)
end

function TabButton:onMouseDown(e)
	self.on_click(self)
	return true
end

local lg = love.graphics
local white = {1, 1, 1, 1}
local black = {0, 0, 0, 1}
local colored_string = {white, ""}

function TabButton:draw()
	local atlas, quads = Resources.atlas, Resources.quads
	colored_string[2] = self.text
	local _, _, iw, ih = quads.pill_cap:getViewport()

	if self.active then
		lg.setColor(0, 0, 0, 1)
		lg.scale(0.5)
		lg.draw(atlas, quads.pill_cap)
		lg.draw(atlas, quads.pixel, iw, 0, 0, (self.width - iw) * 2, self.height * 2)
		lg.draw(atlas, quads.pill_cap, self.width * 2, 0, 0, -1, 1)
		colored_string[1] = white
	else
		colored_string[1] = black
	end

	self.text_batch:addf(colored_string, self.width, "center", self.x, padding_y_half + self.y)
end

return TabButton
