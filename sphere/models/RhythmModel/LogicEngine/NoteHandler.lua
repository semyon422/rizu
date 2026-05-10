local class = require("class")
local LogicalNoteFactory = require("sphere.models.RhythmModel.LogicEngine.LogicalNoteFactory")

---@class sphere.NoteHandler
---@operator call: sphere.NoteHandler
local NoteHandler = class()

---@param logicEngine sphere.LogicEngine
---@param notes ncdk2.LinkedNote[]
function NoteHandler:new(logicEngine, notes)
	self.logicEngine = logicEngine
	self.lnotes = notes
	---@type sphere.LogicalNote[]
	self.notes = {}
end

function NoteHandler:load()
	---@type sphere.LogicalNote[]
	self.notes = {}
	local notes = self.notes

	local logicEngine = self.logicEngine

	for _, lnote in ipairs(self.lnotes) do
		local note = LogicalNoteFactory:getNote(lnote)
		if note then
			note.logicEngine = logicEngine
			note.column = lnote:getColumn()
			table.insert(notes, note)
			logicEngine.sharedLogicalNotes[lnote.startNote] = note
		end
	end

	-- table.sort(notes)

	local isPlayable = false
	for i, note in ipairs(notes) do
		note.index = i
		note.nextNote = notes[i + 1]
		isPlayable = isPlayable or note.isPlayable
	end
	self.isPlayable = isPlayable

	self.startNoteIndex = 1
	self.endNoteIndex = 0
end

function NoteHandler:updateRange()
	local notes = self.notes

	for i = self.startNoteIndex, #notes do
		local note = notes[i]
		if not note.ended then
			self.startNoteIndex = i
			break
		end
		if i == #notes and note.ended then
			self.startNoteIndex = #notes + 1
		end
	end

	if not self.isPlayable then -- bga columns
		self.endNoteIndex = math.min(self.startNoteIndex, #notes)
		return
	end

	local eventTime = self.logicEngine:getEventTime()


	for i = self.endNoteIndex, #notes do
		local note = notes[i]
		if
			i == #notes or
			note and not note.ended and note.isPlayable and note:getNoteTime() >= eventTime
		then
			self.endNoteIndex = i
			break
		end
	end
end

---return current isPlayable note
---@return sphere.LogicalNote?
function NoteHandler:getCurrentNote()
	local notes = self.notes
	self:updateRange()

	for i = self.startNoteIndex, self.endNoteIndex do
		local note = notes[i]
		if not note.ended and note.state ~= "clear" then
			return note
		end
	end

	local nearest = self.logicEngine.nearest
	if not nearest then
		for i = self.startNoteIndex, self.endNoteIndex do
			local note = notes[i]
			if not note.ended and note.isPlayable then
				return note
			end
		end
	end

	local nearestIndex
	local nearestTime = math.huge
	for i = self.startNoteIndex, self.endNoteIndex do
		local note = notes[i]
		local time = math.abs(note:getDeltaTime())
		if not note.ended and note.isPlayable and time < nearestTime then
			nearestTime = time
			nearestIndex = i
		end
	end

	return notes[nearestIndex]
end

function NoteHandler:update()
	self:updateRange()
	for i = self.startNoteIndex, self.endNoteIndex do
		self.notes[i]:update()
	end
end

---@param note sphere.LogicalNote
function NoteHandler:handlePromode(note)
	local isReachable = note:isReachable(self.logicEngine:getEventTime())
	if not note.ended and note.isPlayable and isReachable then
		note.isPlayable = false
	end
	note:update()
end

---@param state boolean
---@param input string
function NoteHandler:setKeyState(state, input)
	self:update()

	local note = self:getCurrentNote()
	if not note then return end

	if self.logicEngine.promode then
		self:handlePromode(note)
		return
	end

	note.keyState = state
	note.inputMatched = note.column == input

	local _note = state and note.startNote or note.endNote
	if _note then
		self.logicEngine:playSound(_note)
	end

	note:update()
end

return NoteHandler
