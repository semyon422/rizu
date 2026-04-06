local View = require("ui.View")
local Painter = require("yi.Painter")

---@class yi.config.GroupLabelParams
---@field resources yi.Resources
---@field font_name yi.FontName
---@field font_size integer
---@field text string
---@field color ui.Color
---@field marker_text string
---@field marker_color ui.Color
---@field marker_alpha_scale number
---@field gap number

---@class yi.config.GroupLabel : ui.View
---@overload fun(params: yi.config.GroupLabelParams): yi.config.GroupLabel
---@field font love.Font
---@field resources yi.Resources
---@field font_name yi.FontName
---@field font_size integer
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

---@private
function GroupLabel:rebuild()
	self.font = self.resources:getScaledFont(self.font_name, self.font_size, self.ui_scale)
	local marker_color = scale_color_alpha(self.marker_color, self.marker_alpha_scale)
	self.text_batch = love.graphics.newText(self.font)
	self.text_batch:setf({
		marker_color, self.marker_text,
		self.color, string.rep(" ", self.gap) .. self.text,
	}, math.huge, "left")

	local width, height = self.text_batch:getDimensions()
	self:setSize(self:toLogicalSize(width), self:toLogicalSize(height))
end

---@param params yi.config.GroupLabelParams
function GroupLabel:new(params)
	View.new(self)
	self.resources = assert(params.resources, "GroupLabel resources are required")
	self.font_name = assert(params.font_name, "GroupLabel font_name is required")
	self.font_size = assert(params.font_size, "GroupLabel font_size is required")
	self.text = assert(params.text, "Text is required")
	self.color = assert(params.color, "Color is required")
	self.marker_text = assert(params.marker_text, "Marker text is required")
	self.marker_color = assert(params.marker_color, "Marker color is required")
	self.marker_alpha_scale = assert(params.marker_alpha_scale, "Marker alpha scale is required")
	self.gap = assert(params.gap, "Gap is required")
	self:rebuild()
end

function GroupLabel:onLayoutUpdate()
	self:rebuild()
end

function GroupLabel:draw()
	love.graphics.setColor(1, 1, 1, 1)
	Painter.drawText(self.text_batch, 0, 0)
end

return GroupLabel
