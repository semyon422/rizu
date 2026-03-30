local View = require("ui.View")

---@class yi.config.SectionLabelParams
---@field font love.Font
---@field text string
---@field color ui.Color
---@field accent_color ui.Color
---@field accent_width number
---@field accent_height number
---@field gap number

---@class yi.config.SectionLabel : ui.View
---@overload fun(params: yi.config.SectionLabelParams): yi.config.SectionLabel
---@field font love.Font
---@field text string
---@field color ui.Color
---@field accent_color ui.Color
---@field accent_width number
---@field accent_height number
---@field gap number
---@field blink_period number
---@field blink_min_alpha number
---@field blink_offset number
---@field text_batch love.Text
local SectionLabel = View + {}

---@param params yi.config.SectionLabelParams
function SectionLabel:new(params)
	View.new(self)
	self.font = assert(params.font, "Font is required")
	self.text = assert(params.text, "Text is required")
	self.color = assert(params.color, "Color is required")
	self.accent_color = assert(params.accent_color, "Accent color is required")
	self.accent_width = assert(params.accent_width, "Accent width is required")
	self.accent_height = assert(params.accent_height, "Accent height is required")
	self.gap = assert(params.gap, "Gap is required")
	self.blink_period = 0.5
	self.blink_min_alpha = 0.7
	self.blink_offset = love.math.random() * self.blink_period

	self.text_batch = love.graphics.newText(self.font, self.text)

	local text_w, text_h = self.text_batch:getDimensions()
	local width = self.accent_width + self.gap + text_w
	local height = math.max(self.accent_height, text_h)
	self:setSize(width, height)
end

function SectionLabel:updateTransform()
	View.updateTransform(self)
	local x, y = self.transform:transformPoint(0, 0)
	self.transform:translate(math.floor(x) - x, math.floor(y) - y)
end

function SectionLabel:draw()
	local text_w, text_h = self.text_batch:getDimensions()
	local accent_y = math.floor((self.height - self.accent_height) / 2)
	local text_x = self.accent_width + self.gap
	local text_y = math.floor((self.height - text_h) / 2)
	local accent_color = self.accent_color
	local blink_t = (love.timer.getTime() + self.blink_offset) / self.blink_period
	local wave = 0.5 + 0.5 * math.sin(blink_t * math.pi * 2)
	local accent_alpha_max = accent_color[4] or 1
	local accent_alpha = self.blink_min_alpha + (accent_alpha_max - self.blink_min_alpha) * wave

	love.graphics.setColor(accent_color[1], accent_color[2], accent_color[3], accent_alpha)
	love.graphics.rectangle("fill", 0, accent_y, self.accent_width, self.accent_height)

	love.graphics.setColor(self.color)
	love.graphics.draw(self.text_batch, text_x, text_y)
end

return SectionLabel
