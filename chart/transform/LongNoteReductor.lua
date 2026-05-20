local class = require("class")

---@class chart.LongNoteReductor
---@operator call: chart.LongNoteReductor
local LongNoteReductor = class()

---@param i number
---@param note table
---@return table?
---@return table?
function LongNoteReductor:getNextLines(i, note)
	local lines = self.lines
	for j = i + 1, #lines - 2 do
		local nextLine = lines[j]
		for _, column in ipairs(nextLine.bestLineCombination) do
			if note.columnIndex == column then
				return nextLine, lines[j - 1]
			end
		end
	end
	return lines[i + 1], lines[i]
end

function LongNoteReductor:reduceLongNotes()
	local lines = self.lines
	local allLines = self.allLines
	local allLinesMap = self.allLinesMap
	for i = 1, #lines - 1 do
		local line = lines[i]
		for _, note in ipairs(line.reducedNotes) do
			if note.baseEndTime ~= note.startTime then
				local nextLine, preNextLine = self:getNextLines(i, note)

				local window = nextLine.time - line.time - 10

				local gap
				if note.baseEndTime >= line.time + window then
					gap = nextLine.time - preNextLine.time
				end

				local baseGap
				local nearLineTime = allLines[allLinesMap[note.baseEndTime] + 1]
				if nearLineTime then
					baseGap = nearLineTime - note.baseEndTime
				end

				local reverseGap
				local nextAppliedSuggestedNote = nextLine.appliedSuggested[note.columnIndex]
				if nextAppliedSuggestedNote and nextAppliedSuggestedNote.bottom then
					reverseGap = nextAppliedSuggestedNote.startTime - nextAppliedSuggestedNote.bottom.baseEndTime
				end

				local minBaseGap
				if baseGap and reverseGap then
					minBaseGap = math.min(baseGap, reverseGap)
				elseif baseGap then
					minBaseGap = baseGap
				elseif reverseGap then
					minBaseGap = reverseGap
				end

				if minBaseGap and minBaseGap < window then
					note.endTime = math.min(nextLine.time - minBaseGap, note.baseEndTime)
				elseif gap then
					note.endTime = math.min(nextLine.time - gap, note.baseEndTime)
				else
					note.endTime = math.min(note.startTime, note.baseEndTime)
				end
			end
		end
	end
end

---@param notes table
---@param lines table
---@param columnCount number
---@param targetMode number
function LongNoteReductor:process(notes, lines, columnCount, targetMode)
	self.notes = notes
	self.lines = lines
	self.columnCount = columnCount
	self.targetMode = targetMode

	local allLinesMap = {}
	self.allLinesMap = allLinesMap

	for _, note in ipairs(self.notes) do
		allLinesMap[note.startTime] = true
		allLinesMap[note.baseEndTime] = true
	end

	local allLines = {}
	self.allLines = allLines

	for time in pairs(allLinesMap) do
		allLines[#allLines + 1] = time
	end

	table.sort(allLines)

	for i, time in ipairs(allLines) do
		allLinesMap[time] = i
	end

	-- print("reduceLongNotes")
	self:reduceLongNotes()
end

return LongNoteReductor
