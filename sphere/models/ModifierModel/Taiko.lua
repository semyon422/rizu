local Modifier = require("sphere.models.ModifierModel.Modifier")
local InputMode = require("chart.core.InputMode")
local Notes = require("chart.model.notes.Notes")

---@class sphere.Taiko: sphere.Modifier
---@operator call: sphere.Taiko
local Taiko = Modifier + {}

Taiko.name = "Taiko"
Taiko.shortName = "TK"

Taiko.description = "Converts mania 4K to taiko 2K (experimental)"

function Taiko:applyMeta(config, state)
	if state.inputMode.key ~= 4 then
		return
	end
	state.inputMode.key = 2
end

local function getKey(i)
	if i == 1 or i == 4 then
		return 2
	end
	return 1
end

---@param config table
---@param chart chart.Chart
function Taiko:apply(config, chart)
	local inputMode = chart.inputMode

	if tostring(inputMode) ~= "4key" then
		return
	end

	local new_notes = Notes()
	for _, _note in ipairs(chart.notes:getLinkedNotes()) do
		local inputType, inputIndex = InputMode:splitInput(_note:getColumn())
		if inputType == "key" then
			local note = _note.startNote
			note.type = "tap"
			note.column = "key" .. getKey(inputIndex)
			local found_note = new_notes:get(note.visualPoint, note.column)
			if not found_note then
				new_notes:insert(note)
			else
				found_note.isDouble = true
			end
		else
			new_notes:insertLinked(_note)
		end
	end
	chart.notes = new_notes

	inputMode.key = 2

	chart:compute()
end

return Taiko
