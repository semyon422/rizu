local class = require("class")
local table_util = require("table_util")

---@class rizu.editor.EditorNote
---@operator call: rizu.editor.EditorNote
local EditorNote = class()

---@param noteType string
---@param note chart.LinkedNote
---@param visual_info rizu.VisualInfo
function EditorNote:new(noteType, note, visual_info)
	self.noteType = noteType
	self.linked_note = note
	self.visual_info = visual_info
	if note then
		self.startNote = note.startNote
		self.endNote = note.endNote
	end
end

---@param absoluteTime number
---@param column chart.Column
---@return rizu.editor.EditorNote?
function EditorNote:create(absoluteTime, column) end

---@param t number
---@param part string
---@param deltaColumn number
---@param lockSnap boolean
function EditorNote:grab(t, part, deltaColumn, lockSnap) end

---@param t number
function EditorNote:drop(t) end

---@param t number
function EditorNote:updateGrabbed(t) end

---@param point chartedit.Point
function EditorNote:copy(point) end

---@param point chartedit.Point
function EditorNote:paste(point) end

function EditorNote:remove() end

function EditorNote:add() end

function EditorNote:clone()
	local note = table_util.copy(self)
	setmetatable(note, getmetatable(self))
	return note
end

---@return chart.Note[]
function EditorNote:getNotes()
	return {}
end

---@param column chart.Column
function EditorNote:setColumn(column)
	self.column = column
	self.startNote.column = column
	if self.endNote then
		self.endNote.column = column
	end
end

return EditorNote
