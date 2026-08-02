local View = require("gui.View")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")

---@class ui.screens.song_select.Footer : gui.View
---@operator call: ui.screens.song_select.Footer
---@field left gui.Sprite
---@field middle gui.Sprite
---@field right gui.Sprite
local Footer = View + {}

local HEIGHT = 50

function Footer:new()
	View.new(self)
	self.left = Resources.sprites.footer_bg_left
	self.middle = Resources.sprites.footer_bg_middle
	self.right = Resources.sprites.footer_bg_right
	self:setSize(self.left:getWidth() + self.middle:getWidth() + self.right:getWidth(), HEIGHT)
end

function Footer:draw()
	Painter.snapToPixel()
	Painter.setColorTable(Colors.panel)

	local left_width = self.left:getWidth()
	local right_width = self.right:getWidth()
	local middle_width = math.max(0, self.width - left_width - right_width)

	self.left:draw(0, 0)
	if middle_width > 0 then
		self.middle:draw(left_width, 0, 0, middle_width / self.middle:getWidth(), 1)
	end
	self.right:draw(self.width - right_width, 0)
end

return Footer
