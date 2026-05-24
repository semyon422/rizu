local IChartDecoder = require("chart.format.notechart.IChartDecoder")
local Chart = require("chart.model.Chart")
local Note = require("chart.model.notes.Note")
local Velocity = require("chart.model.visual.Velocity")
local Tempo = require("chart.model.to.Tempo")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local InputMode = require("chart.core.InputMode")
local Barlines = require("chart.format.osu.Barlines")
local PrimaryTempo = require("chart.format.osu.PrimaryTempo")
local tinyyaml = require("tinyyaml")
local Visual = require("chart.model.visual.Visual")
local Chartmeta = require("sea.chart.Chartmeta")
local Timings = require("sea.chart.Timings")
local Healths = require("sea.chart.Healths")

---@class chart.quaver.ChartDecoder: chart.IChartDecoder
---@operator call: chart.quaver.ChartDecoder
local ChartDecoder = IChartDecoder + {}

function ChartDecoder:new()
end

---@param s string
---@param hash string?
---@return {chart: chart.Chart, chartmeta: sea.Chartmeta}[]
function ChartDecoder:decode(s, hash)
	self.hash = hash
	local qua = tinyyaml.parse(s:gsub("\r\n", "\n"))
	local chart, chartmeta = self:decodeQua(qua)
	return {{
		chart = chart,
		chartmeta = chartmeta,
	}}
end

---@param qua table
---@return chart.Chart
---@return sea.Chartmeta
function ChartDecoder:decodeQua(qua)
	self.qua = qua

	local chart = Chart()
	self.chart = chart

	local layer = AbsoluteLayer()
	chart.layers.main = layer
	self.layer = layer

	local visual = Visual()
	layer.visuals.main = visual
	self.visual = visual

	if qua.BPMDoesNotAffectScrollVelocity then
		visual.tempoMultiplyTarget = "none"
	end
	visual.primaryTempo = 120

	self:decodeTempos()
	self:decodeVelocities()
	self:decodeNotes()

	local tempo_points = self:getTempoPoints()
	self:decodeBarlines(tempo_points)
	self.primary_tempo, self.min_tempo, self.max_tempo = PrimaryTempo:compute(tempo_points, self.maxTime * 1000)

	self:addAudio()

	self.columns = tonumber(qua.Mode:sub(-1, -1))
	chart.inputMode = InputMode({key = self.columns})

	chart:compute()

	local chartmeta = self:getChartmeta()

	return chart, chartmeta
end

---@return sea.Chartmeta
function ChartDecoder:getChartmeta()
	local qua = self.qua

	local chartmeta = {
		hash = self.hash,
		index = 1,
		format = "quaver",
		title = tostring(qua["Title"]),  -- yaml can parse it as number
		artist = tostring(qua["Artist"]),
		source = tostring(qua["Source"]),
		tags = tostring(qua["Tags"]),
		name = tostring(qua["DifficultyName"]),
		creator = tostring(qua["Creator"]),
		audio_path = tostring(qua["AudioFile"]),
		background_path = tostring(qua["BackgroundFile"]),
		preview_time = (qua["SongPreviewTime"] or 0) / 1000,
		inputmode = tostring(self.chart.inputMode),
		tempo = self.primary_tempo,
		tempo_avg = self.primary_tempo,
		tempo_min = self.min_tempo,
		tempo_max = self.max_tempo,
		timings = Timings("quaver"),
	}
	setmetatable(chartmeta, Chartmeta)
	---@cast chartmeta sea.Chartmeta

	assert(chartmeta:validate())

	return chartmeta
end

function ChartDecoder:addAudio()
	local audioFileName = self.qua.AudioFile
	if not audioFileName or audioFileName == "virtual" then
		return
	end

	local audio_layer = AbsoluteLayer()
	self.chart.layers.audio = audio_layer

	local visual = Visual()
	audio_layer.visuals.main = visual

	local visualPoint = visual:getPoint(audio_layer:getPoint(0))

	local note = Note(visualPoint, "audio", "sample")
	note.data.sounds = {{audioFileName, 1}}
	self.chart.resources:add("sound", audioFileName)

	self.chart.notes:insert(note)
end

function ChartDecoder:decodeTempos()
	local layer = self.layer
	local visual = self.visual
	for _, tp in ipairs(self.qua.TimingPoints) do
		if tp.Bpm then
			local point = layer:getPoint((tp.StartTime or 0) / 1000)
			point._tempo = Tempo(tp.Bpm)
			visual:getPoint(point)
			-- do something with tp.Singature
		end
	end
end

function ChartDecoder:decodeVelocities()
	local layer = self.layer
	local visual = self.visual
	for _, sv in ipairs(self.qua.SliderVelocities) do
		local point = layer:getPoint((sv.StartTime or 0) / 1000)
		local visualPoint = visual:getPoint(point)
		visualPoint._velocity = Velocity(tonumber(sv.Multiplier) or 1)
	end
end

function ChartDecoder:decodeNotes()
	local chart = self.chart

	self.maxTime = 0
	self.minTime = math.huge
	for _, obj in ipairs(self.qua.HitObjects) do
		local a, b = self:getNotes(obj)
		if a then
			chart.notes:insert(a)
		end
		if b then
			chart.notes:insert(b)
		end
	end
end

---@param time number
---@param noteType string
---@param sounds table?
---@return chart.Note
function ChartDecoder:getNote(time, column, noteType, sounds)
	local point = self.layer:getPoint(time)
	local visualPoint = self.visual:getPoint(point)
	local note = Note(visualPoint, column, noteType)
	note.data.sounds = sounds
	return note
end

---@param obj table
---@return chart.Note?
---@return chart.Note?
function ChartDecoder:getNotes(obj)
	local startTime = obj.StartTime and obj.StartTime / 1000
	local endTime = obj.EndTime and obj.EndTime / 1000
	local column = "key" .. obj.Lane

	if startTime then
		self.maxTime = math.max(self.maxTime, startTime)
		self.minTime = math.min(self.minTime, startTime)
	end
	if endTime then
		self.maxTime = math.max(self.maxTime, endTime)
		self.minTime = math.min(self.minTime, endTime)
	end

	---@type {[1]: string, [2]: number}[]
	local sounds = {}  -- TODO: fix hitsounds/keysounds

	if not endTime then
		return self:getNote(startTime, column, "tap", sounds)
	end

	if endTime < startTime then
		return self:getNote(startTime, column, "hold"), self:getNote(endTime, column, "shade")
	end

	local startNote = self:getNote(startTime, column, "hold", sounds)
	local endNote = self:getNote(endTime, column, "hold")
	startNote.weight = 1
	endNote.weight = -1

	return startNote, endNote
end

---@return chart.osu.FilteredPoint[]
function ChartDecoder:getTempoPoints()
	---@type osu.FilteredPoint[]
	local tempo_points = {}

	for _, tp in ipairs(self.qua.TimingPoints) do
		if tp.Bpm then
			table.insert(tempo_points, {
				offset = tp.StartTime or 0,
				beatLength = 60000 / tp.Bpm,
				signature = tp.Singature or 4,
			})
		end
	end

	return tempo_points
end

function ChartDecoder:decodeBarlines(tempo_points)
	local barlines = Barlines:generate(tempo_points, self.maxTime * 1000)
	local visual = self.visual
	local layer = self.layer
	local chart = self.chart
	local column = "measure1"
	for _, offset in ipairs(barlines) do
		local point = layer:getPoint(offset / 1000)
		local a = Note(visual:getPoint(point), column, "shade")
		chart.notes:insert(a)
	end
end

return ChartDecoder
