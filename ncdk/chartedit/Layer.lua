local class = require("class")
local Points = require("chartedit.Points")
local Vertices = require("chartedit.Intervals")

---@alias chartedit.PointNotes {[ncdk2.Column]: ncdk2.Note}

---@class chartedit.Layer
---@operator call: chartedit.Layer
---@field visuals {[string]: chartedit.Visual}
local Layer = class()

function Layer:new()
	self.visuals = {}
	self.points = Points(function(p) self:removeAllPointsVisual(p) end)
	self.vertices = Vertices(self.points)
end

---@param p chartedit.Point
function Layer:removeAllPointsVisual(p)
	for _, visual in pairs(self.visuals) do
		visual:removeAll(p)
	end
end

---@param start_time number
---@param end_time number
---@return fun(): chartedit.Point
function Layer:iter(start_time, end_time)
	return coroutine.wrap(function()
		local _p = self.points:interpolateAbsolute(1, start_time)
		local p = _p.prev or _p.next
		while p and p.absoluteTime <= end_time do
			coroutine.yield(p)
			p = p.next
		end
	end)
end

return Layer
