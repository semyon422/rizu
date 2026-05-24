local Modifier = require("sphere.models.ModifierModel.Modifier")
local Note = require("chart.model.notes.Note")
local Notes = require("chart.model.notes.Notes")
local InputMode = require("chart.core.InputMode")

---@class sphere.MaxChord
---@operator call: sphere.MaxChord
local MaxChord = Modifier + {}

MaxChord.name = "MaxChord"

MaxChord.defaultValue = 1
MaxChord.values = {}

for i = 1, 10 do
	table.insert(MaxChord.values, i)
end

MaxChord.description = "All chords will be <= modifier value"

---@param config table
---@return string
---@return string
function MaxChord:getString(config)
	return "CH", tostring(config.value)
end

---@param note ncdk2.LinkedNote
---@return boolean
local function checkNote(note)
	local t = note:getType()
	return t == "tap" or t == "hold"
end

---@param notes ncdk2.LinkedNote[]
---@param i number
---@param dir number?  -- 1 = forward, -1 = backward
---@return number
local function getNextTime(notes, i, dir)
	dir = dir or 1
	for j = i + dir, #notes, dir do
		local note = notes[j]
		if checkNote(note) then
			return note:getStartTime()
		end
	end
	return math.huge * dir
end

---@param a table
---@param b table
---@return boolean
local function sortByColumn(a, b)
	return a.column < b.column
end

---@param line table[]
---@param columns number
---@return string
local function getCounterKey(line, columns)  -- use bit.bor
	---@type integer[]
	local t = {}
	for i = 1, columns do
		t[i] = 0
	end
	for _, note in ipairs(line) do
		t[note.column] = 1
	end
	return table.concat(t)
end

---@param t table[]
---@param v table
---@return table?
local function removeNote(t, v)
	for i, _v in ipairs(t) do
		if _v == v then
			table.remove(t, i)
			return v
		end
	end
end

---@param size integer
local function zeroes(size)
	---@type integer[]
	local t = {}
	for i = 1, size do
		t[i] = 0
	end
	return t
end

---@param config table
---@param chart ncdk2.Chart
function MaxChord:apply(config, chart)
	local maxChord = config.value
	local columns = chart.inputMode.key

	local notes = {}

	local column_notes = chart.notes:getColumnLinkedNotes()
	for column, _notes in pairs(column_notes) do
		local inputType, inputIndex = InputMode:splitInput(column)
		if inputType == "key" then
			for i, note in ipairs(_notes) do
				if checkNote(note) then
					table.insert(notes, {
						baseNote = note,
						time = note:getStartTime(),
						nextTime = getNextTime(_notes, i),
						prevTime = getNextTime(_notes, i, -1),
						inputIndex = inputIndex,  -- for auto
						column = inputIndex,
					})
				end
			end
		end
	end

	local linesMap = {}
	for _, note in ipairs(notes) do
		local time = note.time
		linesMap[time] = linesMap[time] or {time = time}
		table.insert(linesMap[time], note)
	end

	local lines = {}
	for _, line in pairs(linesMap) do
		table.insert(lines, line)
		table.sort(line, sortByColumn)
	end
	table.sort(lines, function(a, b)
		return a.time < b.time
	end)

	local counters = {}
	local deletedNotes = {}

	for i = 1, #lines do
		local line = lines[i]
		local nextLineTime = lines[i + 1] and lines[i + 1].time or math.huge

		while #line > maxChord do
			local minNextTime, maxNextTime
			for _, note in ipairs(line) do
				if (not minNextTime or note.nextTime < minNextTime) and note.nextTime ~= nextLineTime then
					minNextTime = note.nextTime
				end
			end

			local notesToDelete = line
			if minNextTime then
				notesToDelete = {}
				for _, note in ipairs(line) do
					if note.nextTime == minNextTime then
						table.insert(notesToDelete, note)
					end
				end
			end

			if #notesToDelete == 1 then
				removeNote(line, notesToDelete[1])
				table.insert(deletedNotes, notesToDelete[1])
			else
				local key = getCounterKey(notesToDelete, columns)
				counters[key] = counters[key] or zeroes(#notesToDelete)
				local counter = counters[key]

				local min_cIndex = 1
				for k = 1, #counter do
					if counter[k] == 0 then
						min_cIndex = k
					end
				end
				local note = notesToDelete[min_cIndex]
				counter[min_cIndex] = counter[min_cIndex] + 1
				removeNote(line, note)
				table.insert(deletedNotes, note)

				local s = 0
				for k = 1, #counter do
					s = s + counter[k]
				end
				if s == #counter then
					counters[key] = zeroes(#counter)
				end
			end
		end
	end

	for _, note in ipairs(deletedNotes) do
		---@type ncdk2.LinkedNote
		local _note = note.baseNote
		_note:setType("sample")
	end
end

return MaxChord
