local Button = require("ui.views.Button")
local NineSliceUsage = require("gui.NineSliceUsage")
local Resources = require("ui.Resources")

---@alias ui.screens.gameplay.PauseButtonVariant "continue"|"restart"|"leave"

---@class ui.screens.gameplay.PauseButton : ui.views.Button
---@operator call: ui.screens.gameplay.PauseButton
local PauseButton = Button + {}

---@param text string
---@param on_click fun()
---@param variant ui.screens.gameplay.PauseButtonVariant
function PauseButton:new(text, on_click, variant)
	Button.new(self, text, on_click, {font_name = "bold", font_size = 26})
	assert(variant == "continue" or variant == "restart" or variant == "leave", "invalid pause button variant")
	local sprite_name = "gameplay_pause_button_" .. variant
	self.background = NineSliceUsage(Resources.nine_slices[sprite_name])
	self.hover_background = NineSliceUsage(Resources.nine_slices[sprite_name .. "_hover"])
	self.pressed_background = NineSliceUsage(Resources.nine_slices[sprite_name .. "_pressed"])
	self:setSize(380, 68)
end

return PauseButton
