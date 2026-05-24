local NoteSelector = {}

---@param notes table
---@param check function
---@return table
---@return table
---@return table
local function selectNotes(notes, check)
	local newNotes = {}
	local startTime = {}
	local endTime = {}

	for _, note in ipairs(notes) do
		if check(note) then
			table.insert(startTime, note.startTime)
			endTime[#startTime] = note.endTime
			newNotes[#startTime] = note
		end
	end

	return startTime, endTime, newNotes
end

---@param notes table
---@return function
function NoteSelector.create(notes)
	return function(check)
		local st, et, newNotes = selectNotes(notes, check)
		local c = 0

		return function()
			c = c + 1
			return st[c], et[c], newNotes[c], st, et, newNotes, c
		end
	end
end

return NoteSelector
