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
---@return chartedit.Interval
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

	local interval = point.interval
	-- if intervalData.next and targetSnapTime >= snap * intervalData:_end() then
	-- 	intervalData = intervalData.next
	-- 	targetSnapTime = intervalData:start() * snap
	-- elseif intervalData.prev and dtp.time > intervalData:start() and targetSnapTime < snap * intervalData:start() then
	-- 	targetSnapTime = intervalData:start() * snap
	-- elseif intervalData.prev and dtp.time == intervalData:start() and targetSnapTime < snap * intervalData:start() then
	-- 	intervalData = intervalData.prev
	-- 	targetSnapTime = (intervalData:_end() * snap):ceil() - 1
	-- end

	if interval.next and targetSnapTime == snap * interval:_end() then
		interval = interval.next
		targetSnapTime = interval:start() * snap
	elseif interval.next and targetSnapTime > snap * interval:_end() then
		interval = interval.next
		targetSnapTime = (interval:start() * snap):floor() + 1
	elseif interval.prev and targetSnapTime < snap * interval:start() then
		interval = interval.prev
		targetSnapTime = (interval:_end() * snap):ceil() - 1
	end

	return interval, Fraction(targetSnapTime, snap)
end

return Scroller
