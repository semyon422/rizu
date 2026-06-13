local spherefonts = require("sphere.assets.fonts")
local just = require("just")
local time_util = require("time_util")
local imgui = require("imgui")

local ChartSlider = require("ui.views.EditorView.ChartSlider")

local Layout = require("ui.views.EditorView.Layout")

return function(self)
	local context = self.game.editorModel.context:getViewContext()
	local footerService = self.editorViewServices.footerService
	local state = footerService:getState(context)

	local w, h = Layout:move("footer")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))

	local lineHeight = 55
	imgui.setSize(w, h, 200, lineHeight)

	love.graphics.translate(0, h - lineHeight * 2)

	just.row(true)

	local button_pressed = imgui.TextButton("play/pause", state.playPauseLabel, 110, lineHeight)
	local key_pressed = just.keypressed("space")
	if button_pressed or key_pressed then
		footerService:togglePlayback(context)
	end

	imgui.TextButton(nil, time_util.format(state.absoluteTime, 3), 220, lineHeight)

	local newRate = imgui.Slider("rate slider", state.rate, w / 6, lineHeight, ("%0.2fx"):format(state.rate))
	if newRate then
		footerService:setRate(context, newRate)
	end

	just.row()

	ChartSlider(self, w, lineHeight)
end
