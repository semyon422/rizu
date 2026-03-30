local View = require("ui.View")

---@class yi.LabelParams
---@field font love.Font
---@field text string?
---@field color ui.Color

---@class yi.Label : ui.View
---@operator call: yi.Label
local Label = View + {}

---@param params yi.LabelParams
function Label:new(params)
	View.new(self)
	self.font = assert(params.font, "Font is required")
	self.color = assert(params.color, "Color is required")
	self.text = params.text

	self.text_batch = love.graphics.newText(self.font, self.text)
	self.color = params.color

	self:setSize(self.text_batch:getDimensions())
end

function Label:updateTransform()
	View.updateTransform(self)
	local x, y = self.transform:transformPoint(0, 0)
	self.transform:translate(math.floor(x) - x, math.floor(y) - y)
end

function Label:draw()
	love.graphics.setColor(self.color)
	love.graphics.draw(self.text_batch, 0.5)
end

return Label
