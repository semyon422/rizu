local class = require("class")
local table_util = require("table_util")
local rbtree = require("rbtree")
local Fraction = require("chart.core.Fraction")
local Point = require("chart.chartedit.Point")
local Vertex = require("chart.chartedit.Interval")

local fraction_0 = Fraction(0)

---@class chartedit.Points
---@operator call: chartedit.Points
local Points = class()

---@param on_remove function?
function Points:new(on_remove)
	self.on_remove = on_remove
	self.points_tree = rbtree.new()
	self.search_point = Point()
end

function Points:initDefault()
	local v_1 = Vertex(0, 1)
	local v_2 = Vertex(1, 1)
	v_1.next, v_2.prev = v_2, v_1
	v_1.point = self:getPoint(v_1, Fraction(0))
	v_2.point = self:getPoint(v_2, Fraction(0))
	v_1.point._vertex = v_1
	v_2.point._vertex = v_2
end

---@return chartedit.Point?
function Points:getFirstPoint()
	local node = self.points_tree:min()
	return node and node.key
end

---@return chartedit.Point?
function Points:getLastPoint()
	local node = self.points_tree:max()
	return node and node.key
end

---@param vertex chartedit.Vertex
---@param time chart.Fraction
---@return chartedit.Point
function Points:getPoint(vertex, time)
	self.search_point:new(vertex, time)

	local node = self.points_tree:find(self.search_point)
	if node then
		return node.key
	end

	local point = Point(vertex, time)
	node = assert(self.points_tree:insert(point))
	local prev_node = node:prev()
	local next_node = node:next()
	local prev_point = prev_node and prev_node.key
	local next_point = next_node and next_node.key
	table_util.insert_linked(point, prev_point, next_point)

	local base_node = prev_node or next_node
	if base_node then
		point.measure = base_node.key.measure
	end

	return point
end

---@param point chartedit.Point
function Points:removePoint(point)
	assert(not rawequal(point, self.search_point), "can't remove search point")

	if self.on_remove then
		self.on_remove(point)
	end
	local node = self.points_tree:remove(point)
	table_util.remove_linked(point)

	--TODO: notes, sv
end

---@param object chartedit.Point
---@return chartedit.Point?
---@return chartedit.Point?
function Points:getInterp(object)
	local a, b = self.points_tree:find(object)
	a = a or b
	if not a then
		return
	end

	---@type chartedit.Point
	local key = a.key
	if key == object then
		return key, key
	elseif object > key then
		local _next = a:next()
		return key, _next and _next.key
	elseif object < key then
		local _prev = a:prev()
		return _prev and _prev.key, key
	end
end

---@param vertex chartedit.Vertex
---@param time chart.Fraction
---@return chartedit.Point?
function Points:interpolateFraction(vertex, time)
	local search_point = self.search_point

	search_point:new(vertex, time)

	local a, b = self:getInterp(search_point)
	if not a and not b then
		return
	elseif a == b then
		return a:clone(search_point)
	end

	if search_point == a then
		a:clone(search_point)
		return search_point
	end
	if search_point == b then
		b:clone(search_point)
		return search_point
	end

	search_point.prev = a
	search_point.next = b

	a = a or b

	search_point.measure = a.measure

	return search_point
end

---@param limit number
---@param time number
---@return chartedit.Point
function Points:interpolateAbsolute(limit, time)
	local search_point = self.search_point

	table_util.clear(search_point)

	assert(time, "missing time")
	search_point:new(time, fraction_0)

	local a, b = self:getInterp(search_point)
	if not a and not b then
		return
	elseif a == b then
		a:clone(search_point)
		return search_point
	end

	if search_point == a then
		a:clone(search_point)
		return search_point
	end
	if search_point == b then
		b:clone(search_point)
		return search_point
	end

	search_point.prev = a
	search_point.next = b

	a = a or b

	search_point:fromnumber(a.vertex, time, limit, a.measure)
	search_point.measure = a.measure

	return search_point
end

---@return chartedit.Point
function Points:saveSearchPoint()
	return self:getPoint(self.search_point:unpack())
end

return Points
