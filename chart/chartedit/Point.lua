local IPoint = require("chart.model.tp.IPoint")
local table_util = require("table_util")
local Fraction = require("chart.core.Fraction")

---@class chartedit.Point: chart.IPoint
---@operator call: chartedit.Point
---@field _measure chart.Measure?
---@field measure chart.Measure?
---@field _vertex chartedit.Vertex?
---@field vertex chartedit.Vertex
---@field absoluteTime number
---@field prev chartedit.Point?
---@field next chartedit.Point?
local Point = IPoint + {}

---@param p chartedit.Point
---@param k any
---@param v any
function Point.__index(p, k, v)
	if k == "absoluteTime" then
		return p:tonumber()
	end
	return Point[k]
end

---@param vertex chartedit.Vertex
---@param time chart.Fraction
function Point:new(vertex, time)
	self.vertex = vertex
	self.time = time
end

---@return chartedit.Vertex
---@return chart.Fraction
function Point:unpack()
	return self.vertex, self.time
end

---@param point chartedit.Point?
---@return chartedit.Point
function Point:clone(point)
	assert(not rawequal(self, point), "not allowed to clone to itself")
	point = point or Point()
	table_util.clear(point)
	table_util.copy(self, point)
	return point
end

---@return chart.Fraction
function Point:getBeatModulo()
	local measure = self.measure
	if not measure then
		return self.time % 1
	end
	return (self.time + measure.offset) % 1
end

---@return chart.Fraction
function Point:getGlobalTime()
	local beat_offset = 0
	local vertex = self.vertex.prev
	while vertex do
		beat_offset = beat_offset + vertex.beats
		vertex = vertex.prev
	end
	return self.time + beat_offset
end

---@param vertex chartedit.Vertex
---@param time chart.Fraction
---@return chartedit.Vertex
---@return chart.Fraction
local function add(vertex, time)
	if vertex.next and time >= vertex:_end() then
		time = time - vertex.beats
		vertex = vertex.next
		return add(vertex, time)
	elseif vertex.prev and time < vertex:start() then
		vertex = vertex.prev
		time = time + vertex.beats
		return add(vertex, time)
	end
	return vertex, time
end

---@param duration chart.Fraction
---@return chartedit.Vertex
---@return chart.Fraction
function Point:add(duration)
	return add(self.vertex, self.time + duration)
end

---@param id1 chartedit.Vertex
---@param t1 chart.Fraction
---@param id2 chartedit.Vertex
---@param t2 chart.Fraction
---@return chart.Fraction
local function sub(id1, t1, id2, t2)
	if id1 > id2 then
		return sub(id1.prev, t1 + id1.prev.beats, id2, t2)
	elseif id1 < id2 then
		return -sub(id2, t2, id1, t1)
	end
	return t1 - t2
end

---@param point chartedit.Point
---@return chart.Fraction
function Point:sub(point)
	return sub(
		self.vertex,
		self.time,
		point.vertex,
		point.time
	)
end

---@return number
function Point:tonumber()
	local vertex = self.vertex
	if type(vertex) == "number" then
		return vertex
	end
	if vertex:isSingle() then
		return vertex.offset
	end
	local a, b, offset = vertex:getPair()
	local time = self.time:tonumber() - a:startn() + (offset and a.beats or 0)
	return a.offset + a:getBeatDuration() * time
end

---@param vertex chartedit.Vertex
---@param t number
---@param limit number
---@param measure chart.Measure?
function Point:fromnumber(vertex, t, limit, measure)
	local a, b, offset = vertex:getPair()
	local time = (t - a.offset) / a:getBeatDuration() + a:startn()
	if offset then
		time = time - a.beats
		a = b
	end
	local m_offset = measure and measure.offset or 0
	time = Fraction(time + m_offset, limit, true) - m_offset -- TODO: better code
	if not offset and time == a:_end() then
		time = b:start()
		a = b
	end
	self:new(a, time)
end

---@param a chartedit.Point
---@return string
function Point.__tostring(a)
	return ("Point(%s, %s)"):format(a.vertex, a.time)
end

---@param a chartedit.Point
---@param b chartedit.Point
---@return number?
---@return number?
local function number_intervals(a, b)
	local ia, ib = a.vertex, b.vertex
	local ta, tb = type(ia) == "table", type(ib) == "table"
	if ta and tb then
		return
	end
	if ta then
		ia = a.absoluteTime
	end
	if tb then
		ib = b.absoluteTime
	end
	return ia, ib
end

---@param a chartedit.Point
---@param b chartedit.Point
---@return boolean
function Point.__eq(a, b)
	local na, nb = number_intervals(a, b)
	if na then return na == nb end
	local ai, bi = a.vertex, b.vertex
	return ai == bi and a.time == b.time
end

---@param a chartedit.Point
---@param b chartedit.Point
---@return boolean
function Point.__lt(a, b)
	local na, nb = number_intervals(a, b)
	if na then return na < nb end
	local ai, bi = a.vertex, b.vertex
	return ai < bi or ai == bi and a.time < b.time
end

---@param a chartedit.Point
---@param b chartedit.Point
---@return boolean
function Point.__le(a, b)
	local na, nb = number_intervals(a, b)
	if na then return na <= nb end
	local ai, bi = a.vertex, b.vertex
	return ai < bi or ai == bi and a.time < b.time or ai == bi and a.time == b.time
end

return Point
