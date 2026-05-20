local IChartDecoder = require("chart.format.notechart.IChartDecoder")
local ChartBuilder = require("chart.format.notechart.ChartBuilder")
local Chart = require("chart.model.Chart")
local Note = require("chart.format.notechart.Note")
local Velocity = require("chart.model.visual.Velocity")
local Tempo = require("chart.model.to.Tempo")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local VisualColumns = require("chart.model.visual.VisualColumns")
local InputMode = require("chart.core.InputMode")
local RawOsu = require("chart.format.osu.RawOsu")
local Osu = require("chart.format.osu.Osu")
local Visual = require("chart.model.visual.Visual")
local Chartmeta = require("sea.chart.Chartmeta")
local Healths = require("sea.chart.Healths")
local Timings = require("sea.chart.Timings")
local odhp = require("chart.format.osu.odhp")

---@class chart.osu.ChartDecoder: chart.IChartDecoder
---@operator call: chart.osu.ChartDecoder
local ChartDecoder = IChartDecoder + {}

function ChartDecoder:new()
	self.longNotes = {}
end

---@param s string
---@param hash string?
---@return {chart: chart.Chart, chartmeta: sea.Chartmeta}[]
function ChartDecoder:decode(s, hash)
	self.hash = hash
	local rawOsu = RawOsu()
	local osu = Osu(rawOsu)
	rawOsu:decode(s)
	osu:decode()
	local chart, chartmeta = self:decodeOsu(osu)
	return {{
		chart = chart,
		chartmeta = chartmeta,
	}}
end

---@param osu chart.osu.Osu
---@return chart.Chart
---@return sea.Chartmeta
function ChartDecoder:decodeOsu(osu)
	self.osu = osu

	local chartBuilder = ChartBuilder()
	self.chartBuilder = chartBuilder

	local chart = chartBuilder.chart
	self.chart = chart

	local layer = chartBuilder:createAbsoluteLayer()
	self.layer = layer

	local visual = chartBuilder:getVisual("main")
	self.visual = visual
	self.visualColumns = VisualColumns(visual)

	visual.primaryTempo = 120

	self:decodeTempos()
	self:decodeVelocities()
	self:decodeNotes()
	self:decodeSamples()
	self:decodeBarlines()

	self:addAudio()

	local mode = tonumber(self.osu.rawOsu.General.Mode)
	if mode == 0 then
		chart.inputMode = InputMode({osu = 1})
	elseif mode == 1 then
		chart.inputMode = InputMode({key = 2})
	elseif mode == 2 then
		chart.inputMode = InputMode({fruits = 1})
	elseif mode == 3 then
		chart.inputMode = InputMode({key = osu.keymode})
	end

	chart:compute()

	local chartmeta = self:getChartmeta()

	return chart, chartmeta
end

---@return sea.Chartmeta
function ChartDecoder:getChartmeta()
	local general = self.osu.rawOsu.General
	local metadata = self.osu.rawOsu.Metadata

	---@type sea.Timings?
	local timings

	local od = tonumber(self.osu.rawOsu.Difficulty.OverallDifficulty)
	if od then
		timings = Timings("osuod", odhp.round_od(od, 10))
	end

	local chartmeta = {
		hash = self.hash,
		index = 1,
		format = "osu",
		title = metadata.Title,
		artist = metadata.Artist,
		source = metadata.Source,
		tags = metadata.Tags,
		name = metadata.Version,
		creator = metadata.Creator,
		audio_path = general.AudioFilename,
		background_path = self.osu.rawOsu.Events.background,
		preview_time = tonumber(general.PreviewTime) / 1000,
		inputmode = tostring(self.chart.inputMode),
		tempo = self.osu.primary_tempo,
		tempo_avg = self.osu.primary_tempo,
		tempo_min = self.osu.min_tempo,
		tempo_max = self.osu.max_tempo,
		osu_beatmap_id = tonumber(self.osu.rawOsu.Metadata.BeatmapID),
		osu_beatmapset_id = tonumber(self.osu.rawOsu.Metadata.BeatmapSetID),
		timings = timings,
	}
	setmetatable(chartmeta, Chartmeta)
	---@cast chartmeta sea.Chartmeta

	assert(chartmeta:validate())

	return chartmeta
end

