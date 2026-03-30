local View = require("ui.View")

---@class yi.config.GroupLabelParams
---@field font love.Font
---@field text string
---@field color ui.Color
---@field marker_text string
---@field marker_color ui.Color
---@field marker_alpha_scale number
---@field gap number

---@class yi.config.GroupLabel : ui.View
---@overload fun(params: yi.config.GroupLabelParams): yi.config.GroupLabel
---@field font love.Font
---@field text string
---@field color ui.Color
---@field marker_text string
---@field marker_color ui.Color
---@field marker_alpha_scale number
---@field gap number
---@field text_batch love.Text
local GroupLabel = View + {}

---@param color ui.Color
---@param alpha_scale number
---@return ui.Color
local function scale_color_alpha(color, alpha_scale)
	return {color[1], color[2], color[3], (color[4] or 1) * alpha_scale}
end

---@param params yi.config.GroupLabelParams
function GroupLabel:new(params)
	View.new(self)
	self.font = assert(params.font, "Font is required")
	self.text = assert(params.text, "Text is required")
	self.color = assert(params.color, "Color is required")
	self.marker_text = assert(params.marker_text, "Marker text is required")
	self.marker_color = assert(params.marker_color, "Marker color is required")
	self.marker_alpha_scale = params.marker_alpha_scale or 0.65
	self.gap = assert(params.gap, "Gap is required")

	local marker_color = scale_color_alpha(self.marker_color, self.marker_alpha_scale)
	self.text_batch = love.graphics.newText(self.font)
	self.text_batch:setf({
		marker_color, self.marker_text,
		self.color, string.rep(" ", self.gap) .. self.text,
	}, math.huge, "left")

	local width, height = self.text_batch:getDimensions()
	self:setSize(width, height)
end

function GroupLabel:updateTransform()
	View.updateTransform(self)
	local x, y = self.transform:transformPoint(0, 0)
	self.transform:translate(math.floor(x) - x, math.floor(y) - y)
end

function GroupLabel:draw()
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.text_batch, 0, 0)
end

return GroupLabel
