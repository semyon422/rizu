local ChartBuilder = require("chart.format.notechart.ChartBuilder")
local SdvxChart = require("chart.format.ksm.SdvxChart")
local InputMode = require("chart.core.InputMode")
local Chartmeta = require("sea.chart.Chartmeta")
local Tempo = require("chart.model.to.Tempo")
local Note = require("chart.model.notes.Note")

local SdvxDecoder = {}

---@param source string
---@param hash string?
---@return chart.Chart
---@return sea.Chartmeta
function SdvxDecoder.decode(source, hash)
	local sdvx = SdvxChart(source)
	local builder = ChartBuilder()
	local chart = builder.chart
	chart.sdvx = sdvx
	-- Keep the existing library identifier, but never use its directional columns for gameplay.
	chart.inputMode = InputMode("4bt2fx2laserleft2laserright")
	local layer = builder:createAbsoluteLayer()
	local visual = builder:getVisual("main")
	for _, tempo in ipairs(sdvx.tempos) do
		local point = layer:getPoint(tempo.time)
		point._tempo = Tempo(tempo.bpm)
		visual:getPoint(point)
	end
	for _, object in ipairs(sdvx.buttons) do
		local column = object.lane <= 4 and "bt" .. object.lane or "fx" .. (object.lane - 4)
		local note = Note(visual:getPoint(layer:getPoint(object.time)), column, object.kind == "chip" and "tap" or "hold")
		note.weight = object.kind == "hold" and 1 or 0
		chart.notes:insert(note)
		if object.kind == "hold" then
			local tail = Note(visual:getPoint(layer:getPoint(object.end_time)), column, "hold")
			tail.weight = -1
			chart.notes:insert(tail)
		end
	end
	if sdvx.audio_path then
		local volume = sdvx.options.mvol and assert(tonumber(sdvx.options.mvol)) / 100 or 1
		assert(volume >= 0 and volume <= 10, "SDVX prototype: invalid music volume.")
		builder:setMainAudio(sdvx.audio_path, -sdvx.offset, volume)
	end
	chart:compute()
	local meta = Chartmeta()
	meta.mode = "sdvx"
	meta.hash, meta.index, meta.format = hash, 1, "ksm"
	meta.title, meta.artist, meta.creator = sdvx.options.title, sdvx.options.artist, sdvx.options.effect
	meta.name, meta.level = sdvx.options.difficulty, tonumber(sdvx.options.level)
	meta.audio_path, meta.background_path = sdvx.audio_path, sdvx.options.jacket
	meta.preview_time = sdvx.options.po and assert(tonumber(sdvx.options.po)) / 1000 or 0
	meta.tempo = sdvx.tempos[1].bpm
	meta.inputmode = tostring(chart.inputMode)
	assert(meta:validate())
	return chart, meta
end

return SdvxDecoder
