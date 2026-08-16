local View = require("gui.View")
local BgaRenderer = require("ui.views.BgaRenderer")
local Painter = require("gui.Painter")

---@class ui.screens.gameplay.BgaView : gui.View
---@operator call: ui.screens.gameplay.BgaView
---@field game sphere.GameController
---@field ui_config ui.UiConfig
---@field renderer ui.views.BgaRenderer
local BgaView = View + {}

---@param game sphere.GameController
---@param ui_config ui.UiConfig
function BgaView:new(game, ui_config)
	View.new(self)
	self.game = game
	self.ui_config = ui_config
	self.renderer = BgaRenderer()
end

function BgaView:draw()
	local rhythm_engine = self.game.rhythm_engine
	local bga_engine = rhythm_engine and rhythm_engine.bga_engine
	if not bga_engine then
		return
	end

	local brightness = self.ui_config:getNumber(self.ui_config.keys.gameplay_bga_brightness)
	Painter.setColorRgb(brightness, brightness, brightness)
	self.renderer:draw(bga_engine, rhythm_engine.visual_info:getTime(), self.width, self.height)
end

return BgaView
