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
---@param column ncdk2.Column
---@return rizu.editor.LongEditorNote?
function LongEditorNote:create(absoluteTime, column)
	local editorModel = self.editorModel
	local layer = editorModel.layer
	local visual = editorModel.visual

	local dtp = editorModel:getDtpAbsolute(absoluteTime)
	local p = layer.points:saveSearchPoint(dtp)
	local vp = visual:getPoint(p)
	local startNote = Note(vp, column, "hold", 1)
	self.startNote = startNote

	local p = layer.points:getPoint(editorModel.scroller:getNextSnapIntervalTime(p, 1))
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

	if lockSnap then
		return
	end

	self.startNote = self.startNote:clone()
	self.endNote = self.endNote:clone()
	self.linked_note.startNote = self.startNote
	self.linked_note.endNote = self.endNote
	self.startNote.endNote = self.endNote
	self.endNote.startNote = self.startNote

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
	local editorModel = self.editorModel
	local layer = editorModel.layer
	local visual = editorModel.visual
	if self.grabbedPart == "head" then
		local dtp = editorModel:getDtpAbsolute(t - self.grabbedDeltaTime)
		local p = layer.points:saveSearchPoint()
		if p == self.endNote.visualPoint.point then
			p = layer.points:getPoint(editorModel.scroller:getNextSnapIntervalTime(p, -1))
		end
		local vp = visual:getPoint(p)
		self.startNote.visualPoint = vp
	elseif self.grabbedPart == "tail" then
		local dtp = editorModel:getDtpAbsolute(t - self.grabbedDeltaTime)
		local p = layer.points:saveSearchPoint()
		if self.startNote.visualPoint.point == p then
			p = layer.points:getPoint(editorModel.scroller:getNextSnapIntervalTime(p, 1))
		end
		local vp = visual:getPoint(p)
		self.endNote.visualPoint = vp
	elseif self.grabbedPart == "body" then
		local dtp = editorModel:getDtpAbsolute(t - self.grabbedDeltaTime[1])
		local p = layer.points:saveSearchPoint()
		local vp = visual:getPoint(p)
		self.startNote.visualPoint = vp
		local dtp = editorModel:getDtpAbsolute(t - self.grabbedDeltaTime[2])
		local p = layer.points:saveSearchPoint()
		local vp = visual:getPoint(p)
		self.endNote.visualPoint = vp
	end
end

---@param t number
function LongEditorNote:updateGrabbed(t)
	local editorModel = self.editorModel
	if self.grabbedPart == "head" then
		editorModel:getDtpAbsolute(t - self.grabbedDeltaTime):clone(self.startNote.visualPoint.point)
	elseif self.grabbedPart == "tail" then
		editorModel:getDtpAbsolute(t - self.grabbedDeltaTime):clone(self.endNote.visualPoint.point)
	elseif self.grabbedPart == "body" then
		editorModel:getDtpAbsolute(t - self.grabbedDeltaTime[1]):clone(self.startNote.visualPoint.point)
		editorModel:getDtpAbsolute(t - self.grabbedDeltaTime[2]):clone(self.endNote.visualPoint.point)
	end
end

---@param copyPoint chartedit.Point
function LongEditorNote:copy(copyPoint)
	self.deltaStartTime = self.startNote.visualPoint.point:sub(copyPoint)
	self.deltaEndTime = self.endNote.visualPoint.point:sub(copyPoint)
end

---@param point chartedit.Point
---@return ncdk2.Note[]
function LongEditorNote:paste(point)
	local layer = self.editorModel.layer
	local visual = self.editorModel.visual

	local startNote = self.startNote:clone()
	local endNote = self.endNote:clone()

	startNote.visualPoint = visual:getPoint(layer.points:getPoint(point:add(self.deltaStartTime)))
	endNote.visualPoint = visual:getPoint(layer.points:getPoint(point:add(self.deltaEndTime)))

	return {startNote, endNote}
end

---@return ncdk2.Note[]
function LongEditorNote:getNotes()
	return {self.startNote, self.endNote}
end

return LongEditorNote
