local EditorNote = require("rizu.editor.EditorNote")
local ShortVisualNote = require("rizu.engine.visual.ShortVisualNote")
local VisualPoint = require("chartedit.VisualPoint")
local Note = require("ncdk2.notes.Note")
local LinkedNote = require("ncdk2.notes.LinkedNote")

---@class rizu.editor.ShortEditorNote: rizu.editor.EditorNote, rizu.ShortVisualNote
---@operator call: rizu.editor.ShortEditorNote
local ShortEditorNote = EditorNote + ShortVisualNote

---@param absoluteTime number
---@param column ncdk2.Column
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

	if lockSnap then
		return
	end

	self.startNote = self.startNote:clone()
	self.linked_note.startNote = self.startNote

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
---@return ncdk2.Note[]
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
