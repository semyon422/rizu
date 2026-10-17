local ChartBuilder = require("chart.format.notechart.ChartBuilder")
local SdvxNoteDecoder = require("chart.format.ksm.SdvxNoteDecoder")
local InputMode = require("chart.core.InputMode")
local Chartmeta = require("sea.chart.Chartmeta")
local Tempo = require("chart.model.to.Tempo")

local SdvxDecoder = {}

---@param source string
---@param hash string?
---@return chart.Chart
---@return sea.Chartmeta
function SdvxDecoder.decode(source, hash)
	local builder = ChartBuilder()
	local chart = builder.chart
	-- Keep the existing library identifier, but never use its directional columns for gameplay.
	chart.inputMode = InputMode("4bt2fx2laserleft2laserright")
	local layer = builder:createAbsoluteLayer()
	local visual = builder:getVisual("main")
	SdvxNoteDecoder.decode(source, chart, layer, visual)
	local sdvx = chart.data
	for _, tempo in ipairs(sdvx.tempos) do
		local point = layer:getPoint(tempo.time)
		point._tempo = Tempo(tempo.bpm)
		visual:getPoint(point)
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
