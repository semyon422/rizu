local class = require("class")
local IntervalUpdateSnapshot = require("rizu.editor.IntervalUpdateSnapshot")

---@class rizu.editor.IntervalManagerContext
---@field getLayer fun(): chartedit.Layer
---@field getNotes fun(): chartedit.Notes
---@field editorChanges rizu.editor.EditorChanges

---@class rizu.editor.IntervalManager
---@operator call: rizu.editor.IntervalManager
---@field context rizu.editor.IntervalManagerContext
local IntervalManager = class()

---@param context rizu.editor.IntervalManagerContext
function IntervalManager:setContext(context)
	self.context = context
end

---@param vertex chartedit.Vertex
function IntervalManager:grab(vertex)
	self.grabbedVertex = vertex
	self.grabbedVertexOffset = vertex.offset
end

function IntervalManager:drop()
	local vertex = self.grabbedVertex
	local offset = self.grabbedVertexOffset
	if vertex and offset and vertex.offset ~= offset then
		local editorChanges = self.context.editorChanges
		editorChanges:reset()
		editorChanges:add(
			editorChanges:command(self, "setOffset", vertex, vertex.offset),
			editorChanges:command(self, "setOffset", vertex, offset)
		)
		editorChanges:next()
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
	self.context.getLayer().vertices:moveVertex(self.grabbedVertex, time)
end

---@param vertex chartedit.Vertex
---@param offset number
function IntervalManager:setOffset(vertex, offset)
	self.context.getLayer().vertices:moveVertex(vertex, offset)
end

---@param point chartedit.Point
---@return chartedit.Vertex
function IntervalManager:split(point)
	local layer = self.context.getLayer()
	local p = layer.points:getPoint(point:unpack())
	layer.visuals.main:getPoint(p)
	layer.vertices:splitVertex(p)
	local editorChanges = self.context.editorChanges
	editorChanges:reset()
	editorChanges:add(
		editorChanges:command(self, "splitRaw", p),
		editorChanges:command(self, "mergeRaw", p)
	)
	editorChanges:next()
	return p._vertex
end

---@param point chartedit.Point
function IntervalManager:merge(point)
	if not point._vertex then
		return
	end
	local editorChanges = self.context.editorChanges
	editorChanges:reset()
	self.context.getLayer().vertices:mergeVertex(point)
	editorChanges:add(
		editorChanges:command(self, "mergeRaw", point),
		editorChanges:command(self, "splitRaw", point)
	)
	editorChanges:next()
end

---@param vertex chartedit.Vertex
---@param beats number
function IntervalManager:update(vertex, beats)
	local oldBeats = vertex.beats
	local removed_points = IntervalUpdateSnapshot.captureRemovedPoints(self.context, vertex, beats)
	IntervalUpdateSnapshot.removeNotes(self.context.getNotes(), removed_points)
	self.context.getLayer().vertices:updateVertex(vertex, beats)
	if vertex.beats == oldBeats then
		return
	end
	local editorChanges = self.context.editorChanges
	editorChanges:reset()
	editorChanges:add(
		editorChanges:command(self, "updateRaw", vertex, vertex.beats, removed_points),
		editorChanges:command(self, "updateRaw", vertex, oldBeats, removed_points, true)
	)
	editorChanges:next()
end

---@param point chartedit.Point
function IntervalManager:splitRaw(point)
	self.context.getLayer().vertices:splitVertex(point)
end

---@param point chartedit.Point
function IntervalManager:mergeRaw(point)
	self.context.getLayer().vertices:mergeVertex(point)
end

---@param vertex chartedit.Vertex
---@param beats number
---@param removed_points rizu.editor.IntervalUpdateSnapshot.RemovedPoint[]?
---@param restore_removed_points boolean?
function IntervalManager:updateRaw(vertex, beats, removed_points, restore_removed_points)
	if not restore_removed_points then
		IntervalUpdateSnapshot.removeNotes(self.context.getNotes(), removed_points)
	end
	self.context.getLayer().vertices:updateVertex(vertex, beats)
	if not restore_removed_points then
		return
	end

	IntervalUpdateSnapshot.restore(self.context, removed_points)
end

return IntervalManager
