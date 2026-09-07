local View = require("gui.View")
local NineSliceUsage = require("gui.NineSliceUsage")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")

---@class ui.views.Tooltip : gui.View
---@operator call: ui.views.Tooltip
local Tooltip = View + {}

local PADDING_X = 10
local PADDING_Y = 6
local CURSOR_OFFSET = 14
local EDGE_MARGIN = 8

function Tooltip:new()
	View.new(self)
	self.background = NineSliceUsage(Resources.nine_slices.tooltip)
	self.font = Resources.getFont("medium", 14)
	self.text_batch = love.graphics.newTextBatch(self.font)
	self.text = nil
	self:setOpacity(0)
end

---@param text string?
function Tooltip:setText(text)
	if not text or text == "" then
		if self.text then
			self.text = nil
			self:fadeOut(0.12, "OutQuad")
		end
		return
	end
	if text ~= self.text then
		self.text = text
		self.text_batch:clear()
		self.text_batch:add({Colors.text, text}, PADDING_X, PADDING_Y)
		self:setSize(self.font:getWidth(text) + PADDING_X * 2, self.font:getHeight() + PADDING_Y * 2)
		self:setOpacity(0)
	end
	self:fadeIn(0.18, "OutQuint")
end

---@param screen_x number
---@param screen_y number
function Tooltip:followCursor(screen_x, screen_y)
	local parent = self.parent
	if not parent then return end
	local x, y = parent.world_transform:inverseTransformPoint(screen_x, screen_y)
	x = x + CURSOR_OFFSET
	y = y + CURSOR_OFFSET
	if x + self.width > parent.width - EDGE_MARGIN then
		x = x - self.width - CURSOR_OFFSET * 2
	end
	if y + self.height > parent.height - EDGE_MARGIN then
		y = y - self.height - CURSOR_OFFSET * 2
	end
	self:setPosition(
		math.max(EDGE_MARGIN, x),
		math.max(EDGE_MARGIN, y)
	)
end

function Tooltip:draw()
	Painter.snapToPixel()
	Painter.setColorRgb(1, 1, 1)
	self.background:drawFixedScale(self.width, self.height, assert(self.screen).ui_scale)
	love.graphics.draw(self.text_batch)
end

return Tooltip
