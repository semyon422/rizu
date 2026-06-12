local spherefonts = require("sphere.assets.fonts")
local just = require("just")
local time_util = require("time_util")
local imgui = require("imgui")

local ChartSlider = require("ui.views.EditorView.ChartSlider")

local Layout = require("ui.views.EditorView.Layout")

return function(self)
	local editorModel = self.game.editorModel
	local editorTimePoint = editorModel:getPoint()

	local w, h = Layout:move("footer")
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setFont(spherefonts.get("Noto Sans", 24))

	local lineHeight = 55
	imgui.setSize(w, h, 200, lineHeight)

	love.graphics.translate(0, h - lineHeight * 2)

	just.row(true)

	local play_pause = editorModel.timer.is_playing and "pause" or "play"
	local button_pressed = imgui.TextButton("play/pause", play_pause, 110, lineHeight)
	local key_pressed = just.keypressed("space")
	if button_pressed or key_pressed then
		if editorModel.timer.is_playing then
			editorModel:pause()
		else
			editorModel:play()
		end
	end

	imgui.TextButton(nil, time_util.format(editorTimePoint.absoluteTime, 3), 220, lineHeight)

	local newRate = imgui.Slider("rate slider", editorModel.timer.rate, w / 6, lineHeight, ("%0.2fx"):format(editorModel.timer.rate))
	if newRate then
		editorModel.timer:setRate(math.min(math.max(newRate, 0.25), 1))
	end

	just.row()

	ChartSlider(self, w, lineHeight)
end
