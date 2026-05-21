local class = require("class")
local table_util = require("table_util")
local Tempo = require("chart.model.to.Tempo")
local Measure = require("chart.model.to.Measure")
local AbsolutePoint = require("chart.model.tp.AbsolutePoint")
local AbsoluteLayer = require("chart.model.layers.AbsoluteLayer")
local Restorer = require("chart.model.visual.Restorer")

---@class chart.IntervalAbsolute
---@operator call: chart.IntervalAbsolute
local IntervalAbsolute = class()

---@param points chart.IntervalPoint[]
---@return {[string]: chart.AbsolutePoint}
function IntervalAbsolute:convertPoints(points)
	---@type {[string]: chart.AbsolutePoint}
	local points_map = {}

	---@type {[chart.Vertex]: number}
	local interval_tempos = {}

	for _, p in ipairs(points) do
		local _vertex = p._vertex
		if _vertex then
			interval_tempos[_vertex] = _vertex:getTempo()
		end
	end

	local first_measure = points[1].measure ~= nil

	for _, p in ipairs(points) do
		local _vertex = p._vertex
		local vertex = p.vertex
		local tempo = interval_tempos[vertex]

		local _measure = p._measure
		local measure = p.measure

		local time = p.time

		---@type ncdk.Fraction
		local beat_offset
		if measure then
			beat_offset = measure.offset
		end

		local absoluteTime = p.absoluteTime

		---@cast p -chart.IntervalPoint, +chart.AbsolutePoint
		setmetatable(p, AbsolutePoint)
		table_util.clear(p)

		if _vertex or _measure then
			p._tempo = Tempo(tempo)
			local offset = (time + (beat_offset or 0)) % 1
			if _measure or offset:tonumber() ~= 0 then
				p._measure = Measure(offset)
			end
		end

		if not first_measure and _vertex then
			first_measure = true
			p._measure = Measure()
		end

		p:new(absoluteTime)
		points_map[tostring(p)] = p
	end

	return points_map
end

---@param layer chart.IntervalLayer
function IntervalAbsolute:convert(layer)
	local points = layer:getPointList()
	local points_map = self:convertPoints(points)

	local visuals = layer.visuals

	---@cast layer -chart.IntervalLayer, +chart.AbsoluteLayer
	setmetatable(layer, AbsoluteLayer)
	table_util.clear(layer)

	layer:new()
	layer.points = points_map
	layer.visuals = visuals

	layer:compute()
end

return IntervalAbsolute
