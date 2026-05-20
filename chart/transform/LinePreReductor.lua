local class = require("class")

---@class chart.LinePreReductor
---@operator call: chart.LinePreReductor
local LinePreReductor = class()

---@param tc number
---@param tm number
---@param bc number
---@param bm number
---@return number
local function intersectSegment(tc, tm, bc, bm)
	return (
		math.max((tc - 1) / tm, math.min(tc / tm, bc / bm)) -
		math.min(tc / tm, math.max((tc - 1) / tm, (bc - 1) / bm))
	) * tm
end

function LinePreReductor:createIntersectTable()
	local intersectTable = {}
	for i = 1, self.targetMode do
		intersectTable[i] = {}
		for j = 1, self.columnCount do
			intersectTable[i][j] = intersectSegment(i, self.targetMode, j, self.columnCount)
		end
	end
	self.intersectTable = intersectTable
end

---@param line table
function LinePreReductor:processLine(line)
	local intersectTable = self.intersectTable
	local targetMode = self.targetMode

	local overlap = {}
	local baseNotes = {}
	local combination = {}
	local appliedSuggested = {}

	line.overlap = overlap
	line.baseNotes = baseNotes
	line.combination = combination
	line.appliedSuggested = appliedSuggested

	local shortNoteCount = 0
	local longNoteCount = 0

	if line.baseLine then
		for _, note in ipairs(line.baseLine) do
			baseNotes[#baseNotes + 1] = note
			combination[#combination + 1] = note.columnIndex

			if note.startTime == note.baseEndTime then
				shortNoteCount = shortNoteCount + 1
			end
			if note.startTime ~= note.baseEndTime then
				longNoteCount = longNoteCount + 1
			end
		end
		line.noteCount = #baseNotes
		line.time = baseNotes[1].startTime
	else
		line.noteCount = 0
		line.time = 0
		line.reducedNoteCount = 0
	end

	line.shortNoteCount = shortNoteCount
	line.longNoteCount = longNoteCount
	table.sort(combination)

	for i = 1, targetMode do
		overlap[i] = 0
		local intersectSubTable = intersectTable[i]
		for _, column in ipairs(line.combination) do
			local rate = intersectSubTable[column]
			overlap[i] = overlap[i] + rate
		end
	end

	local countOverlap = 0
	for i = 1, targetMode do
		if overlap[i] > 0 then
			countOverlap = countOverlap + 1
		end
	end

	local maxReducedNoteCount = math.min(countOverlap, #line.combination)
	line.maxReducedNoteCount = maxReducedNoteCount
end

---@param notes table
---@param columnCount number
---@param targetMode number
---@return table
function LinePreReductor:getLines(notes, columnCount, targetMode)
	self.notes = notes
	self.columnCount = columnCount
	self.targetMode = targetMode

	self:createIntersectTable()

	local lines = {}
	self.lines = lines

	for _, line in ipairs(self.notes[1].line.lines) do
		local newLine = {}
		newLine.baseLine = line
		self:processLine(newLine)
		lines[#lines + 1] = newLine
	end

	lines[0] = {}
	self:processLine(lines[0])

	return lines

	--[[output:
		lines = {
			{
				baseLine
				shortNoteCount
				longNoteCount

				time

				combination
				overlap
				noteCount
				maxReducedNoteCount
			}
		}
	]]
end

return LinePreReductor
