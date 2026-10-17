local table_util = require("table_util")

---@param chart chart.Chart
---@param note_types chart.NoteType[]
---@return {time: number, column: integer, input: chart.Column, end_time: number?}[]
local function simplify_notechart(chart, note_types)
	---@type {time: number, column: integer, input: chart.Column, end_time: number?}[]
	local notes = {}

	local inputMap = chart.inputMode:getInputMap()
	local types = table_util.invert(note_types)

	for _, _note in ipairs(chart.notes:getLinkedNotes()) do
		local column = _note:getColumn()
		local col = inputMap[column]
		if col and types[_note:getType()] then
			local note = {
				time = _note:getStartTime(),
				column = col,
				input = column,
			}
			if _note:isLong() then
				note.end_time = _note:getEndTime()
			end
			table.insert(notes, note)
		end
	end
	table.sort(notes, function(a, b)
		if a.time == b.time then
			return a.column < b.column
		end
		return a.time < b.time
	end)

	return notes
end

return simplify_notechart
