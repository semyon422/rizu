local class = require("class")
local table_util = require("table_util")
local Vertex = require("chart.model.to.Interval")
local IntervalPoint = require("chart.model.tp.IntervalPoint")
local IntervalLayer = require("chart.model.layers.IntervalLayer")
local Restorer = require("chart.model.visual.Restorer")

---@class chart.MeasureInterval
---@operator call: chart.MeasureInterval
local MeasureInterval = class()

---@param points chart.MeasurePoint[]
---@return {[string]: chart.IntervalPoint}
function MeasureInterval:convertPoints(points)
	---@type {[string]: chart.IntervalPoint}
	local points_map = {}
	if #points == 0 then
		return points_map
	end

	local absoluteTime = 0

	---@type chart.IntervalPoint
	local last_point

	local prev_stop = false

	---@type chart.Tempo?
	local _tempo
	local stop_beats = 0
	for _, p in ipairs(points) do
		_tempo = p._tempo
		local _stop = p._stop

		if prev_stop then
			stop_beats = stop_beats + 1
		end

		local beatTime = assert(p.beatTime) + stop_beats
		absoluteTime = assert(p.absoluteTime)

		---@cast p -chart.MeasurePoint, +chart.IntervalPoint
		setmetatable(p, IntervalPoint)
		table_util.clear(p)

		p:new(beatTime)
		points_map[tostring(p)] = p
		if _tempo or _stop or prev_stop then
			p._vertex = Vertex(absoluteTime)
			prev_stop = _stop ~= nil
		end
		last_point = p
	end

	-- Non empty MeasureLayer always have at least one Tempo object
	---@cast _tempo chart.Tempo

	if #points == 1 then
		last_point = IntervalPoint(last_point.time + 1)
		points_map[tostring(last_point)] = last_point
		absoluteTime = absoluteTime + _tempo:getBeatDuration()
	end

	if not last_point._vertex then
		last_point._vertex = Vertex(absoluteTime)
	end

	return points_map
end

---@param layer chart.MeasureLayer
function MeasureInterval:convert(layer)
	for _, visual in pairs(layer.visuals) do
		Restorer:restore(visual.points)
	end

	local points = layer:getPointList()
	local points_map = self:convertPoints(points)

	local visuals = layer.visuals

	---@cast layer -chart.MeasureLayer, +chart.IntervalLayer
	setmetatable(layer, IntervalLayer)
	table_util.clear(layer)

	layer:new()
	layer.points = points_map
	layer.visuals = visuals

	layer:compute()
end

return MeasureInterval
