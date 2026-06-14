local View = require("gui.View")
local Colors = require("yi.Colors")
local Painter = require("yi.Painter")

---@class yi.ChartInfo: gui.View
---@operator call: yi.ChartInfo
local ChartInfo = View + {}

function ChartInfo:new()
	View.new(self)
	self:setHeight(36)

	self.duration = "00:00"
	self.mode = "?K"
	self.notes = "0"
	self.tempo = "0"
	self.ln = "0%%"
end

---@param chartview rizu.library.Chartview
---@param replay_base sea.ReplayBase
function ChartInfo:bind(chartview, replay_base)
	local duration = (chartview.duration or 0) * replay_base.rate
	local notes = chartview.notes_count or 0
	local mode = (chartview.inputmode or "???"):gsub("key", "K")
	local tempo = (chartview.tempo or 0) * replay_base.rate
	local ln = chartview.long_notes_ratio or 0

	local minutes = duration / 60
	local seconds = duration % 60

	self.duration = ("%i:%0.2i"):format(minutes, seconds)
	self.mode = mode
	self.notes = tostring(notes)
	self.tempo = ("%i"):format(tempo)
	self.ln = ("%i%%"):format((ln * 100))
end

local lg = love.graphics
local KV_GAP = 10
local VK_GAP = 45

local function drawKV(k, v, ky)
	lg.setColor(Colors.text_muted)
	Painter.setFontSize(24)
	Painter.print(k, 0, ky)

	lg.setColor(Colors.text)
	lg.translate(Painter.getFontWidth(k, 24) + KV_GAP, 0)
	Painter.setFontSize(36)
	Painter.print(v)

	lg.translate(Painter.getFontWidth(v, 36) + VK_GAP, 0)
end

function ChartInfo:draw()
	local half = (Painter.getFontHeight(36) - Painter.getFontHeight(24)) / 2

	Painter.setFontOutline(0.12)
	Painter.setFontThickness(0.45)
	Painter.setFontOutlineColor(Colors.text_shadow)
	Painter.beginTextDrawing()

	drawKV("DURATION", self.duration, half)
	drawKV("MODE", self.mode, half)
	drawKV("NOTES", self.notes, half)
	drawKV("TEMPO", self.tempo, half)
	drawKV("LN", self.ln, half)

	Painter.endTextDrawing()
end

return ChartInfo
