local class = require("class")
local Measure = require("chart.model.to.Measure")

---@class chartedit.Measures
---@operator call: chartedit.Measures
local Measures = class()

---@param point chartedit.Point
function Measures:insert(point)
	if point._measure then
		return
	end

	local measure = Measure()
	local _point = point

	local m = point.measure
	local p = point
	while p and p.prev and p.prev.measure == m and not p._measure do
		p = p.prev
	end

	if not p.prev then
		point = p
	end

	while point and point.measure == m and not point._measure do
		point.measure = measure
		point = point.next
	end

	_point._measure = measure
end

---@param point chartedit.Point
function Measures:remove(point)
	if not point._measure then
		return
	end

	local m = point._measure
	point._measure = nil

	local p = point
	while p and p.prev and p.prev.measure == m do
		p = p.prev
	end

	local new_m
	local _p = p
	if not p.prev then
		p = point
		while p and p.next and p.next.measure == m do
			p = p.next
		end
		if not p.next then
			new_m = nil
		else
			new_m = p.next.measure
		end
	else
		new_m = p.prev.measure
	end
	point = _p

	while point and point.measure == m do
		point.measure = new_m
		point = point.next
	end
end

return Measures
