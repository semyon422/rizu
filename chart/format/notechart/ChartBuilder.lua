local class = require("class")
local Chart = require("chart.model.Chart")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local MeasureLayer = require("chart.model.layers.MeasureLayer")
local IntervalLayer = require("chart.model.layers.IntervalLayer")
local Visual = require("chart.model.visual.Visual")
local Note = require("chart.model.notes.Note")

---@class chart.ChartBuilder
---@operator call: chart.ChartBuilder
local ChartBuilder = class()

function ChartBuilder:new()
	self.chart = Chart()
end

---@return chart.AbsoluteLayer
function ChartBuilder:createAbsoluteLayer()
	local layer = AbsoluteLayer()
	self.chart.layers.main = layer
	return layer
end

---@return chart.MeasureLayer
function ChartBuilder:createMeasureLayer()
	local layer = MeasureLayer()
	self.chart.layers.main = layer
	return layer
end

---@return chart.IntervalLayer
function ChartBuilder:createIntervalLayer()
	local layer = IntervalLayer()
	self.chart.layers.main = layer
	return layer
end

---@return chart.Layer
function ChartBuilder:getMainLayer()
	return self.chart.layers.main
end

---@param name string
function ChartBuilder:getVisual(name)
	local layer = self:getMainLayer()
	local visual = layer.visuals[name]
	if visual then
		return visual
	end

	visual = Visual()
	layer.visuals[name] = visual

	return visual
end

---@param file_name string
---@param offset number?
---@param volume number?
function ChartBuilder:setMainAudio(file_name, offset, volume)
	local chart = self.chart

	local layer = AbsoluteLayer()
	chart.layers.audio = layer

	local visual = Visual()
	layer.visuals.main = visual

	local vp = visual:getPoint(layer:getPoint(offset or 0))

	local note = Note(vp, "audio", "sample")
	note.data = {sounds = {{file_name, volume or 1}}}
	chart.resources:add("sound", file_name)

	chart.notes:insert(note)
end

return ChartBuilder
