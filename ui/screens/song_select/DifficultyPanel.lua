local View = require("gui.View")
local Resources = require("ui.Resources")
local Color = require("ui.Color")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")

---@class ui.screens.song_select.DifficultyPanel : gui.View
---@operator call: ui.screens.song_select.DifficultyPanel
local DifficultyPanel = View + {}

function DifficultyPanel:new()
	View.new(self)

	self.difficulty = "0.0"
	self.difficulty_color = Colors.text
	self.difficulty_font = Resources.getFont("regular", 64)
	self.postfix_font = Resources.getFont("regular", 24)
	self.postfix = "ENPS"

	self.bg = Resources.sprites.song_select_difficulty_panel
	self.gradient = Resources.sprites.song_select_difficulty_panel_gradient
end

---@param cvf ui.formatters.ChartviewFormatter
function DifficultyPanel:bind(cvf)
	local diff = cvf:getDifficulty()
	self.difficulty = diff.value
	self.difficulty_color = diff.color
	self.postfix = diff.postfix
end

function DifficultyPanel:draw()
	Painter.setColorTable(Colors.panel)
	self.bg:draw()
	Painter.setColorTable(self.difficulty_color)
	Painter.setOpacity(0.2 * self.render_opacity)
	self.gradient:draw()
	Painter.setOpacity(self.render_opacity)
	love.graphics.setFont(self.difficulty_font)
	love.graphics.print(self.difficulty, 12, 2)

	Painter.setColorTable(Colors.text_muted)
	love.graphics.setFont(self.postfix_font)
	love.graphics.print(self.postfix, 150, 26)
end

return DifficultyPanel
