local class = require("class")
local SolutionSeeker = require("chart.transform.SolutionSeeker")

local NextUpscaler = class()

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

---@param i number
---@param lane number
---@return number?
function NextUpscaler:getPrevNoteIndex(i, lane)
	for k = i - 1, 1, -1 do
		local cnote = self.notes[k]
		if cnote.seeker.lane == lane then
			return k
		end
	end
end

---@param i number
---@param lane number
---@return table?
function NextUpscaler:getPrevNote(i, lane)
	return self.notes[self:getPrevNoteIndex(i, lane)]
end

---@param i number
---@param lane number
---@return number
function NextUpscaler:getDelta(i, lane)
	local startTime = self.notes[i].startTime
	local prevNoteIndex = self:getPrevNoteIndex(i, lane)
	if prevNoteIndex then
		return math.max(0, startTime - self.notes[prevNoteIndex].endTime)
	end
	return startTime + 1000
end

---@param i number
---@param lane number
---@return number
function NextUpscaler:checkHorizontalSpacing(i, lane)
	local note = self.notes[i]

	local rates = {}
	for columnIndex = 1, self.targetMode do
		rates[columnIndex] = 1
	end

	for columnIndex = 1, self.targetMode do
		local prevNoteIndex = self:getPrevNoteIndex(i, lane)

		if prevNoteIndex then
			local prevNote = self.notes[prevNoteIndex]

			local deltaTime = note.startTime - prevNote.endTime
			if deltaTime <= 0 then
				rates[columnIndex] = 0

				local distance = note.distance[prevNote]
				for columnIndex2 = 1, self.targetMode do
					if not distance then break end
					if
						rates[columnIndex2] > 0 and
						math.abs(columnIndex2 - prevNote.columnIndex) >= math.abs(distance) and
						(columnIndex2 - prevNote.columnIndex) * distance > 0
					then
						rates[columnIndex2] = rates[columnIndex2]
					else
						rates[columnIndex2] = 0
					end
				end
			end
		end
	end

	return rates[lane]
end

---@param i number
---@param lane number
---@return number
function NextUpscaler:checkVerticalSpacing(i, lane)
	local note = self.notes[i]
	local prevNote = self:getPrevNote(i, lane)

	if not prevNote then
		return 1
	end

	local basePrevNote = note.bottom
	if basePrevNote then
		local baseDelta = note.startTime - basePrevNote.endTime
		local delta = note.startTime - prevNote.endTime

		if delta < baseDelta then
			return 0
		end
	end

	local nextNote = note
	note = prevNote

	local baseNextNote = note.top
	if baseNextNote then
		local baseDelta = baseNextNote.startTime - note.endTime
		local delta = nextNote.startTime - note.endTime

		if delta < baseDelta then
			return 0
		end
	end

	return 1
end

local recursionLimit = 0

---@param noteIndex number
---@param lane number
---@return number
function NextUpscaler:check(noteIndex, lane)
	local rate = 1

	local note = self.notes[noteIndex]

	if not note then
		return rate
	end

	rate = rate * intersectSegment(lane, self.targetMode, note.columnIndex, self.columnCount)
	if rate == 0 then return rate end

	rate = rate * self:getDelta(noteIndex, lane) / 1000
	if rate == 0 then return rate end

	rate = rate * self:checkHorizontalSpacing(noteIndex, lane)
	if rate == 0 then return rate end

	rate = rate * self:checkVerticalSpacing(noteIndex, lane)
	if rate == 0 then return rate end

	-- disabled, recursion is not completed
	if recursionLimit ~= 0 then
		recursionLimit = recursionLimit - 1
		local maxNextRate = 0
		for i = 1, self.targetMode do
			maxNextRate = math.max(maxNextRate, self:check(noteIndex + 1, i))
		end
		rate = rate * maxNextRate
		recursionLimit = recursionLimit + 1
	end

	return rate
end

function NextUpscaler:process()
	local check = function(noteIndex, lane)
		return self:check(noteIndex, lane)
	end

	local status, err = SolutionSeeker:solve(self.notes, self.targetMode, check)
	assert(status, err)

	for _, note in ipairs(self.notes) do
		note.columnIndex = note.seeker.lane
	end
end

return NextUpscaler
