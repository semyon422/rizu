local class = require("class")
local ShortVisualNote = require("rizu.engine.visual.ShortVisualNote")
local LongVisualNote = require("rizu.engine.visual.LongVisualNote")

---@class rizu.VisualNoteFactory
---@operator call: rizu.VisualNoteFactory
local VisualNoteFactory = class()

---@type {[chart.NoteType]: string}
local types = {
	tap = "short",
	hold = "long",
	laser = "long",
	drumroll = "long",
	mine = "SoundNote",
	shade = "SoundNote",
	fake = "SoundNote",
	sample = "SoundNote",
	sprite = "ImageNote",
}

---@param visual_info rizu.VisualInfo
function VisualNoteFactory:new(visual_info)
	self.visual_info = visual_info
end

---@param linked_note chart.LinkedNote
---@return rizu.VisualNote?
function VisualNoteFactory:getNote(linked_note)
	local Note = linked_note:isShort() and ShortVisualNote or LongVisualNote
	local visual_note = Note(linked_note, self.visual_info)

	visual_note.type = types[linked_note:getType()] or visual_note.type

	return visual_note
end

return VisualNoteFactory

