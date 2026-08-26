local Colors = require("ui.Colors")
local Image = require("ui.views.Image")
local Label = require("ui.views.Label")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local View = require("gui.View")

---@class ui.modals.config.SectionItem : gui.View
---@operator call: ui.modals.config.SectionItem
---@field section ui.modals.config.Section
---@field on_select fun(section: ui.modals.config.Section)
local SectionItem = View + {}

local WIDTH = 280
local HEIGHT = 48
local PADDING = 12
local ICON_SIZE = 24
local GAP = 12

---@param section ui.modals.config.Section
---@param on_select fun(section: ui.modals.config.Section)
function SectionItem:new(section, on_select)
	View.new(self)
	self.section = section
	self.on_select = on_select
	self.handles_mouse_input = true
	self:setSize(WIDTH, HEIGHT)

	self:add(Image(section.icon, "fit", Colors.text)):anchorFixed(PADDING, PADDING, ICON_SIZE, ICON_SIZE)
	local label = self:add(Label({font_name = "medium", font_size = 16, text = section.name}))
	local label_height = label.offset_max[2] - label.offset_min[2]
	label:setOffset(PADDING + ICON_SIZE + GAP, (HEIGHT - label_height) / 2)
end

---@param e gui.MouseClickEvent
---@return boolean? handled
function SectionItem:onMouseClick(e)
	if e.button ~= 1 then
		return
	end
	self.on_select(self.section)
	return true
end

function SectionItem:draw()
	if not self.mouse_over then
		return
	end
	Painter.setColorTable(Colors.surface_raised)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
end

return SectionItem
