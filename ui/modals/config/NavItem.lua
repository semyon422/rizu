local Colors = require("ui.Colors")
local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
local View = require("gui.View")

---A sidebar entry of the settings modal: highlighted on hover, raised while its section is in view.
---@class ui.modals.config.NavItem : gui.View
---@operator call: ui.modals.config.NavItem
---@field icon gui.Sprite
---@field text string
---@field on_select fun()
---@field active boolean
---@field background gui.NineSliceUsage?
local NavItem = View + {}

NavItem.HEIGHT = 38

local PADDING_X = 12
local ICON_SIZE = 18
local GAP = 12

---@param icon gui.Sprite
---@param text string
---@param on_select fun()
function NavItem:new(icon, text, on_select)
	View.new(self)
	self.icon = icon
	self.text = text
	self.on_select = on_select
	self.active = false
	self.handles_mouse_input = true
	self:setHeight(NavItem.HEIGHT)
end

---@param e gui.HoverEvent
function NavItem:onHover(e)
	Sounds.play("hover")
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function NavItem:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	Sounds.play("click")
	self.on_select()
	return true
end

function NavItem:draw()
	Painter.snapToPixel()
	if self.active or self.mouse_over then
		self.background = self.background or NineSliceUsage(Resources.nine_slices.config_v2_nav_item)
		Painter.setColorTable(self.active and Colors.surface_raised or Colors.surface)
		self.background:draw(self.width, self.height)
	end

	local text_color = (self.active or self.mouse_over) and Colors.text or Colors.muted
	local scale = ICON_SIZE / self.icon:getWidth()
	Painter.setColorTable(self.active and Colors.accent or text_color)
	self.icon:draw(PADDING_X, (self.height - ICON_SIZE) / 2, 0, scale, scale)

	local font = Resources.getFont("medium", 14)
	Painter.setColorTable(text_color)
	love.graphics.setFont(font)
	love.graphics.print(self.text, PADDING_X + ICON_SIZE + GAP, math.floor((self.height - font:getHeight()) / 2))
end

return NavItem
