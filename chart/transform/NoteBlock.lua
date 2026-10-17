local class = require("class")

---@class chart.NoteBlock
---@operator call: chart.NoteBlock
local NoteBlock = class()

function NoteBlock:new()
	self.columnIndex = 0
	self.size = 0
	self.notes = {}
end

---@param note table
---@return chart.NoteBlock
function NoteBlock:addNote(note)
	self.notes[#self.notes + 1] = note
	self.baseColumnIndex = self.baseColumnIndex or note.columnIndex
	self.columnIndex = self.baseColumnIndex
	self.startTime = math.min(self.startTime or note.startTime, note.startTime)
	self.endTime = math.max(self.endTime or note.endTime, note.endTime)
	self.size = self.size + 1

	return self
end

---@return table
function NoteBlock:getNotes()
	local notes = {}

	for _, note in ipairs(self.notes) do
		notes[#notes + 1] = note
		note.columnIndex = self.columnIndex
	end

	return notes
end

---@return table?
function NoteBlock:getLastNote()
	return self.notes[#self.notes]
end

---@return table
function NoteBlock:lock()
	self.locked = true

	self.notes[1].blockStart = true
	for _, note in ipairs(self.notes) do
		note.block = self
		note.locked = true
	end

	return self
end

---@return boolean?
local function isNextLineFree(lastNote)
	local nextLine = lastNote.line.next

	if not nextLine then return end

	for _, note in ipairs(nextLine) do
		if note.columnIndex == lastNote.columnIndex then
			return
		end
	end

	return true
end

function NoteBlock:extend()
	local lastNote = self.notes[#self.notes]
	local nextNote = lastNote.top

	local nextLine
	if not nextNote then
		nextLine = lastNote.line.last
	else
		nextLine = nextNote.line.prev
	end

	if nextLine.startTime <= self.endTime then
		return
	end

	self.endTime = nextLine.startTime
end

function NoteBlock:extendNextLine()
	local lastNote = self.notes[#self.notes]
	local nextNote = lastNote.top

	local nextLine
	if not nextNote then
		nextLine = lastNote.line.last
	else
		nextLine = lastNote.line.next
	end

	if nextLine.startTime <= self.endTime then
		return
	end

	self.endTime = nextLine.startTime
end

function NoteBlock:print()
	print("block")
	print("lanePos, linePos")
	for _, note in ipairs(self.notes) do
		print(note.lanePos, note.linePos)
	end
end

---@param note table
function NoteBlock:printNote(note)
	print("note")
	print("lanePos, linePos")
	print(note.lanePos, note.linePos)
end

return NoteBlock
