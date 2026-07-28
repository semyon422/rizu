local View = require("gui.View")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Color = require("ui.Color")
local Painter = require("gui.Painter")

---@class ui.screens.song_select.InfoPanel : gui.View
---@operator call: ui.screens.song_select.InfoPanel
---@field text_batch24 love.Text
local InfoPanel = View + {}

function InfoPanel:new()
	View.new(self)
	self.text_batch24 = love.graphics.newTextBatch(Resources.getFont("regular", 24))
	self.font64 = Resources.getFont("regular", 64)
	self.ln_color = {1, 1, 1, 1}
	self.difficulty = "0.00"
	self.difficulty_color = {1, 1, 1, 1}
	self:setSize(0, 122)
end

function InfoPanel:load() end

local cs = {{1, 1, 1, 1}, ""}

local pattern_alias_4k = {
	stream = "STREAM",
	jumpstream = "JS",
	handstream = "HS",
	stamina = "STAMINA",
	jackspeed = "JACK",
	chordjack = "CJ",
	technical = "TECH"
}

---@param cvf ui.factories.ChartviewFactory
function InfoPanel:bind(cvf)
	self.text_batch24:clear()
	local tb24 = self.text_batch24

	cs[1] = Colors.text
	cs[2] = cvf:getDuration()
	tb24:add(cs, 355, 13)

	local tempo = cvf:getTempo()

	if tempo.min ~= "0" and tempo.min ~= "0" then
		cs[2] = ("%i (%i - %i)"):format(tempo.avg, tempo.min, tempo.max)
		tb24:add(cs, 355, 48)
	else
		cs[2] = ("%i"):format(tempo.avg)
		tb24:add(cs, 355, 48)
	end

	cs[1] = Colors.text_muted
	cs[2] = "LN"
	tb24:add(cs, 304, 84)

	local ln_ratio = cvf:getLongNoteRatio()
	cs[1] = ln_ratio.color
	cs[2] = ln_ratio.value
	tb24:add(cs, 355, 84)

	local patterns = cvf:getPatterns()
	local top, second = patterns.top_simple, patterns.second_simple
	cs[1] = Colors.text

	if top and second then
		cs[2] = ("%s %s"):format(top, second)
	elseif top then
		cs[2] = top
	else
		cs[2] = "None"
	end

	tb24:add(cs, 12, 84)

	local diff = cvf:getDifficulty()
	self.difficulty = diff.value
	self.difficulty_color = diff.color
end

function InfoPanel:draw()
	Painter.setColorTable(Colors.panel)
	Resources.sprites.pixel:draw(0, 0, 0, self.width, self.height)
	Painter.snapToPixel()
	Painter.setColorTable(Colors.text_muted)
	Resources.sprites.icon_clock:draw(308, 15)
	Resources.sprites.icon_metronome:draw(308, 50)
	Painter.setColorRgb(1, 1, 1)
	love.graphics.draw(self.text_batch24)
	love.graphics.setFont(self.font64)
	Painter.setColorTable(self.difficulty_color)
	love.graphics.print(self.difficulty, 12, 8)
end

return InfoPanel
