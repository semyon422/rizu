local class = require("class")
local ShortNoteView = require("sphere.views.RhythmView.ShortNoteView")
local LongNoteView = require("sphere.views.RhythmView.LongNoteView")

---@class sphere.NoteViewFactory
---@operator call: sphere.NoteViewFactory
local NoteViewFactory = class()

---@alias sphere.NoteViewType
---| "ShortNote"
---| "LongNote"
---| "SoundNote"
---| "ShortNoteAnimation"
---| "LongNoteAnimation"
---| "ShortNoteLighting"
---| "LongNoteLighting"

---@see sphere.GraphicalNoteFactory

---@type {[string]: {[sphere.GraphicalNoteType]: {[1]: table, [2]: sphere.NoteViewType}}}
local notes = {
	default = {
		short = {ShortNoteView, "ShortNote"},
		SoundNote = {ShortNoteView, "SoundNote"},
		long = {LongNoteView, "LongNote"},
	},
	animation = {
		short = {ShortNoteView, "ShortNoteAnimation"},
		long = {ShortNoteView, "LongNoteAnimation"},
	},
	lighting = {
		short = {ShortNoteView, "ShortNoteLighting"},
		long = {ShortNoteView, "LongNoteLighting"},
	},
}

for _, c in pairs(notes) do
	for k, v in pairs(c) do
		c[k] = v[1](v[2])
	end
end

---@param visual_note rizu.VisualNote
---@param mode string
---@return sphere.NoteView?
function NoteViewFactory:getNoteView(visual_note, mode)
	return notes[mode][visual_note.type]
end

return NoteViewFactory