function ChartDecoder:addAudio()
	local path = self.osu.rawOsu.General.AudioFilename
	if not path or path == "virtual" then
		return
	end
	self.chartBuilder:setMainAudio(path)
end

function ChartDecoder:decodeTempos()
	local layer = self.layer
	local visual = self.visual
	for _, proto_tempo in ipairs(self.osu.protoTempos) do
		local point = layer:getPoint(proto_tempo.offset / 1000)
		local tempo = math.min(proto_tempo.tempo, 1e6) -- visual time double precision loss (1e100 + 1)
		point._tempo = Tempo(tempo)
		visual:getPoint(point)
		-- do something with proto_tempo.signature
	end
end

function ChartDecoder:decodeVelocities()
	local layer = self.layer
	local visual = self.visual
	for _, proto_velocity in ipairs(self.osu.protoVelocities) do
		local point = layer:getPoint(proto_velocity.offset / 1000)
		local visualPoint = visual:getPoint(point)
		visualPoint._velocity = Velocity(proto_velocity.velocity)
	end
end

function ChartDecoder:decodeNotes()
	local chart = self.chart
	for _, proto_note in ipairs(self.osu.protoNotes) do
		local a, b = self:getNotes(proto_note)
		if a then
			chart.notes:insert(a)
		end
		if b then
			chart.notes:insert(b)
		end
	end
end

function ChartDecoder:decodeSamples()
	local layer = self.layer
	local chart = self.chart
	local visualColumns = self.visualColumns

	for _, e in ipairs(self.osu.rawOsu.Events.samples) do
		local point = layer:getPoint(e.time / 1000)
		local visualPoint = visualColumns:getPoint(point, "auto")
		local note = Note(visualPoint, "auto", "sample")
		note.data = {sounds = {{e.name, e.volume / 100}}}
		chart.notes:insert(note)
		self.chart.resources:add("sound", e.name)
	end
end

---@param time number
---@param column chart.Column
---@param _type string
---@param sounds table?
---@param weight integer?
---@return chart.Note
function ChartDecoder:getNote(time, column, _type, sounds, weight)
	local layer = self.layer
	local visualColumns = self.visualColumns
	local point = layer:getPoint(time)
	local visualPoint = visualColumns:getPoint(point, column)
	local note = Note(visualPoint, column)
	note.type = _type
	note.weight = weight or 0
	note.data = {sounds = sounds}
	return note
end

---@param proto_note chart.osu.ProtoNote
---@return chart.Note?
---@return chart.Note?
function ChartDecoder:getNotes(proto_note)
	local startTime = proto_note.time and proto_note.time / 1000
	local endTime = proto_note.endTime and proto_note.endTime / 1000
	local column = "key" .. proto_note.column

	local startIsNan = startTime ~= startTime
	local endIsNan = endTime ~= endTime

	---@type {[1]: string, [2]: number}[]
	local sounds = {}
	for i, s in ipairs(proto_note.sounds) do
		sounds[i] = {s.name, s.volume / 100}
		self.chart.resources:add("sound", s.name, s.fallback_name)
	end

	if not endTime then
		if startIsNan then
			return
		end
		return self:getNote(startTime, column, "tap", sounds)
	end

	if startIsNan and endIsNan then
		return
	end

	if not startIsNan and endIsNan then
		return self:getNote(startTime, column, "shade")
	end
	if startIsNan and not endIsNan then
		return self:getNote(endTime, column, "shade")
	end

	if endTime < startTime then
		return self:getNote(startTime, column, "tap"), self:getNote(endTime, column, "shade")
	end

	local lnType = "hold"
	if self.mode == 2 then
		lnType = "drumroll"
	end

	local startNote = self:getNote(startTime, column, lnType, sounds, 1)
	local endNote = self:getNote(endTime, column, lnType, nil, -1)

	return startNote, endNote
end

function ChartDecoder:decodeBarlines()
	local layer = self.layer
	local chart = self.chart
	local visualColumns = self.visualColumns
	local column = "measure1"
	for _, offset in ipairs(self.osu.barlines) do
		local point = layer:getPoint(offset / 1000)
		local a = Note(visualColumns:getPoint(point, column), column, "shade")
		chart.notes:insert(a)
	end
end

return ChartDecoder
