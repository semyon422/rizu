local class = require("class")

---@class chart.NoteApplyer
---@operator call: chart.NoteApplyer
local NoteApplyer = class()

---@param line table
function NoteApplyer:applyNotesEqual(line)
	-- add swap here if need
	local notes = {}
	for i = 1, line.reducedNoteCount do
		line.baseNotes[i].reducedColumnIndex = line.bestLineCombination[i]
		line.appliedSuggested[line.baseNotes[i].reducedColumnIndex] = line.baseNotes[i]
		notes[#notes + 1] = line.baseNotes[i]
	end
	line.reducedNotes = notes
end

---@param line table
function NoteApplyer:applyNotesLessShort(line)
	-- TODO: choose notes with lower density
	local notes = {}
	for i = 1, line.reducedNoteCount do
		line.baseNotes[i].reducedColumnIndex = line.bestLineCombination[i]
		line.appliedSuggested[line.baseNotes[i].reducedColumnIndex] = line.baseNotes[i]
		notes[#notes + 1] = line.baseNotes[i]
	end
	line.reducedNotes = notes
end

---@param line table
function NoteApplyer:applyNotesLessLong(line)
	-- add swap here if need
	local notes = {}
	for _, note in ipairs(line.baseNotes) do
		notes[#notes + 1] = note
	end
	while #notes > line.reducedNoteCount do
		local longest = 1
		for i, note in ipairs(notes) do
			if note.baseEndTime > notes[longest].baseEndTime then
				longest = i
			end
		end
		table.remove(notes, longest)
	end

	for i = 1, line.reducedNoteCount do
		notes[i].reducedColumnIndex = line.bestLineCombination[i]
		line.appliedSuggested[notes[i].reducedColumnIndex] = notes[i]
	end
	line.reducedNotes = notes
end

---@param line table
function NoteApplyer:applyNotesLessCombined(line)
	-- add swap here if need
	local notes = {}
	for _, note in ipairs(line.baseNotes) do
		notes[#notes + 1] = note
	end
	while #notes > line.reducedNoteCount do
		local shortNote
		for i, note in ipairs(notes) do
			if note.startTime == note.baseEndTime then
				shortNote = i
				break
			end
		end
		if shortNote then
			table.remove(notes, shortNote)
		else
			local longest = 1
			for i, note in ipairs(notes) do
				if note.baseEndTime > notes[longest].baseEndTime then
					longest = i
				end
			end
			table.remove(notes, longest)
		end
	end

	for i = 1, line.reducedNoteCount do
		notes[i].reducedColumnIndex = line.bestLineCombination[i]
		line.appliedSuggested[notes[i].reducedColumnIndex] = notes[i]
	end
	line.reducedNotes = notes
end

---@param line table
function NoteApplyer:applyNotesLess(line)
	if line.shortNoteCount > 0 and line.longNoteCount == 0 then
		self:applyNotesLessShort(line)
	elseif line.shortNoteCount == 0 and line.longNoteCount > 0 then
		self:applyNotesLessLong(line)
	elseif line.shortNoteCount > 0 and line.longNoteCount > 0 then
		self:applyNotesLessCombined(line)
	end
end

function NoteApplyer:applyNotes()
	for _, line in ipairs(self.lines) do
		if line.reducedNoteCount == line.noteCount then
			self:applyNotesEqual(line)
		else
			self:applyNotesLess(line)
		end
	end
	-- ! save probortions (ln:sn)
end

---@param notes table
---@param lines table
---@param columnCount number
---@param targetMode number
function NoteApplyer:process(notes, lines, columnCount, targetMode)
	self.notes = notes
	self.lines = lines
	self.columnCount = columnCount
	self.targetMode = targetMode

	-- print("applyNotes")
	self:applyNotes()

	for _, note in ipairs(self.notes) do
		-- note.endTime = note.startTime
		if note.reducedColumnIndex then
			note.columnIndex = note.reducedColumnIndex
		end
		note.endTime = note.baseEndTime
	end
end

return NoteApplyer
