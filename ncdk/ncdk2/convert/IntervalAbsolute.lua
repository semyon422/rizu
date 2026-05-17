local class = require("class")
local table_util = require("table_util")
local Tempo = require("ncdk2.to.Tempo")
local Measure = require("ncdk2.to.Measure")
local AbsolutePoint = require("ncdk2.tp.AbsolutePoint")
local AbsoluteLayer = require("ncdk2.layers.AbsoluteLayer")
local Restorer = require("ncdk2.visual.Restorer")

---@class ncdk2.IntervalAbsolute
---@operator call: ncdk2.IntervalAbsolute
local IntervalAbsolute = class()

---@param points ncdk2.IntervalPoint[]
---@return {[string]: ncdk2.AbsolutePoint}
function IntervalAbsolute:convertPoints(points)
	---@type {[string]: ncdk2.AbsolutePoint}
	local points_map = {}

	---@type {[ncdk2.Vertex]: number}
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

		---@cast p -ncdk2.IntervalPoint, +ncdk2.AbsolutePoint
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

---@param layer ncdk2.IntervalLayer
function IntervalAbsolute:convert(layer)
	local points = layer:getPointList()
	local points_map = self:convertPoints(points)

	local visuals = layer.visuals

	---@cast layer -ncdk2.IntervalLayer, +ncdk2.AbsoluteLayer
	setmetatable(layer, AbsoluteLayer)
	table_util.clear(layer)

	layer:new()
	layer.points = points_map
	layer.visuals = visuals

	layer:compute()
end

return IntervalAbsolute
