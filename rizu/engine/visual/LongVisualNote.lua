local math_util = require("math_util")
local VisualNote = require("rizu.engine.visual.VisualNote")
local Point = require("chart.model.tp.Point")
local VisualPoint = require("chart.model.visual.VisualPoint")

---@class rizu.LongVisualNote: rizu.VisualNote
---@operator call: rizu.LongVisualNote
local LongVisualNote = VisualNote + {}

LongVisualNote.type = "long"

---@param vp ncdk2.IVisualPoint
local function copy_point(vp)
	local _p = Point(vp.point.absoluteTime)
	local _vp = VisualPoint(_p)

	_vp.visualTime = vp.visualTime

	return _p, _vp
end

function LongVisualNote:initPoints()
	if self.head_p then
		return
	end

	local note = self.linked_note

	self.head_p, self.head_vp = copy_point(note.startNote.visualPoint)
	self.tail_p, self.tail_vp = copy_point(note.endNote.visualPoint)
end

function LongVisualNote:update()
	local visual_info = self.visual_info

	self:initPoints()

	local head_visual_time = self:getHeadVisualTime()
	self.start_dt = visual_info:sub(head_visual_time)

	head_visual_time = math.max(head_visual_time, self:getTailVisualTime())
	self.end_dt = visual_info:sub(head_visual_time)
end

---@param time number
function LongVisualNote:clampAbsoluteTime(time)
	local linked_note = self.linked_note
	local visual_info = self.visual_info

	local start_time = linked_note:getStartTime()
	local end_time = math.max(start_time, linked_note:getEndTime() + visual_info.shortening)

	return math_util.clamp(time, start_time, end_time)
end

---@param cur_time number
function LongVisualNote:getLatePressTime(cur_time)
	self.head_press_offset = self.head_press_offset or cur_time

	local dur = math.max(self.head_press_offset - self.linked_note:getStartTime(), 0)
	local press_time = cur_time - self.head_press_offset

	return cur_time + math.min(press_time - dur, 0)
end

---@param cur_time number
function LongVisualNote:getLatePressTimeClamped(cur_time)
	return self:clampAbsoluteTime(self:getLatePressTime(cur_time))
end

---@return number
function LongVisualNote:getHeadVisualTime()
	local cvp = self.cvp
	local head_vp = self.head_vp
	local head_p = self.head_p

	local state = self:getState()
	if state ~= "startPassedPressed" and state ~= "endPassed" then
		return self:getVisualTime(head_vp)
	end

	if self.visual_info.const then
		head_p.absoluteTime = self:getLatePressTimeClamped(cvp.point.absoluteTime)
		return head_p.absoluteTime
	end

	local interpolator = self.visual.interpolator
	local points = self.visual.points

	head_vp.monotonicVisualTime = cvp.monotonicVisualTime
	interpolator:interpolate(points, head_vp, "visual")

	head_p.absoluteTime = self:getLatePressTimeClamped(head_p.absoluteTime)
	interpolator:interpolate(points, head_vp, "absolute")

	return self:getVisualTime(head_vp)
end

---@return number
function LongVisualNote:getTailVisualTime()
	local tail_vp = self.tail_vp
	local tail_p = self.tail_p

	tail_p.absoluteTime = self:clampAbsoluteTime(self.linked_note:getEndTime())

	if self.visual_info.const then
		return tail_p.absoluteTime
	end

	self.visual.interpolator:interpolate(self.visual.points, tail_vp, "absolute")

	return self:getVisualTime(tail_vp)
end

LongVisualNote.__lt = VisualNote.__lt

return LongVisualNote
