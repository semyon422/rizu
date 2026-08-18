local View = require("gui.View")
local Resources = require("ui.Resources")
local Colors = require("ui.Colors")
local Color = require("ui.Color")
local Painter = require("gui.Painter")
local NineSliceUsage = require("gui.NineSliceUsage")

---@class ui.screens.song_select.InfoPanel : gui.View
---@operator call: ui.screens.song_select.InfoPanel
---@field text_batch24 love.Text
local InfoPanel = View + {}

function InfoPanel:new()
	View.new(self)
	self.text_batch24 = love.graphics.newTextBatch(Resources.getFont("regular", 24))
	self.font64 = Resources.getFont("regular", 64)
	self.ln_color = {1, 1, 1, 1}
	self.bg = NineSliceUsage(Resources.nine_slices.ns_rect)
end

function InfoPanel:load() end

local cs = {{1, 1, 1, 1}, ""}

---@param cvf ui.formatters.ChartviewFormatter
function InfoPanel:bind(cvf)
	self.text_batch24:clear()
	local tb24 = self.text_batch24

	cs[1] = Colors.text
	cs[2] = cvf:getDuration()
	tb24:add(cs, 65, 9)

	cs[1] = Colors.text_muted
	cs[2] = "LN"
	tb24:add(cs, 14, 43)

	local ln_ratio = cvf:getLongNoteRatio()
	cs[1] = ln_ratio.color
	cs[2] = ln_ratio.value
	tb24:add(cs, 65, 43)

	local tempo = cvf:getTempo()

	cs[1] = Colors.text
	if tempo.min ~= "0" and tempo.min ~= "0" then
		cs[2] = ("%i (%i - %i)"):format(tempo.avg, tempo.min, tempo.max)
		tb24:add(cs, 407, 9)
	else
		cs[2] = ("%i"):format(tempo.avg)
		tb24:add(cs, 407, 9)
	end

	cs[1] = Colors.text
	cs[2] = cvf:getNoteCount()
	tb24:add(cs, 212, 9)

	cs[1] = Colors.text_muted
	cs[2] = "LV"
	tb24:add(cs, 165, 43)

	cs[1] = Colors.text
	cs[2] = cvf:getLevel()
	tb24:add(cs, 212, 43)

	cs[2] = cvf:getFormat()
	tb24:add(cs, 407, 43)
end

function InfoPanel:draw()
	Painter.setColorTable(Colors.panel)
	self.bg:draw(self.width, self.height)
	Painter.snapToPixel()
	Painter.setColorTable(Colors.text_muted)
	Resources.sprites.icon_clock:draw(18, 11)
	Resources.sprites.icon_music:draw(165, 11)
	Resources.sprites.icon_metronome:draw(360, 11)
	Resources.sprites.icon_file:draw(360, 45)
	Painter.setColorRgb(1, 1, 1)
	love.graphics.draw(self.text_batch24)
	love.graphics.setFont(self.font64)
end

return InfoPanel
