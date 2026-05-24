local string_util = require("string_util")
local IChartDecoder = require("chart.format.notechart.IChartDecoder")
local Chart = require("chart.model.Chart")
local Note = require("chart.format.notechart.Note")
local Signature = require("chart.model.to.Signature")
local Tempo = require("chart.model.to.Tempo")
local MeasureLayer = require("chart.model.layers.MeasureLayer")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local InputMode = require("chart.core.InputMode")
local Fraction = require("chart.core.Fraction")
local EncodingConverter = require("chart.format.notechart.EncodingConverter")
local Ksh = require("chart.format.ksm.Ksh")
local Visual = require("chart.model.visual.Visual")
local Chartmeta = require("sea.chart.Chartmeta")
local Timings = require("sea.chart.Timings")
local Healths = require("sea.chart.Healths")

---@class chart.ksm.ChartDecoder: chart.IChartDecoder
---@operator call: chart.ksm.ChartDecoder
local ChartDecoder = IChartDecoder + {}

local encodings = {
	"SHIFT-JIS",
	"ISO-8859-1",
	"CP932",
	"EUC-KR",
	"US-ASCII",
	"CP1252",
}

function ChartDecoder:new()
	self.conv = EncodingConverter(encodings)
end

---@param s string
---@param hash string?
---@return {chart: chart.Chart, chartmeta: sea.Chartmeta}[]
function ChartDecoder:decode(s, hash)
	self.hash = hash
	local ksh = Ksh(s)
	local content = s:gsub("\r\n", "\n")
	content = self.conv:convert(content)
	ksh:import(content)
	local chart, chartmeta = self:decodeKsh(ksh)
	return {{
		chart = chart,
		chartmeta = chartmeta,
	}}
end

---@param ksh chart.ksm.Ksh
---@return chart.Chart
---@return sea.Chartmeta
function ChartDecoder:decodeKsh(ksh)
	self.ksh = ksh

	local chart = Chart()
	self.chart = chart

	local layer = MeasureLayer()
	chart.layers.main = layer
	self.layer = layer

	local visual = Visual()
	layer.visuals.main = visual
	self.visual = visual

	chart.inputMode = InputMode({
		bt = 4,
		fx = 2,
		laserleft = 2,
		laserright = 2,
	})

	self:processTempos()
	self:processSignatures()
	self:processNotes()
	self:processAudio()
	self:processMeasureLines()

	chart:compute()

	self:updateLength()
	local chartmeta = self:getChartmeta()

	return chart, chartmeta
end

function ChartDecoder:updateLength()
	if self.maxPoint and self.minPoint then
		self.totalLength = self.maxPoint.absoluteTime - self.minPoint.absoluteTime
		self.minTime = self.minPoint.absoluteTime
		self.maxTime = self.maxPoint.absoluteTime
	else
		self.totalLength = 0
		self.minTime = 0
		self.maxTime = 0
	end
end

---@return sea.Chartmeta
function ChartDecoder:getChartmeta()
	local ksh = self.ksh
	local options = ksh.options

	local chartmeta = {
		hash = self.hash,
		index = 1,
		format = "ksm",
		title = options["title"],
		artist = options["artist"],
		name = options["difficulty"],
		creator = options["effect"],
		level = tonumber(options["level"]),
		tempo = tonumber(options["t"]) or 0,
		audio_path = self.audioFileName,
		background_path = options["jacket"],
		preview_time = (options["plength"] or 0) / 1000,
		inputmode = tostring(self.chart.inputMode),
	}
	setmetatable(chartmeta, Chartmeta)
	---@cast chartmeta sea.Chartmeta

	assert(chartmeta:validate())

	return chartmeta
end

function ChartDecoder:processTempos()
	local layer = self.layer
	for _, _tempo in ipairs(self.ksh.tempos) do
		local measureTime = Fraction(_tempo.lineOffset, _tempo.lineCount) + _tempo.measureOffset
		local point = layer:getPoint(measureTime)
		point._tempo = Tempo(_tempo.tempo)
		self.visual:getPoint(point)
	end
end

function ChartDecoder:processSignatures()
	local layer = self.layer
	for _, _signature in ipairs(self.ksh.timeSignatures) do
		local measureTime = Fraction(_signature.measureIndex)
		local point = layer:getPoint(measureTime)
		point._signature = Signature(Fraction(_signature.n * 4, _signature.d))
		self.visual:getPoint(point)
	end
end

function ChartDecoder:processAudio()
	local audio = self.ksh.options.m
	local split = string_util.split(audio, ";")
	if split[1] then
		audio = split[1]
	end
	if not audio then
		return
	end

	local audio_layer = AbsoluteLayer()
	self.chart.layers.audio = audio_layer

	local audio_visual = Visual()
	audio_layer.visuals.main = audio_visual

	local offset = -(tonumber(self.ksh.options.o) or 0) / 1000
	local visualPoint = audio_visual:getPoint(audio_layer:getPoint(offset))

	local note = Note(visualPoint, "audio", "sample")
	note.data.sounds = {{audio, 1}}
	self.chart.resources:add("sound", audio)

	self.chart.notes:insert(note)
end

function ChartDecoder:processNotes()
	local layer = self.layer
	local visual = self.visual
	local chart = self.chart

	self.minPoint = nil
	self.maxPoint = nil

	local allNotes = {}
	for _, note in ipairs(self.ksh.notes) do
		allNotes[#allNotes + 1] = note
	end
	for _, laser in ipairs(self.ksh.lasers) do
		allNotes[#allNotes + 1] = laser
	end

	for _, _note in ipairs(allNotes) do
		local startMeasureTime = Fraction(_note.startLineOffset, _note.startLineCount) + _note.startMeasureOffset
		local point = layer:getPoint(startMeasureTime)
		local visualPoint = visual:getPoint(point)

		local inputType = _note.input
		local inputIndex = _note.lane
		if inputType == "fx" then
			inputIndex = _note.lane - 4
		end

		local column = inputType .. inputIndex
		local startNote = Note(visualPoint, column)

		chart.notes:insert(startNote)

		local lastPoint = point
		local endMeasureTime = Fraction(_note.endLineOffset, _note.endLineCount) + _note.endMeasureOffset

		if startMeasureTime == endMeasureTime then
			startNote.type = "tap"
		else
			if _note.input ~= "laser" then
				startNote.type = "hold"
			else
				startNote.type = "laser"
			end
			startNote.weight = 1

			local end_point = layer:getPoint(endMeasureTime)
			local end_visualPoint = visual:getPoint(end_point)

			local endNote = Note(end_visualPoint, column)

			if _note.input ~= "laser" then
				endNote.type = "hold"
			else
				endNote.type = "laser"
			end
			endNote.weight = -1

			chart.notes:insert(endNote)

			lastPoint = end_point
		end

		if not self.minPoint or point < self.minPoint then
			self.minPoint = point
		end
		if not self.maxPoint or lastPoint > self.maxPoint then
			self.maxPoint = lastPoint
		end
	end
end

function ChartDecoder:processMeasureLines()
	local layer = self.layer
	local visual = self.visual
	local chart = self.chart
	for measureIndex = 0, #self.ksh.measureStrings do
		local point = layer:getPoint(Fraction(measureIndex))
		local note = Note(visual:getPoint(point), "measure1", "shade")
		chart.notes:insert(note)
	end
end

return ChartDecoder
