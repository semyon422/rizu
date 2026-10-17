local class = require("class")
local table_util = require("table_util")
local Vertex = require("chart.chartedit.Interval")

---@class chartedit.Vertices
---@operator call: chartedit.Vertices
local Vertices = class()

Vertices.minBeatDuration = 60 / 1000

---@param points chartedit.Points
function Vertices:new(points)
	self.points = points
end

---@param point chartedit.Point
---@param beats integer
---@return chartedit.Vertex
function Vertices:_setVertex(point, beats)
	local new_vertex = Vertex(point.absoluteTime, beats)
	new_vertex.point = point
	point._vertex = new_vertex
	return new_vertex
end

---@param point chartedit.Point
function Vertices:splitVertex(point)
	local _vertex = assert(point.vertex)

	local time = point.time
	local _beats = time:floor()

	---@type chartedit.Vertex
	local vertex
	if time[1] > 0 then
		local beats = _vertex.next and _vertex.beats - _beats or 1
		vertex = self:_setVertex(point, beats)
		table_util.insert_linked(vertex, _vertex, _vertex.next)
		_vertex.beats = _beats
	else
		vertex = self:_setVertex(point, -_beats)
		table_util.insert_linked(vertex, nil, _vertex)
		point = self.points:getFirstPoint()
	end
	while point and point.vertex == _vertex and point._vertex ~= _vertex do
		point.vertex = vertex
		point.time = point.time - _beats
		point = point.next
	end
end

---@param point chartedit.Point
function Vertices:mergeVertex(point)
	local _vertex = point._vertex
	if not _vertex then
	-- if not _vertex or self.ranges.vertex.tree.size == 2 then
		return
	end

	point._vertex = nil
	local _prev, _next = table_util.remove_linked(_vertex)

	local _beats, vertex
	if _prev then
		_beats = _prev.beats
		_prev.beats = _next and _prev.beats + _vertex.beats or 1
		vertex = _prev
	elseif _next then
		_beats = -_vertex.beats
		point = self.points:getFirstPoint()
		vertex = _next
	end

	while point and point.vertex == _vertex do
		point.vertex = vertex
		point.time = point.time + _beats
		point = point.next
	end
end

---@param vertex chartedit.Vertex
---@param offset number
function Vertices:moveVertex(vertex, offset)
	if vertex.offset == offset then
		return
	end
	local minTime, maxTime = -math.huge, math.huge
	if vertex.prev then
		minTime = vertex.prev.offset + self.minBeatDuration * vertex.prev:getDuration()
	end
	if vertex.next then
		maxTime = vertex.next.offset - self.minBeatDuration * vertex:getDuration()
	end
	if minTime >= maxTime then
		return
	end
	vertex.offset = math.min(math.max(offset, minTime), maxTime)
end

---@param vertex chartedit.Vertex
---@param beats number
function Vertices:updateVertex(vertex, beats)
	local a, b = vertex, vertex.next
	if not b then
		return
	end

	assert(math.floor(beats) == beats)
	beats = math.max(beats, a:start() >= b:start() and 1 or 0)

	if beats == a.beats then
		return
	end

	local _a, _b = a.point, b.point

	local maxBeats = (_b.absoluteTime - _a.absoluteTime) / self.minBeatDuration + a:start() - b:start()
	beats = math.min(beats, math.floor(maxBeats))

	if beats < vertex.beats then
		local p = b.point.prev
		while p and p ~= _a and p.time >= b:start() + beats do
			self.points:removePoint(p)
			p = p.prev
		end
	end
	vertex.beats = beats
end

return Vertices
