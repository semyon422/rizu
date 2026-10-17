local class = require("class")
local NotePartView = require("sphere.views.RhythmView.NotePartView")

---@class sphere.NoteView
---@operator call: sphere.NoteView
---@field noteSkin sphere.NoteSkin
---@field graphicalNote rizu.VisualNote
---@field column number
---@field chords table
---@field start_time_state {dt: number}
---@field end_time_state {dt: number}
local NoteView = class()

---@param noteType string
function NoteView:new(noteType)
	self.noteType = noteType
	self.startChord = {}
	self.endChord = {}
	self.middleChord = {}
	self.start_time_state = {dt = 0}
	self.end_time_state = {dt = 0}
end

---@return {dt: number}
function NoteView:getStartTimeState()
	self.start_time_state.dt = self.graphicalNote.start_dt
	return self.start_time_state
end

---@return {dt: number}
function NoteView:getEndTimeState()
	self.end_time_state.dt = self.graphicalNote.end_dt
	return self.end_time_state
end

local noteParts = {}

---@param name string
---@return sphere.NotePartView
function NoteView:getNotePart(name)
	local part = noteParts[name]
	if not part then
		part = NotePartView({name = name})
		noteParts[name] = part
	end
	part.noteView = self
	return part
end

---@param quad love.Quad?
---@param ... number
---@return love.Quad|number?
---@return number?...
function NoteView:getDraw(quad, ...)
	if quad then
		return quad, ...
	end
	return ...
end

function NoteView:draw() end

---@return boolean
function NoteView:isVisible()
	return true
end

return NoteView
