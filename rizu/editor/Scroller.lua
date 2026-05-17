local class = require("class")
local Fraction = require("ncdk.Fraction")

---@class rizu.editor.Scroller
---@operator call: rizu.editor.Scroller
local Scroller = class()

---@param point ncdk2.Point
function Scroller:_scrollPoint(point)
	if not point then
		return
	end
	point:clone(self.editorModel.point)
end

---@param point ncdk2.Point
function Scroller:scrollPoint(point)
	if not point then
		return
	end
	self:_scrollPoint(point)
	self.editorModel:setTime(point.absoluteTime)
end

---@param absoluteTime number
function Scroller:scrollSeconds(absoluteTime)
	local point = self.editorModel:getDtpAbsolute(absoluteTime)
	self:scrollPoint(point)
end

---@param delta number
function Scroller:scrollSecondsDelta(delta)
	self:scrollSeconds(self.editorModel.point.absoluteTime + delta)
end

---@param delta number
function Scroller:scrollSnaps(delta)
	if self.editorModel.intervalManager:isGrabbed() then
		return
	end
	self:scrollPoint(
		self.editorModel.layer.points:interpolateFraction(
			self:getNextSnapIntervalTime(self.editorModel.point, delta)
		)
	)
end

---@param point chartedit.Point
---@param delta number
---@return chartedit.Vertex
---@return ncdk.Fraction
function Scroller:getNextSnapIntervalTime(point, delta)
	local editor = self.editorModel:getSettings()

	local snap = editor.snap
	local snapTime = point.time * snap

	local targetSnapTime
	if delta == -1 then
		targetSnapTime = snapTime:ceil() - 1
	else
		targetSnapTime = snapTime:floor() + 1
	end

	local vertex = point.vertex
	-- if vertexData.next and targetSnapTime >= snap * vertexData:_end() then
	-- 	vertexData = vertexData.next
	-- 	targetSnapTime = vertexData:start() * snap
	-- elseif vertexData.prev and dtp.time > vertexData:start() and targetSnapTime < snap * vertexData:start() then
	-- 	targetSnapTime = vertexData:start() * snap
	-- elseif vertexData.prev and dtp.time == vertexData:start() and targetSnapTime < snap * vertexData:start() then
	-- 	vertexData = vertexData.prev
	-- 	targetSnapTime = (vertexData:_end() * snap):ceil() - 1
	-- end

	if vertex.next and targetSnapTime == snap * vertex:_end() then
		vertex = vertex.next
		targetSnapTime = vertex:start() * snap
	elseif vertex.next and targetSnapTime > snap * vertex:_end() then
		vertex = vertex.next
		targetSnapTime = (vertex:start() * snap):floor() + 1
	elseif vertex.prev and targetSnapTime < snap * vertex:start() then
		vertex = vertex.prev
		targetSnapTime = (vertex:_end() * snap):ceil() - 1
	end

	return vertex, Fraction(targetSnapTime, snap)
end

return Scroller
