local class = require("class")
local NoteBlock = require("chart.transform.NoteBlock")

---@class chart.Upscaler
---@operator call: chart.Upscaler
local Upscaler = class()

function Upscaler:new()
	self.noteBlocks = {}
end

---@param columnCount number
function Upscaler:load(columnCount)
	self.columnCount = columnCount
	for i = 1, columnCount do
		self.noteBlocks[i] = NoteBlock()
		self.noteBlocks[i].columnIndex = i
		self.noteBlocks[i].startTime = 0
		self.noteBlocks[i].endTime = 0
	end
end

---@param noteBlocks table
---@return table
---@return table
function Upscaler:process(noteBlocks)
	local blocks = {}
	for i = 1, #noteBlocks do
		local noteBlock = noteBlocks[i]

		local bestColumnIndex = self:getBestColumnIndex(noteBlock)

		noteBlock.columnIndex = bestColumnIndex
		blocks[#blocks + 1] = noteBlock

		self.noteBlocks[bestColumnIndex]:addNote(noteBlock)
	end

	local columns = {}
	local notes = {}
	for columnIndex = 1, self.columnCount do
		for _, noteBlock in ipairs(self.noteBlocks[columnIndex]:getNotes()) do
			for _, note in ipairs(noteBlock:getNotes()) do
				notes[#notes + 1] = note
				columns[columnIndex] = (columns[columnIndex] or 0) + 1
			end
		end
	end
	for columnIndex = 1, self.columnCount do
		-- print(columnIndex, columns[columnIndex])
	end

	return notes, blocks
end

---@param noteBlock table
---@return number?
function Upscaler:getBestColumnIndex(noteBlock)
	local rates = {}
	for columnIndex = 1, self.columnCount do
		rates[columnIndex] = self.columns[noteBlock.baseColumnIndex][columnIndex]
	end

	for columnIndex = 1, self.columnCount do
		local lastNoteBlock = self.noteBlocks[columnIndex]:getLastNote()

		if lastNoteBlock then
			local deltaTime = noteBlock.startTime - lastNoteBlock.endTime
			if deltaTime <= 0 then
				rates[columnIndex] = 0

				local distance = noteBlock.distance[lastNoteBlock]
				for columnIndex2 = 1, self.columnCount do
					if not distance then break end
					if
						rates[columnIndex2] > 0 and
						math.abs(columnIndex2 - lastNoteBlock.columnIndex) >= math.abs(distance) and
						(columnIndex2 - lastNoteBlock.columnIndex) * distance > 0
					then
						rates[columnIndex2] = rates[columnIndex2]
					else
						rates[columnIndex2] = 0
					end
				end
			end
		end
	end

	local bestColumnIndex
	local maxRate = 0
	for columnIndex = 1, self.columnCount do
		local endTime = self.noteBlocks[columnIndex].endTime
		local deltaTime = noteBlock.startTime - endTime
		if deltaTime > 0 then
			rates[columnIndex] = rates[columnIndex] * deltaTime
		end

		if rates[columnIndex] > maxRate then
			maxRate = rates[columnIndex]
			bestColumnIndex = columnIndex
		end
	end

	return bestColumnIndex
end

return Upscaler
