local EditorNote = require("rizu.editor.EditorNote")
local LongVisualNote = require("rizu.engine.visual.LongVisualNote")
local VisualPoint = require("chart.chartedit.VisualPoint")
local Note = require("chart.model.notes.Note")
local LinkedNote = require("chart.model.notes.LinkedNote")

---@class rizu.editor.LongEditorNote: rizu.editor.EditorNote, rizu.LongVisualNote
---@operator call: rizu.editor.LongEditorNote
local LongEditorNote = EditorNote + LongVisualNote

function LongEditorNote:update()
	local visual_info = self.visual_info
	self.start_dt = visual_info:sub(self:getVisualTime(self.startNote.visualPoint))
	self.end_dt = visual_info:sub(self:getVisualTime(self.endNote.visualPoint))
end

---@param absoluteTime number
---@param column chart.Column
---@return rizu.editor.LongEditorNote?
function LongEditorNote:create(absoluteTime, column)
	local context = self.context
	local layer = context.getLayer()
	local visual = context.getVisual()

	local dtp = context.getDtpAbsolute(absoluteTime)
	local p = layer.points:saveSearchPoint(dtp)
	local vp = visual:getPoint(p)
	local startNote = Note(vp, column, "hold", 1)
	self.startNote = startNote

	local p = layer.points:getPoint(context.getNextSnapIntervalTime(p, 1))
	local vp = visual:getPoint(p)
	local endNote = Note(vp, column, "hold", -1)
	self.endNote = endNote

	self.linked_note = LinkedNote(startNote, endNote)

	startNote.endNote = endNote
	endNote.startNote = startNote

	self:update()

	return self
end

---@param t number
---@param part string
---@param deltaColumn number
---@param lockSnap boolean
function LongEditorNote:grab(t, part, deltaColumn, lockSnap)
	self.grabbedPart = part
	self.grabbedDeltaColumn = deltaColumn

	self:cloneLinkedNotes()

	if lockSnap then
		return
	end

	local startTime = self.startNote:getTime()
	local endTime = self.endNote:getTime()
	if part == "head" then
		self.grabbedDeltaTime = t - startTime
		self.startNote.visualPoint = VisualPoint({})
	elseif part == "tail" then
		self.grabbedDeltaTime = t - endTime
		self.endNote.visualPoint = VisualPoint({})
	elseif part == "body" then
		self.grabbedDeltaTime = {
			t - startTime,
			t - endTime,
		}
		self.startNote.visualPoint = VisualPoint({})
		self.endNote.visualPoint = VisualPoint({})
	end
	self:updateGrabbed(t)
end

---@param t number
function LongEditorNote:drop(t)
	local context = self.context
	local layer = context.getLayer()
	local visual = context.getVisual()
	if self.grabbedPart == "head" then
		local dtp = context.getDtpAbsolute(t - self.grabbedDeltaTime)
		local p = layer.points:saveSearchPoint()
		if p == self.endNote.visualPoint.point then
			p = layer.points:getPoint(context.getNextSnapIntervalTime(p, -1))
		end
		local vp = visual:getPoint(p)
		self.startNote.visualPoint = vp
	elseif self.grabbedPart == "tail" then
		local dtp = context.getDtpAbsolute(t - self.grabbedDeltaTime)
		local p = layer.points:saveSearchPoint()
		if self.startNote.visualPoint.point == p then
			p = layer.points:getPoint(context.getNextSnapIntervalTime(p, 1))
		end
		local vp = visual:getPoint(p)
		self.endNote.visualPoint = vp
	elseif self.grabbedPart == "body" then
		local dtp = context.getDtpAbsolute(t - self.grabbedDeltaTime[1])
		local p = layer.points:saveSearchPoint()
		local vp = visual:getPoint(p)
		self.startNote.visualPoint = vp
		local dtp = context.getDtpAbsolute(t - self.grabbedDeltaTime[2])
		local p = layer.points:saveSearchPoint()
		local vp = visual:getPoint(p)
		self.endNote.visualPoint = vp
	end
end

---@param t number
function LongEditorNote:updateGrabbed(t)
	local context = self.context
	if self.grabbedPart == "head" then
		context.getDtpAbsolute(t - self.grabbedDeltaTime):clone(self.startNote.visualPoint.point)
	elseif self.grabbedPart == "tail" then
		context.getDtpAbsolute(t - self.grabbedDeltaTime):clone(self.endNote.visualPoint.point)
	elseif self.grabbedPart == "body" then
		context.getDtpAbsolute(t - self.grabbedDeltaTime[1]):clone(self.startNote.visualPoint.point)
		context.getDtpAbsolute(t - self.grabbedDeltaTime[2]):clone(self.endNote.visualPoint.point)
	end
end

---@param copyPoint chartedit.Point
function LongEditorNote:copy(copyPoint)
	self.deltaStartTime = self.startNote.visualPoint.point:sub(copyPoint)
	self.deltaEndTime = self.endNote.visualPoint.point:sub(copyPoint)
end

---@param point chartedit.Point
---@return chart.Note[]
function LongEditorNote:paste(point)
	local context = self.context
	local layer = context.getLayer()
	local visual = context.getVisual()

	local startNote = self.startNote:clone()
	local endNote = self.endNote:clone()

	startNote.visualPoint = visual:getPoint(layer.points:getPoint(point:add(self.deltaStartTime)))
	endNote.visualPoint = visual:getPoint(layer.points:getPoint(point:add(self.deltaEndTime)))
	startNote.endNote = endNote
	endNote.startNote = startNote

	return {startNote, endNote}
end

---@return chart.Note[]
function LongEditorNote:getNotes()
	return {self.startNote, self.endNote}
end

return LongEditorNote
