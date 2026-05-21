local Note = require("chart.model.notes.Note")
local Notes = require("chart.model.notes.Notes")
local InputMode = require("chart.core.InputMode")
local Modifier = require("sphere.models.ModifierModel.Modifier")

---@class sphere.MultiOverPlay: sphere.Modifier
---@operator call: sphere.MultiOverPlay
local MultiOverPlay = Modifier + {}

MultiOverPlay.name = "MultiOverPlay"

MultiOverPlay.defaultValue = 2
MultiOverPlay.values = {2, 3, 4, 5}

MultiOverPlay.description = "1 2 1 2 -> 12 34 12 34, doubles the input mode"

---@param config table
---@return string
---@return string
function MultiOverPlay:getString(config)
	return tostring(config.value), "OP"
end

---@param config table
---@param state table
function MultiOverPlay:applyMeta(config, state)
	local inputMode = state.inputMode

	local value = config.value
	for inputType, inputCount in pairs(inputMode) do
		inputMode[inputType] = inputCount * value
	end
end

---@param config table
---@param chart chart.Chart
function MultiOverPlay:apply(config, chart)
	local value = config.value

	local inputMode = chart.inputMode

	local new_notes = Notes()
	for _, note in ipairs(chart.notes:getLinkedNotes()) do
		local inputType, inputIndex = InputMode:splitInput(note:getColumn())
		local inputCount = inputMode[inputType]
		if inputCount then
			for i = 1, value do
				local newInputIndex = (inputIndex - 1) * value + i
				local new_note = note:clone()
				new_note:setColumn(inputType .. newInputIndex)
				new_notes:insertLinked(new_note)
			end
		else
			new_notes:insertLinked(note)
		end
	end
	chart.notes = new_notes

	for inputType, inputCount in pairs(inputMode) do
		inputMode[inputType] = inputCount * value
	end

	chart:compute()
end

return MultiOverPlay
