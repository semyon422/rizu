local class = require("class")
local ShortEditorNote = require("rizu.editor.notes.ShortEditorNote")
local LongEditorNote = require("rizu.editor.notes.LongEditorNote")

---@class rizu.editor.EditorNoteFactory
---@operator call: rizu.editor.EditorNoteFactory
local EditorNoteFactory = class()

local notes = {
	tap = {ShortEditorNote, "ShortNote"},
	hold = {LongEditorNote, "LongNote"},
	laser = {LongEditorNote, "LongNote"},
	drumroll = {LongEditorNote, "LongNote"},
	mine = {ShortEditorNote, "SoundNote"},
	shade = {ShortEditorNote, "SoundNote"},
	fake = {ShortEditorNote, "SoundNote"},
	sample = {ShortEditorNote, "SoundNote"},
	-- sprite = {ShortEditorNote, "SoundNote"},
}

---@param note chart.LinkedNote
---@param visual_info rizu.VisualInfo
---@return rizu.editor.EditorNote?
function EditorNoteFactory:newNote(note, visual_info)
	local classAndType = notes[note:getType()]
	if not classAndType then
		return
	end
	return classAndType[1](classAndType[2], note, visual_info)
end

---@param note_type chart.NoteType
---@param visual_info rizu.VisualInfo
---@return rizu.editor.EditorNote?
function EditorNoteFactory:newNote_t(note_type, visual_info)
	local classAndType = notes[note_type]
	if not classAndType then
		return
	end
	return classAndType[1](classAndType[2], nil, visual_info)
end

return EditorNoteFactory
