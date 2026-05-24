local class = require("class")

---@class rizu.editor.IntervalManager
---@operator call: rizu.editor.IntervalManager
local IntervalManager = class()

---@param vertex chartedit.Vertex
function IntervalManager:grab(vertex)
	self.grabbedVertex = vertex
end

function IntervalManager:drop()
	self.grabbedVertex = nil
end

---@return boolean
function IntervalManager:isGrabbed()
	return self.grabbedVertex ~= nil
end

---@param time number
function IntervalManager:moveGrabbed(time)
	self.editorModel.layer.vertices:moveVertex(self.grabbedVertex, time)
end

---@param point chartedit.Point
---@return chartedit.Vertex
function IntervalManager:split(point)
	local layer = self.editorModel.layer
	local p = layer.points:getPoint(point:unpack())
	layer.visuals.main:getPoint(p)
	return layer.vertices:splitVertex(p)
end

---@param point chartedit.Point
function IntervalManager:merge(point)
	self.editorModel.layer.vertices:mergeVertex(point)
end

---@param vertex chartedit.Vertex
---@param beats number
function IntervalManager:update(vertex, beats)
	self.editorModel.layer.vertices:updateVertex(vertex, beats)
end

return IntervalManager
