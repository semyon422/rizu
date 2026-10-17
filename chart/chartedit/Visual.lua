local class = require("class")
local table_util = require("table_util")
local VisualPoint = require("chart.chartedit.VisualPoint")

---@class chartedit.Visual
---@operator call: chartedit.Visual
---@field head chartedit.VisualPoint?
---@field p2vp {[chartedit.Point]: chartedit.VisualPoint}
local Visual = class()

---@param on_remove function?
function Visual:new(on_remove)
	self.on_remove = on_remove
	self.p2vp = {}
end

---@param point chartedit.Point
function Visual:getPoint(point)
	local p2vp = self.p2vp
	local vp = p2vp[point]
	if vp then
		return vp
	end

	vp = VisualPoint(point)
	p2vp[point] = vp

	if not self.head then
		self.head = vp
		return vp
	end

	local _vp = p2vp[point.prev]
	if not _vp then
		table_util.insert_linked(vp, nil, self.head)
		return vp
	end

	while _vp and _vp.next and _vp.next.point == _vp.point do
		_vp = _vp.next
	end

	table_util.insert_linked(vp, _vp, _vp.next)
	return vp
end

---@param point chartedit.Point
function Visual:removeAll(point)
	local p2vp = self.p2vp
	local vp = assert(p2vp[point])
	while vp and vp.point == point do
		self:remove(vp)
		vp = vp.next
	end
end

---@param vp chartedit.VisualPoint
function Visual:remove(vp)
	local p2vp = self.p2vp
	local p = vp.point
	if p2vp[p] ~= vp then
	elseif vp.next ~= p2vp[p.next] then
		p2vp[p] = vp.next
	else
		p2vp[p] = nil
	end
	local prev, _next = table_util.remove_linked(vp)
	if not prev then
		self.head = _next
	end
	if self.on_remove then
		self.on_remove(vp)
	end
end

---@param vp chartedit.VisualPoint
---@return chartedit.VisualPoint
function Visual:createAfter(vp)
	local _vp = VisualPoint(vp.point)
	table_util.insert_linked(_vp, vp, vp.next)
	return _vp
end

---@param vp chartedit.VisualPoint
---@return chartedit.VisualPoint
function Visual:createBefore(vp)
	local p2vp = self.p2vp
	local p = vp.point
	local _vp = VisualPoint(p)
	if p2vp[p] == vp then
		p2vp[p] = _vp
	end
	table_util.insert_linked(_vp, vp.prev, vp)
	return _vp
end

return Visual
