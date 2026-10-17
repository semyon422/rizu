local NineSliceUsage = require("gui.NineSliceUsage")
local Painter = require("gui.Painter")
local Resources = require("ui.Resources")
local View = require("gui.View")

---@class ui.screens.dlc.DlcPanel : gui.View
---@operator call: ui.screens.dlc.DlcPanel
---@field color gui.Color
---@field background gui.NineSliceUsage
local DlcPanel = View + {}

---@param color gui.Color
function DlcPanel:new(color)
	View.new(self)
	self.color = color
	self.background = NineSliceUsage(Resources.nine_slices.dlc_panel)
end

function DlcPanel:draw()
	Painter.setColorTable(self.color)
	self.background:draw(self.width, self.height)
end

return DlcPanel
