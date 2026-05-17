local class = require("class")
local table_util = require("table_util")
local Vertex = require("ncdk2.to.Interval")
local IntervalPoint = require("ncdk2.tp.IntervalPoint")
local IntervalLayer = require("ncdk2.layers.IntervalLayer")
local Restorer = require("ncdk2.visual.Restorer")

---@class ncdk2.MeasureInterval
---@operator call: ncdk2.MeasureInterval
local MeasureInterval = class()

---@param points ncdk2.MeasurePoint[]
---@return {[string]: ncdk2.IntervalPoint}
function MeasureInterval:convertPoints(points)
	---@type {[string]: ncdk2.IntervalPoint}
	local points_map = {}
	if #points == 0 then
		return points_map
	end

	local absoluteTime = 0

	---@type ncdk2.IntervalPoint
	local last_point

	local prev_stop = false

	---@type ncdk2.Tempo?
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

		---@cast p -ncdk2.MeasurePoint, +ncdk2.IntervalPoint
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
	---@cast _tempo ncdk2.Tempo

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

---@param layer ncdk2.MeasureLayer
function MeasureInterval:convert(layer)
	for _, visual in pairs(layer.visuals) do
		Restorer:restore(visual.points)
	end

	local points = layer:getPointList()
	local points_map = self:convertPoints(points)

	local visuals = layer.visuals

	---@cast layer -ncdk2.MeasureLayer, +ncdk2.IntervalLayer
	setmetatable(layer, IntervalLayer)
	table_util.clear(layer)

	layer:new()
	layer.points = points_map
	layer.visuals = visuals

	layer:compute()
end

return MeasureInterval
