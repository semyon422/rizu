local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")

---@class ui.screens.song_select.FooterCell : gui.View
---@operator call: ui.screens.song_select.FooterCell
---@field content gui.View
---@field left gui.Sprite
---@field middle gui.Sprite
---@field right gui.Sprite
local FooterCell = View + {}

local HORIZONTAL_PADDING = 15
local HEIGHT = 40

---@param content gui.View
function FooterCell:new(content)
	View.new(self)
	self.left = Resources.sprites.footer_button_left
	self.middle = Resources.sprites.footer_button_middle
	self.right = Resources.sprites.footer_button_right

	self.content = self:add(content)
	self.content:setAlignment(0.5, 0.5)
	self:fitContent()
end

---Resizes the cell from its content's current authored width.
---@return ui.screens.song_select.FooterCell
function FooterCell:fitContent()
	local content_width = self.content.offset_max[1] - self.content.offset_min[1]
	local minimum_width = self.left:getWidth() + self.right:getWidth()
	self:setSize(math.max(minimum_width, content_width + HORIZONTAL_PADDING * 2), HEIGHT)
	return self
end

function FooterCell:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.elements)

	local left_width = self.left:getWidth()
	local right_width = self.right:getWidth()
	local middle_width = self.width - left_width - right_width
	self.left:draw(0, 0)
	self.middle:draw(left_width, 0, 0, middle_width / self.middle:getWidth(), 1)
	self.right:draw(self.width - right_width, 0)
end

return FooterCell
