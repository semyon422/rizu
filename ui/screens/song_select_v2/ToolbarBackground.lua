local class = require("class")
local NineSliceUsage = require("gui.NineSliceUsage")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")

---Background of a toolbar control. The toolbar sits directly on the blurred background, whose brightness
---follows the song, so the control is a dark well with a light hairline instead of a fixed surface color.
---@class ui.screens.song_select_v2.ToolbarBackground
---@operator call: ui.screens.song_select_v2.ToolbarBackground
local ToolbarBackground = class()

local background = Colors.background
local text = Colors.text
local FILL = {background[1], background[2], background[3], 0.62}
local FILL_HOVER = {Colors.surface_raised[1], Colors.surface_raised[2], Colors.surface_raised[3], 0.85}
local BORDER = {text[1], text[2], text[3], 0.2}
local BORDER_HOVER = {text[1], text[2], text[3], 0.42}

function ToolbarBackground:new()
	self.fill = NineSliceUsage(Resources.nine_slices.song_select_toolbar_control)
	self.border = NineSliceUsage(Resources.nine_slices.song_select_toolbar_border)
end

---@param width number
---@param height number
---@param ui_scale number
---@param highlighted boolean? Hovered or focused.
function ToolbarBackground:draw(width, height, ui_scale, highlighted)
	Painter.setColorTable(highlighted and FILL_HOVER or FILL)
	self.fill:drawFixedScale(width, height, ui_scale)
	Painter.setColorTable(highlighted and BORDER_HOVER or BORDER)
	self.border:drawFixedScale(width, height, ui_scale)
end

return ToolbarBackground
