local View = require("gui.View")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local Sounds = require("ui.Sounds")
local ToolbarBackground = require("ui.screens.song_select_v2.ToolbarBackground")

---Opens the leaderboard filters, styled like the toolbar controls.
---@class ui.screens.song_select_v2.ScoreFiltersButton : gui.View
---@operator call: ui.screens.song_select_v2.ScoreFiltersButton
local ScoreFiltersButton = View + {}

local ICON_SIZE = 18

---@param on_click fun()
function ScoreFiltersButton:new(on_click)
	View.new(self)
	self.on_click = on_click
	self.background = ToolbarBackground()
	self.handles_mouse_input = true
end

---@param e gui.HoverEvent
function ScoreFiltersButton:onHover(e)
	if self.effective_enabled then
		Sounds.play("hover")
	end
end

---@param e gui.MouseClickEvent
---@return boolean?
function ScoreFiltersButton:onMouseClick(e)
	if e.button ~= 1 or not self.effective_enabled then
		return
	end
	self.on_click()
	Sounds.play("click")
	return true
end

function ScoreFiltersButton:draw()
	Painter.snapToPixel()
	self.background:draw(self.width, self.height, assert(self.screen).ui_scale, self.mouse_over)

	local icon = Resources.sprites.icon_funnel
	local width, height = icon:getDimensions()
	local scale = math.min(ICON_SIZE / width, ICON_SIZE / height)
	Painter.setColorTable(self.mouse_over and Colors.text or Colors.muted)
	icon:draw((self.width - width * scale) / 2, (self.height - height * scale) / 2, 0, scale, scale)
end

return ScoreFiltersButton
