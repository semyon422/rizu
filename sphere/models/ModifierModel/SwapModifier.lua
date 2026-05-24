local table_util = require("table_util")
local Modifier = require("sphere.models.ModifierModel.Modifier")
local Notes = require("chart.model.notes.Notes")

---@class sphere.SwapModifier: sphere.Modifier
---@operator call: sphere.SwapModifier
local SwapModifier = Modifier + {}

SwapModifier.name = "SwapModifier"

---@param config table
---@param inputMode ncdk.InputMode
---@return {[ncdk2.Column]: ncdk2.Column}
function SwapModifier:getMap(config, inputMode)
	return {}
end

---@param config table
---@param chart ncdk2.Chart
function SwapModifier:apply(config, chart)
	local map = self:getMap(config, chart.inputMode)

	local new_notes = Notes()
	for _, note in chart.notes:iter() do
		note.column = map[note.column] or note.column
		new_notes:insert(note)
	end
	chart.notes = new_notes
end

return SwapModifier
