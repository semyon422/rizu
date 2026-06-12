local class = require("class")
local Fraction = require("chart.core.Fraction")

---@class rizu.editor.ScrollerContext
---@field getDtpAbsolute fun(absoluteTime: number): chartedit.Point
---@field getSessionTime fun(): number
---@field getPoint fun(): chartedit.Point
---@field setSessionPoint fun(point: chartedit.Point)
---@field setTime fun(time: number)
---@field isIntervalGrabbed fun(): boolean
---@field interpolateFraction fun(vertex: chartedit.Vertex, time: chart.Fraction): chartedit.Point
---@field getSettings fun(): table

---@class rizu.editor.Scroller
---@operator call: rizu.editor.Scroller
---@field context rizu.editor.ScrollerContext
local Scroller = class()

---@param context rizu.editor.ScrollerContext
function Scroller:setContext(context)
	self.context = context
end

---@param point chartedit.Point
function Scroller:_scrollPoint(point)
	if not point then
		return
	end
	self.context:setSessionPoint(point)
end

---@param point chartedit.Point
function Scroller:scrollPoint(point)
	if not point then
		return
	end
	self:_scrollPoint(point)
	self.context:setTime(point.absoluteTime)
end

---@param point chartedit.Point
function Scroller:scrollTimePoint(point)
	self:scrollPoint(point)
end

---@param absoluteTime number
function Scroller:scrollSeconds(absoluteTime)
	local point = self.context:getDtpAbsolute(absoluteTime)
	self:scrollPoint(point)
end

---@param delta number
function Scroller:scrollSecondsDelta(delta)
	self:scrollSeconds(self.context:getSessionTime() + delta)
end

---@param delta number
function Scroller:scrollSnaps(delta)
	if self.context:isIntervalGrabbed() then
		return
	end
	self:scrollPoint(
		self.context:interpolateFraction(
			self:getNextSnapIntervalTime(self.context:getPoint(), delta)
		)
	)
end

---@param point chartedit.Point
---@param delta number
---@return chartedit.Vertex
---@return chart.Fraction
function Scroller:getNextSnapIntervalTime(point, delta)
	local editor = self.context:getSettings()

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
