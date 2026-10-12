local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
local ToolbarBackground = require("ui.screens.song_select_v2.ToolbarBackground")

---@class ui.screens.song_select_v2.FiltersButton : gui.View
---@operator call: ui.screens.song_select_v2.FiltersButton
local FiltersButton = View + {}

---@param ui ui.UserInterface
function FiltersButton:new(ui)
	View.new(self)
	self.ui = ui
	self.label_font = Resources.getFont("bold", 9)
	self.value_font = Resources.getFont("bold", 14)
	self.background = ToolbarBackground()
	self.handles_mouse_input = true
end

---@return string
function FiltersButton:getValueLabel()
	local active = self.ui.api.charts:getActiveFilterCount()
	if active == 0 then
		return self.ui.localization:get("song_select.filters_none")
	end
	return self.ui.localization:get("song_select.filters_active", {count = active})
end

---@param e gui.HoverEvent
function FiltersButton:onHover(e)
	if self.effective_enabled then
		Sounds.play("hover")
	end
end

---@param e gui.MouseClickEvent
---@return boolean?
function FiltersButton:onMouseClick(e)
	if e.button ~= 1 or not self.effective_enabled then
		return
	end
	self.ui.modal_manager:attachFilters()
	Sounds.play("click")
	return true
end

function FiltersButton:draw()
	Painter.snapToPixel()
	self.background:draw(self.width, self.height, assert(self.screen).ui_scale, self.mouse_over)

	local icon = Resources.sprites.icon_funnel
	local width, height = icon:getDimensions()
	local scale = math.min(20 / width, 20 / height)
	Painter.setColorTable(Colors.accent)
	icon:draw(14, (self.height - height * scale) / 2, 0, scale, scale)

	Painter.setColorTable(Colors.muted)
	love.graphics.setFont(self.label_font)
	love.graphics.print(self.ui.localization:get("song_select.filters"), 45, 7)
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.value_font)
	love.graphics.print(self:getValueLabel(), 45, 21)
end

return FiltersButton
