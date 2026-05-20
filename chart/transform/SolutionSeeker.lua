local SolutionSeeker = {}

-- local sortRates = function(a, b)
-- 	return a[2] > b[2]
-- end

---@param seeker any
function SolutionSeeker:onForward(seeker)

end

---@param seeker any
function SolutionSeeker:onBackward(seeker)

end

---@param notes table
---@param laneCount number
---@param check function
---@param startNoteIndex number?
---@return boolean
---@return string?
function SolutionSeeker:solve(notes, laneCount, check, startNoteIndex)
	local noteIndex = startNoteIndex or 1
	while true do
		local note = notes[noteIndex]
		if not note then
			break
		end

		local seeker = note.seeker
		if not seeker then
			seeker = {}
			note.seeker = seeker
			seeker.note = note
		end

		local lanes = seeker.lanes
		if not lanes then
			lanes = {}
			seeker.lanes = lanes
			for lane = 1, laneCount do
				lanes[#lanes + 1] = 0
			end
		end

		local rates = seeker.rates
		if not rates then
			rates = {}
			seeker.rates = rates
			for lane = 1, laneCount do
				rates[#rates + 1] = {lane, check(noteIndex, lane)}
			end
			-- table.sort(rates, sortRates)
		end

		local topLane
		local topRate = 0
		for k = 1, #rates do
			local lane = rates[k][1]
			local rate = rates[k][2]
			if lanes[lane] == 0 and rate > topRate then
				topLane = lane
				topRate = rate
			end
		end

		if topLane then
			lanes[topLane] = 1
			seeker.lane = topLane
		end

		if seeker.lane then
			-- print("forward", noteIndex, seeker.lane)
			noteIndex = noteIndex + 1
			self:onForward(seeker)
		else
			-- for i = 1, laneCount do
			-- 	print(rates[i][1], rates[i][2])
			-- end
			-- io.read()
			self:onBackward(seeker)
			seeker.lanes = nil
			seeker.rates = nil
			local prevNote = notes[noteIndex - 1]
			if not prevNote then
				break
			end
			local prevSeeker = prevNote.seeker
			prevSeeker.lanes[prevSeeker.lane] = -1
			prevSeeker.lane = nil
			noteIndex = noteIndex - 1
			-- print("back" .. noteIndex, unpack(prevSeeker.lanes))
		end
	end
	if noteIndex == 1 then
		return false, "Can not solve"
	else
		return true
	end
end

return SolutionSeeker
