local valid = require("valid")
local IChartDecoder = require("notechart.IChartDecoder")
local Chart = require("ncdk2.Chart")
local Sph = require("sph.Sph")
local Note = require("notechart.Note")
local Velocity = require("ncdk2.visual.Velocity")
local Expand = require("ncdk2.visual.Expand")
local Measure = require("ncdk2.to.Measure")
local Vertex = require("ncdk2.to.Interval")
local IntervalLayer = require("ncdk2.layers.IntervalLayer")
local InputMode = require("ncdk.InputMode")
local Fraction = require("ncdk.Fraction")
local Visual = require("ncdk2.visual.Visual")
local Chartmeta = require("sea.chart.Chartmeta")

---@class sph.ChartDecoder: chartbase.IChartDecoder
---@operator call: sph.ChartDecoder
local ChartDecoder = IChartDecoder + {}

function ChartDecoder:new()
end

---@param s string
---@param hash string?
---@return {chart: ncdk2.Chart, chartmeta: sea.Chartmeta}[]
function ChartDecoder:decode(s, hash)
	self.hash = hash
	local sph = Sph()
	sph:decode(s:gsub("\r[\r\n]?", "\n"))
	local chart, chartmeta = self:decodeSph(sph)
	return {{
		chart = chart,
		chartmeta = chartmeta,
	}}
end

---@param sph sph.Sph
---@return ncdk2.Chart
---@return sea.Chartmeta
function ChartDecoder:decodeSph(sph)
	self.sph = sph

	local chart = Chart()
	self.chart = chart

	chart.inputMode = InputMode(assert(sph.metadata:get("input")))
	self.inputMap = chart.inputMode:getInputs()

	local layer = IntervalLayer()
	chart.layers.main = layer
	self.layer = layer

	---@type ncdk2.Point?
	self.close_point = nil

	---@type {[string]: true}
	self.close_visuals = {}

	for _, line in ipairs(sph.sphLines.protoLines) do
		self:processLine(line)
	end

	self:addAudio()

	chart:compute()

	local chartmeta = self:getChartmeta()

	return chart, chartmeta
end

---@param name string
function ChartDecoder:getVisual(name)
	local visual = self.layer.visuals[name]
	if visual then
		return visual
	end

	visual = Visual()
	self.layer.visuals[name] = visual

	return visual
end

---@param line sph.ProtoLine
function ChartDecoder:processLine(line)
	local layer = self.layer
	local chart = self.chart
	local sounds = self.sph.sounds
	local inputMap = self.inputMap
	local close_point = self.close_point
	local close_visuals = self.close_visuals

	local line_visual = line.visual or ""
	local visual = self:getVisual(line_visual)

	local point = layer:getPoint(line.globalTime)

	if close_point and close_point ~= point then
		for v in pairs(close_visuals) do
			self:getVisual(v):newPoint(close_point)
			close_visuals[v] = nil
		end
		self.close_point = nil
	end
	close_visuals[line_visual] = nil

	local visualPoint = visual:newPoint(point)

	if line.offset then
		point._vertex = Vertex(line.offset)
	end

	visualPoint.comment = line.comment

	local line_sounds = line.sounds or {}
	local line_volume = line.volume or {}
	local notes = line.notes or {}

	for i, _note in ipairs(notes) do
		local col = _note.column
		local column = inputMap[col]

		local note = Note(visualPoint, column)

		local sound = sounds[line_sounds[i]]
		if sound then
			note.data.sounds = {{sound, line_volume[i] or 1}}
			self.chart.resources:add("sound", sound)
		end

		local t = _note.type
		if t == "1" then
			note.type = "tap"
		elseif t == "2" then
			note.type = "hold"
			note.weight = 1
		elseif t == "3" then
			note.type = "hold"
			note.weight = -1
		elseif t == "4" then
			note.type = "shade"
		end

		chart.notes:insert(note)
	end

	for i = #notes + 1, #line_sounds do
		local sound = sounds[line_sounds[i]]
		if sound then
			local column = "auto" .. (i - #notes)
			local note = Note(visualPoint, column, "sample")
			note.data.sounds = {{sound, line_volume[i] or 1}}
			self.chart.resources:add("sound", sound)
			chart.notes:insert(note)
		end
	end

	if line.velocity then
		visualPoint._velocity = Velocity(unpack(line.velocity, 1, 3))
	end
	if line.expand and line.expand ~= 0 then
		visualPoint._expand = Expand(line.expand)
		self.close_point = point
		close_visuals[line_visual] = true
	end
	if line.measure then
		point._measure = Measure(line.measure)
	end

	if #notes > 0 then
		self:updateBoundaries(point)
	end
end

---@param point ncdk2.IntervalPoint
function ChartDecoder:updateBoundaries(point)
	if not self.minTimePoint or point < self.minTimePoint then
		self.minTimePoint = point
	end
	if not self.maxTimePoint or point > self.maxTimePoint then
		self.maxTimePoint = point
	end
end

function ChartDecoder:addAudio()
	local sph = self.sph
	local audio = sph.metadata:get("audio")
	if not audio then
		return
	end

	local layer = IntervalLayer()
	self.chart.layers.audio = layer

	local visual = Visual()
	layer.visuals.main = visual

	local point = layer:getPoint(Fraction(0))
	point._vertex = Vertex(0)
	local vp = visual:getPoint(point)

	local note = Note(vp, "audio", "sample")
	note.data.sounds = {{audio, 1}}
	self.chart.resources:add("sound", audio)

	self.chart.notes:insert(note)
end

---@return sea.Chartmeta
function ChartDecoder:getChartmeta()
	local chart = self.chart
	local sph = self.sph

	local totalLength, minTime, maxTime = 0, 0, 0
	if self.maxTimePoint then
		totalLength = self.maxTimePoint.absoluteTime - self.minTimePoint.absoluteTime
		minTime = self.minTimePoint.absoluteTime
		maxTime = self.maxTimePoint.absoluteTime
	end

	local layer = self.chart.layers.main

	---@type ncdk2.IntervalPoint[]
	local points = layer:getPointList()

	local a = points[1]
	local b = points[#points]
	local beats = (b.time - a.time):tonumber()
	local avgBeatDuration = (b.absoluteTime - a.absoluteTime) / beats

	local chartmeta = sph.metadata:toChartmeta()

	chartmeta.hash = self.hash
	chartmeta.index = 1
	chartmeta.tempo = 60 / avgBeatDuration

	setmetatable(chartmeta, Chartmeta)
	---@cast chartmeta sea.Chartmeta

	assert(valid.format(chartmeta:validate()))

	return chartmeta
end

return ChartDecoder
