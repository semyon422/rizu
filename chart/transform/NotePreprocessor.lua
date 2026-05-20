local NotePreprocessor = {}

---@param a table
---@param b table
---@return boolean
local function sortLine(a, b)
	return a.columnIndex < b.columnIndex
end

---@param a table
---@param b table
---@return boolean
local function sortLane(a, b)
	return a.startTime < b.startTime
end

---@param notes table
function NotePreprocessor:process(notes)
	local lines = {}
	local lanes = {}

	for i = 1, self.columnCount do
		lanes[i] = {}
	end

	local laneLineIndex = {}

	for i = 1, #notes do
		local note = notes[i]
		local line = lines[note.startTime] or {}
		lines[note.startTime] = line
		line.startTime = note.startTime
		local lane = lanes[note.columnIndex]

		line[note.columnIndex] = note
		lane[note.startTime] = note

		note.line = line
		note.lane = lane
	end

	local lineIndex = {}
	for _, line in pairs(lines) do
		lineIndex[#lineIndex + 1] = line
	end
	table.sort(lineIndex, function(a, b)
		return a.startTime < b.startTime
	end)
	local longNotes = {}
	for i = 1, #lineIndex do
		local line = lineIndex[i]

		for i = 1, self.columnCount do
			if longNotes[i] then
				if longNotes[i].endTime < line.startTime then
					longNotes[i] = nil
				elseif longNotes[i].endTime == line.startTime then
					line[i] = {
						type = "tail",
						note = longNotes[i],
						columnIndex = i,
						baseColumnIndex = i,
						startTime = line.startTime
					}
					lanes[i][line.startTime] = line[i]
					longNotes[i] = nil
				else
					line[i] = {
						type = "body",
						note = longNotes[i],
						columnIndex = i,
						baseColumnIndex = i,
						startTime = line.startTime
					}
					lanes[i][line.startTime] = line[i]
				end
			end
		end
		for i = 1, self.columnCount do
			local note = line[i]
			if not longNotes[i] and note and not note.type and note.columnIndex == i and note.endTime > note.startTime then
				longNotes[i] = note
			end
		end
	end

	local newLines = {}
	for _, line in pairs(lines) do
		local newLine = {}
		newLine.startTime = line.startTime
		for i = 1, self.columnCount do
			if line[i] then
				newLine[#newLine + 1] = line[i]
				line[i].line = newLine
			end
		end
		newLines[#newLines + 1] = newLine
	end
	lines = newLines
	table.sort(lines, function(a, b)
		return a.startTime < b.startTime
	end)

	local newLanes = {}
	for i = 1, self.columnCount do
		local lane = lanes[i]
		local newLaneDict = {}
		for _, note in pairs(lane) do
			newLaneDict[note] = true
		end
		local newLane = {}
		for note in pairs(newLaneDict) do
			newLane[#newLane + 1] = note
			note.lane = newLane
		end
		table.sort(newLane, function(a, b)
			return a.startTime < b.startTime
		end)
		lanes[i] = newLane
	end

	for i = 1, #lines do
		local line = lines[i]
		table.sort(line, sortLine)
		line.lines = lines
		line.prev = lines[i - 1]
		line.next = lines[i + 1]
		line.first = lines[i]
		line.last = lines[#lines]
		for j = 1, #line do
			local note = line[j]
			note.left = line[j - 1]
			note.right = line[j + 1]
			note.linePos = note.columnIndex
			note.lanePos = i
			note.index = laneLineIndex
			laneLineIndex[note.lanePos .. ":" .. note.linePos] = note
		end
	end

	for i = 1, #lanes do
		local lane = lanes[i]
		table.sort(lane, sortLane)
		lane.lanes = lanes
		lane.prev = lanes[i - 1]
		lane.next = lanes[i + 1]
		lane.first = lanes[i]
		lane.last = lanes[#lanes]
		for j = 1, #lane do
			local note = lane[j]
			for k = j - 1, 1, -1 do
				note.bottom = lane[k]
				if not note.bottom or not note.bottom.type then
					break
				end
			end
			if note.bottom and note.bottom.type then
				note.bottom = nil
			end
			for k = j + 1, #lane do
				note.top = lane[k]
				if not note.top or not note.top.type then
					break
				end
			end
			if note.top and note.top.type then
				note.top = nil
			end
		end
	end


	for _, line in ipairs(lines) do
		for i, baseNote in ipairs(line) do
			if baseNote.note then
				baseNote.note.distance = baseNote.note.distance or {}
				baseNote.distance = baseNote.note.distance
			end
			baseNote.distance = baseNote.distance or {}
			for _, note in ipairs(line) do
				local trueNote = note.note or note
				baseNote.distance[trueNote] = baseNote.columnIndex - trueNote.columnIndex
			end
		end
	end

	self.lines = lines
	self.lanes = lanes
end

---@param path string
function NotePreprocessor:print(path)
	local file = assert(io.open(path, "w"))
	for i = 1, #self.lines do
		local line = self.lines[i]
		local notes = {}
		for j = 1, #line do
			local note = line[j]
			notes[note.columnIndex] = note
		end
		for j = 1, self.columnCount do
			if notes[j] and not notes[j].type then
				file:write("#")
			elseif notes[j] and notes[j].type == "body" then
				file:write("|")
			elseif notes[j] and notes[j].type == "tail" then
				file:write("v")
			else
				file:write("-")
			end
		end
		file:write(" " .. line.startTime .. "\n")
	end
	file:close()
end

return NotePreprocessor
