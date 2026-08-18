local View = require("gui.View")
local Resources = require("ui.Resources")
local Color = require("ui.Color")
local Colors = require("ui.Colors")
local Painter = require("gui.Painter")
local Settings = require("rizu.config.Settings")

---@class ui.screens.song_select.DifficultyPanel : gui.View
---@operator call: ui.screens.song_select.DifficultyPanel
local DifficultyPanel = View + {}

---@param cvf ui.formatters.ChartviewFormatter
function DifficultyPanel:new(cvf)
	View.new(self)

	self.cvf = cvf
	self.difficulty = "0.0"
	self.difficulty_color = Colors.text
	self.difficulty_font = Resources.getFont("regular", 48)
	self.postfix_font = Resources.getFont("regular", 16)
	self.postfix = "ENPS"

	self.bg = Resources.sprites.song_select_difficulty_panel
	self.gradient = Resources.sprites.song_select_difficulty_panel_gradient

	cvf.settings:subscribeChoice(Settings.keys.select.diff_column, function()
		self:updateDifficulty()
	end)
	self:updateDifficulty()
end

function DifficultyPanel:updateDifficulty()
	local diff = self.cvf:getDifficulty()
	self.difficulty = diff.value
	self.difficulty_color = diff.color
	self.postfix = diff.postfix
end

function DifficultyPanel:bind()
	self:updateDifficulty()
end

function DifficultyPanel:draw()
	Painter.setColorTable(Colors.panel)
	self.bg:draw()
	Painter.setColorTable(self.difficulty_color)
	Painter.setOpacity(0.2 * self.render_opacity)
	self.gradient:draw()
	Painter.setOpacity(self.render_opacity)

	local lg = love.graphics
	local previous_font = lg.getFont()
	local difficulty_height = self.difficulty_font:getHeight()
	local postfix_height = self.postfix_font:getHeight()
	local content_y = (self.height - difficulty_height - postfix_height) / 2

	lg.setFont(self.difficulty_font)
	lg.printf(self.difficulty, 0, content_y, self.width, "center")

	Painter.setColorTable(Colors.text_muted)
	lg.setFont(self.postfix_font)
	lg.printf(self.postfix, 0, content_y + difficulty_height - 4, self.width, "center")
	lg.setFont(previous_font)
end

return DifficultyPanel
