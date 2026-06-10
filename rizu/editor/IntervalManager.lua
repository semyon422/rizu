local class = require("class")
local IntervalUpdateSnapshot = require("rizu.editor.IntervalUpdateSnapshot")

---@class rizu.editor.IntervalManager
---@operator call: rizu.editor.IntervalManager
local IntervalManager = class()

---@param vertex chartedit.Vertex
function IntervalManager:grab(vertex)
	self.grabbedVertex = vertex
	self.grabbedVertexOffset = vertex.offset
end

function IntervalManager:drop()
	local vertex = self.grabbedVertex
	local offset = self.grabbedVertexOffset
	if vertex and offset and vertex.offset ~= offset then
		self.editorModel.editorChanges:reset()
		self.editorModel.editorChanges:add(
			self.editorModel.editorChanges:command(self, "setOffset", vertex, vertex.offset),
			self.editorModel.editorChanges:command(self, "setOffset", vertex, offset)
		)
		self.editorModel.editorChanges:next()
	end
	self.grabbedVertex = nil
	self.grabbedVertexOffset = nil
end

---@return boolean
function IntervalManager:isGrabbed()
	return self.grabbedVertex ~= nil
end

---@param time number
function IntervalManager:moveGrabbed(time)
	self.editorModel.layer.vertices:moveVertex(self.grabbedVertex, time)
end

---@param vertex chartedit.Vertex
---@param offset number
function IntervalManager:setOffset(vertex, offset)
	self.editorModel.layer.vertices:moveVertex(vertex, offset)
end

---@param point chartedit.Point
---@return chartedit.Vertex
function IntervalManager:split(point)
	local layer = self.editorModel.layer
	local p = layer.points:getPoint(point:unpack())
	layer.visuals.main:getPoint(p)
	layer.vertices:splitVertex(p)
	self.editorModel.editorChanges:reset()
	self.editorModel.editorChanges:add(
		self.editorModel.editorChanges:command(self, "splitRaw", p),
		self.editorModel.editorChanges:command(self, "mergeRaw", p)
	)
	self.editorModel.editorChanges:next()
	return p._vertex
end

---@param point chartedit.Point
function IntervalManager:merge(point)
	if not point._vertex then
		return
	end
	self.editorModel.editorChanges:reset()
	self.editorModel.layer.vertices:mergeVertex(point)
	self.editorModel.editorChanges:add(
		self.editorModel.editorChanges:command(self, "mergeRaw", point),
		self.editorModel.editorChanges:command(self, "splitRaw", point)
	)
	self.editorModel.editorChanges:next()
end

---@param vertex chartedit.Vertex
---@param beats number
function IntervalManager:update(vertex, beats)
	local oldBeats = vertex.beats
	local removed_points = IntervalUpdateSnapshot.captureRemovedPoints(self.editorModel, vertex, beats)
	IntervalUpdateSnapshot.removeNotes(self.editorModel.notes, removed_points)
	self.editorModel.layer.vertices:updateVertex(vertex, beats)
	if vertex.beats == oldBeats then
		return
	end
	self.editorModel.editorChanges:reset()
	self.editorModel.editorChanges:add(
		self.editorModel.editorChanges:command(self, "updateRaw", vertex, vertex.beats, removed_points),
		self.editorModel.editorChanges:command(self, "updateRaw", vertex, oldBeats, removed_points, true)
	)
	self.editorModel.editorChanges:next()
end

---@param point chartedit.Point
function IntervalManager:splitRaw(point)
	self.editorModel.layer.vertices:splitVertex(point)
end

---@param point chartedit.Point
function IntervalManager:mergeRaw(point)
	self.editorModel.layer.vertices:mergeVertex(point)
end

---@param vertex chartedit.Vertex
---@param beats number
---@param removed_points rizu.editor.IntervalUpdateSnapshot.RemovedPoint[]?
---@param restore_removed_points boolean?
function IntervalManager:updateRaw(vertex, beats, removed_points, restore_removed_points)
	if not restore_removed_points then
		IntervalUpdateSnapshot.removeNotes(self.editorModel.notes, removed_points)
	end
	self.editorModel.layer.vertices:updateVertex(vertex, beats)
	if not restore_removed_points then
		return
	end

	IntervalUpdateSnapshot.restore(self.editorModel, removed_points)
end

return IntervalManager
