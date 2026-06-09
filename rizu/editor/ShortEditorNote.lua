local EditorNote = require("rizu.editor.EditorNote")
local ShortVisualNote = require("rizu.engine.visual.ShortVisualNote")
local VisualPoint = require("chart.chartedit.VisualPoint")
local Note = require("chart.model.notes.Note")
local LinkedNote = require("chart.model.notes.LinkedNote")

---@class rizu.editor.ShortEditorNote: rizu.editor.EditorNote, rizu.ShortVisualNote
---@operator call: rizu.editor.ShortEditorNote
local ShortEditorNote = EditorNote + ShortVisualNote

---@param absoluteTime number
---@param column chart.Column
---@return rizu.editor.ShortEditorNote?
function ShortEditorNote:create(absoluteTime, column)
	local editorModel = self.editorModel
	local layer = editorModel.layer
	local visual = editorModel.visual

	local dtp = editorModel:getDtpAbsolute(absoluteTime)
	local p = layer.points:saveSearchPoint(dtp)
	local vp = visual:getPoint(p)
	local note = Note(vp, column, "tap")
	self.startNote = note
	self.linked_note = LinkedNote(note)
	self:update()

	return self
end

---@param t number
---@param part string
---@param deltaColumn number
---@param lockSnap boolean
function ShortEditorNote:grab(t, part, deltaColumn, lockSnap)
	self.grabbedPart = part
	self.grabbedDeltaColumn = deltaColumn

	self.startNote = self.startNote:clone()
	self.linked_note.startNote = self.startNote

	if lockSnap then
		return
	end

	self.grabbedDeltaTime = t - self.startNote:getTime()
	self.startNote.visualPoint = VisualPoint({})
	self:updateGrabbed(t)
end

---@param t number
function ShortEditorNote:drop(t)
	local editorModel = self.editorModel
	local layer = editorModel.layer
	local visual = editorModel.visual
	local dtp = editorModel:getDtpAbsolute(t - self.grabbedDeltaTime)
	local p = layer.points:saveSearchPoint()
	local vp = visual:getPoint(p)
	self.startNote.visualPoint = vp
end

---@param t number
function ShortEditorNote:updateGrabbed(t)
	self.editorModel:getDtpAbsolute(t - self.grabbedDeltaTime):clone(self.startNote.visualPoint.point)
end

---@param copyPoint chartedit.Point
function ShortEditorNote:copy(copyPoint)
	self.deltaStartTime = self.startNote.visualPoint.point:sub(copyPoint)
end

---@param point chartedit.Point
---@return chart.Note[]
function ShortEditorNote:paste(point)
	local layer = self.editorModel.layer
	local visual = self.editorModel.visual
	local new_point = layer.points:getPoint(point:add(self.deltaStartTime))
	local startNote = self.startNote:clone()
	startNote.visualPoint = visual:getPoint(new_point)
	return {startNote}
end

function ShortEditorNote:getNotes()
	return {self.startNote}
end

return ShortEditorNote
