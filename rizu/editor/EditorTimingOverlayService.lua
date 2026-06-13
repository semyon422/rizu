local class = require("class")

---@class rizu.editor.EditorTimingOverlayContext
---@field getPoint fun(self: rizu.editor.EditorTimingOverlayContext): chartedit.Point
---@field getEditorSettings fun(self: rizu.editor.EditorTimingOverlayContext): table
---@field getIntervalManager fun(self: rizu.editor.EditorTimingOverlayContext): rizu.editor.IntervalManager
---@field getVisualPointFor fun(self: rizu.editor.EditorTimingOverlayContext, point: chartedit.Point): chartedit.VisualPoint
---@field scrollTimePoint fun(self: rizu.editor.EditorTimingOverlayContext, point: chartedit.Point)
---@field scrollSecondsDelta fun(self: rizu.editor.EditorTimingOverlayContext, delta: number)

---@class rizu.editor.EditorTimingOverlayService
---@operator call: rizu.editor.EditorTimingOverlayService
local EditorTimingOverlayService = class()

---@param context rizu.editor.EditorTimingOverlayContext
---@return chartedit.Point
function EditorTimingOverlayService:getPoint(context)
	return context:getPoint()
end

---@param context rizu.editor.EditorTimingOverlayContext
---@return boolean
function EditorTimingOverlayService:isShowTimings(context)
	return context:getEditorSettings().showTimings
end

---@param context rizu.editor.EditorTimingOverlayContext
---@param showTimings boolean
function EditorTimingOverlayService:setShowTimings(context, showTimings)
	context:getEditorSettings().showTimings = showTimings
end

---@param context rizu.editor.EditorTimingOverlayContext
function EditorTimingOverlayService:scrollPrev(context)
	local point = context:getPoint()
	if point.prev then
		context:scrollTimePoint(point.prev)
	end
end

---@param context rizu.editor.EditorTimingOverlayContext
function EditorTimingOverlayService:scrollNext(context)
	local point = context:getPoint()
	if point.next then
		context:scrollTimePoint(point.next)
	end
end

---@param context rizu.editor.EditorTimingOverlayContext
---@return boolean
function EditorTimingOverlayService:isGrabbed(context)
	return context:getIntervalManager():isGrabbed()
end

---@param context rizu.editor.EditorTimingOverlayContext
---@param point chartedit.Point
function EditorTimingOverlayService:split(context, point)
	context:getIntervalManager():split(point)
end

---@param context rizu.editor.EditorTimingOverlayContext
---@param vertex chartedit.Vertex
function EditorTimingOverlayService:grab(context, vertex)
	context:getIntervalManager():grab(vertex)
end

---@param context rizu.editor.EditorTimingOverlayContext
function EditorTimingOverlayService:drop(context)
	context:getIntervalManager():drop()
end

---@param context rizu.editor.EditorTimingOverlayContext
---@param point chartedit.Point
function EditorTimingOverlayService:merge(context, point)
	context:getIntervalManager():merge(point)
	context:scrollSecondsDelta(0)
end

---@param context rizu.editor.EditorTimingOverlayContext
---@param vertex chartedit.Vertex
---@param beats number
function EditorTimingOverlayService:update(context, vertex, beats)
	context:getIntervalManager():update(vertex, beats)
end

---@param context rizu.editor.EditorTimingOverlayContext
---@param point chartedit.Point
---@return chartedit.VisualPoint?
function EditorTimingOverlayService:getCommentVisualPoint(context, point)
	local commentPoint
	if point.next then
		commentPoint = point.next.prev
	elseif point.prev then
		commentPoint = point.prev.prev
	end
	---@cast commentPoint chartedit.Point?

	if not commentPoint or commentPoint.absoluteTime ~= point.absoluteTime then
		return nil
	end

	return context:getVisualPointFor(commentPoint)
end

return EditorTimingOverlayService
