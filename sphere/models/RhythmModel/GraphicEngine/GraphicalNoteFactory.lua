local class = require("class")
local FileFinder = require("sphere.persistence.FileFinder")
local ShortGraphicalNote = require("sphere.models.RhythmModel.GraphicEngine.ShortGraphicalNote")
local LongGraphicalNote = require("sphere.models.RhythmModel.GraphicEngine.LongGraphicalNote")
local ImageNote = require("sphere.models.RhythmModel.GraphicEngine.ImageNote")

---@class sphere.GraphicalNoteFactory
---@operator call: sphere.GraphicalNoteFactory
local GraphicalNoteFactory = class()

---@alias sphere.GraphicalNoteType
---| "ShortNote"
---| "LongNote"
---| "SoundNote"
---| "ImageNote"
---| "VideoNote"

---@param note chart.LinkedNote
---@return sphere.GraphicalNoteType
local function getImageNoteType(note)
	local image = note.startNote.data.images[1]
	if image and FileFinder:getType(image[1]) == "video" then
		return "VideoNote"
	end
	return "ImageNote"
end

---@see chart.NotechartNote
---@see sphere.NoteViewFactory

---@type {[chart.NoteType]: {[1]: table, [2]: sphere.GraphicalNoteType}}
local notes = {
	tap = {ShortGraphicalNote, "ShortNote"},
	hold = {LongGraphicalNote, "LongNote"},
	laser = {LongGraphicalNote, "LongNote"},
	drumroll = {LongGraphicalNote, "LongNote"},
	mine = {ShortGraphicalNote, "SoundNote"},
	shade = {ShortGraphicalNote, "SoundNote"},
	fake = {ShortGraphicalNote, "SoundNote"},
	-- sample = {ShortGraphicalNote, "SoundNote"},
	sprite = {ImageNote, getImageNoteType},
}

---@param note chart.LinkedNote
---@return sphere.GraphicalNote?
function GraphicalNoteFactory:getNote(note)
	local classAndType = notes[note:getType()]
	if not classAndType then
		return
	end

	local noteType = classAndType[2]
	if type(noteType) == "function" then
		noteType = noteType(note)
	end

	return classAndType[1](noteType, note)
end

return GraphicalNoteFactory
