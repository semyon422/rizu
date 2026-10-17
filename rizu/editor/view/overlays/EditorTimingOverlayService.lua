local class = require("class")

---@class rizu.editor.EditorTimingOverlayState
---@field point chartedit.Point
---@field pointLabel string
---@field pointStatusLabel string
---@field showTimings boolean
---@field canScrollPrev boolean
---@field canScrollNext boolean
---@field isGrabbed boolean
---@field canSplit boolean
---@field canGrab boolean
---@field canDrop boolean
---@field canMerge boolean
---@field canEditBeats boolean
---@field vertexActionLabel string
---@field vertex chartedit.Vertex?
---@field tempoLabel string?
---@field beats number?
---@field beatsLabel string?

---@class rizu.editor.EditorTimingNavigationInput
---@field prevPressed boolean
---@field nextPressed boolean

---@class rizu.editor.EditorTimingVertexInput
---@field splitPressed boolean
---@field grabPressed boolean
---@field dropPressed boolean
---@field mergePressed boolean
---@field beats number?

---@class rizu.editor.EditorTimingCommentState
---@field visualPoint chartedit.VisualPoint
---@field value string

---@class rizu.editor.EditorTimingOverlayContext
---@field getPoint fun(self: rizu.editor.EditorTimingOverlayContext): chartedit.Point
---@field getEditorSettings fun(self: rizu.editor.EditorTimingOverlayContext): rizu.editor.EditorSettings
---@field getIntervalManager fun(self: rizu.editor.EditorTimingOverlayContext): rizu.editor.IntervalManager
---@field getVisualPointFor fun(self: rizu.editor.EditorTimingOverlayContext, point: chartedit.Point): chartedit.VisualPoint
---@field scrollTimePoint fun(self: rizu.editor.EditorTimingOverlayContext, point: chartedit.Point)
---@field scrollSecondsDelta fun(self: rizu.editor.EditorTimingOverlayContext, delta: number)

---@class rizu.editor.EditorTimingOverlayService
---@operator call: rizu.editor.EditorTimingOverlayService
local EditorTimingOverlayService = class()

---@param context rizu.editor.EditorTimingOverlayContext
---@return rizu.editor.EditorTimingOverlayState
function EditorTimingOverlayService:getState(context)
	local point = context:getPoint()
	local vertex = point._vertex
	local isGrabbed = self:isGrabbed(context)
	local hasVertex = vertex ~= nil
	---@type string?
	local tempoLabel
	if point.vertex then
		tempoLabel = "Tempo: " .. point.vertex:getTempo() .. " bpm"
	end
	local pointStatusLabel = "Timing point"
	local vertexActionLabel = "split"
	if isGrabbed then
		pointStatusLabel = "Grabbed timing vertex"
		vertexActionLabel = "drop"
	elseif hasVertex then
		pointStatusLabel = "Timing vertex"
		vertexActionLabel = "grab"
	end

	return {
		point = point,
		pointLabel = tostring(point),
		pointStatusLabel = pointStatusLabel,
		showTimings = self:isShowTimings(context),
		canScrollPrev = point.prev ~= nil,
		canScrollNext = point.next ~= nil,
		isGrabbed = isGrabbed,
		canSplit = not isGrabbed and not hasVertex,
		canGrab = not isGrabbed and hasVertex,
		canDrop = isGrabbed,
		canMerge = not isGrabbed and hasVertex,
		canEditBeats = not isGrabbed and hasVertex,
		vertexActionLabel = vertexActionLabel,
		vertex = vertex,
		tempoLabel = tempoLabel,
		beats = vertex and vertex.beats or nil,
		beatsLabel = vertex and "beats " .. vertex.beats or nil,
	}
end

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
---@param input rizu.editor.EditorTimingNavigationInput
function EditorTimingOverlayService:handleNavigationInput(context, input)
	if input.prevPressed then
		self:scrollPrev(context)
	end
	if input.nextPressed then
		self:scrollNext(context)
	end
end

---@param context rizu.editor.EditorTimingOverlayContext
---@param state rizu.editor.EditorTimingOverlayState
---@param input rizu.editor.EditorTimingVertexInput
function EditorTimingOverlayService:handleVertexInput(context, state, input)
	local vertex = state.vertex
	local isGrabbed = state.isGrabbed

	if not isGrabbed then
		if not vertex then
			if input.splitPressed then
				self:split(context, state.point)
			end
		elseif input.grabPressed then
			self:grab(context, vertex)
			isGrabbed = true
		end
	elseif input.dropPressed then
		self:drop(context)
		isGrabbed = false
	end

	if vertex and not isGrabbed then
		if input.mergePressed then
			self:merge(context, vertex.point)
		end
		if input.beats and input.beats ~= vertex.beats then
			self:update(context, vertex, input.beats)
		end
	end
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
---@param state rizu.editor.EditorTimingOverlayState
---@return rizu.editor.EditorTimingCommentState?
function EditorTimingOverlayService:getCommentState(context, state)
	local visualPoint = self:getCommentVisualPoint(context, state.point)
	if not visualPoint then
		return nil
	end
	return {
		visualPoint = visualPoint,
		value = visualPoint.temp_comment or visualPoint.comment or "",
	}
end

---@param commentState rizu.editor.EditorTimingCommentState
---@param value string
function EditorTimingOverlayService:setCommentDraft(commentState, value)
	commentState.visualPoint.temp_comment = value
	commentState.value = value
end

---@param context rizu.editor.EditorTimingOverlayContext
---@param point chartedit.Point
---@return chartedit.VisualPoint?
function EditorTimingOverlayService:getCommentVisualPoint(context, point)
	---@type chartedit.Point?
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
