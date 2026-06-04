local View = require("gui.View")

---@class yi.LabelParams
---@field resources yi.Resources
---@field font_name yi.FontName
---@field font_size integer
---@field text string
---@field color gui.Color

---@class yi.Label : gui.View
---@operator call: yi.Label
local Label = View + {}

---@param params yi.LabelParams
function Label:new(params)
	View.new(self)
	self.resources = assert(params.resources, "Label resources are required")
	self.font_name = assert(params.font_name, "Label font_name is required")
	self.font_size = assert(params.font_size, "Label font_size is required")
	self.color = assert(params.color, "Color is required")
	self.text = assert(params.text, "Label text is required")
	self.font = self.resources:getFont(self.font_name, self.font_size)
	self.text_batch = love.graphics.newTextBatch(self.font, self.text)
	self:setWidth(self.text_batch:getWidth())
	self:setHeight(self.text_batch:getHeight())
end

---@param text string
function Label:setText(text)
	self.text = text
	self.text_batch:set(text)
end

local lg = love.graphics

function Label:draw()
	local screen_x, screen_y = lg.transformPoint(0, 0)
	lg.setColor(self.color)
	lg.draw(self.text_batch, math.floor(screen_x + 0.5) - screen_x, math.floor(screen_y + 0.5) - screen_y)
end

return Label
