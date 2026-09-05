local View = require("gui.View")
local NineSliceUsage = require("gui.NineSliceUsage")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")

---@class ui.screens.song_select.FiltersButton : gui.View
---@operator call: ui.screens.song_select.FiltersButton
local FiltersButton = View + {}

---@param ui ui.UserInterface
function FiltersButton:new(ui)
	View.new(self)
	self.ui = ui
	self.label_font = Resources.getFont("bold", 9)
	self.value_font = Resources.getFont("bold", 14)
	self.background = NineSliceUsage(Resources.nine_slices.song_select_toolbar_control)
	self.handles_mouse_input = true
end

---@return string
function FiltersButton:getValueLabel()
	local filter_model = self.ui.game.chartSelector.filterModel
	local active = 0
	if filter_model:hasActiveFilters("(not) played") then
		active = active + 1
	end
	if filter_model:hasActiveFilters("scratch") then
		active = active + 1
	end
	if filter_model:hasActiveFilters("original input mode") then
		active = active + 1
	end
	if filter_model:hasActiveFilters("actual input mode") then
		active = active + 1
	end
	if active == 0 then
		return "None"
	end
	return active == 1 and "1 active" or (active .. " active")
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
	Painter.setColorTable(self.mouse_over and Colors.surface_raised or Colors.surface)
	self.background:drawFixedScale(self.width, self.height, assert(self.screen).ui_scale)

	local icon = Resources.sprites.icon_funnel
	local width, height = icon:getDimensions()
	local scale = math.min(20 / width, 20 / height)
	Painter.setColorTable(Colors.accent)
	icon:draw(14, (self.height - height * scale) / 2, 0, scale, scale)

	Painter.setColorTable(Colors.muted)
	love.graphics.setFont(self.label_font)
	love.graphics.print("FILTERS", 45, 7)
	Painter.setColorTable(Colors.text)
	love.graphics.setFont(self.value_font)
	love.graphics.print(self:getValueLabel(), 45, 21)
end

return FiltersButton
