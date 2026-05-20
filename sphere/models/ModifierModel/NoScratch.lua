local Modifier = require("sphere.models.ModifierModel.Modifier")
local InputMode = require("chart.core.InputMode")
local Notes = require("chart.model.notes.Notes")

---@class sphere.NoScratch: sphere.Modifier
---@operator call: sphere.NoScratch
local NoScratch = Modifier + {}

NoScratch.name = "NoScratch"
NoScratch.shortName = "NSC"

NoScratch.description = "Remove scratch notes"

---@param config table
---@param state table
function NoScratch:applyMeta(config, state)
	state.inputMode.scratch = nil
end

---@param config table
---@param chart ncdk2.Chart
function NoScratch:apply(config, chart)
	chart.inputMode.scratch = nil

	local new_notes = Notes()
	for _, note in chart.notes:iter() do
		local inputType, inputIndex = InputMode:splitInput(note.column)
		if inputType == "scratch" then
			note.type = "sample"
			note.column = "autoscratch" .. inputIndex
		end
		new_notes:insert(note)
	end
	chart.notes = new_notes
end

return NoScratch
