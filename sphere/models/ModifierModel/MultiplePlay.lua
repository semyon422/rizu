local Note = require("chart.model.notes.Note")
local Notes = require("chart.model.notes.Notes")
local InputMode = require("chart.core.InputMode")
local Modifier = require("sphere.models.ModifierModel.Modifier")
local MultiOverPlay = require("sphere.models.ModifierModel.MultiOverPlay")

---@class sphere.MultiplePlay: sphere.Modifier
---@operator call: sphere.MultiplePlay
local MultiplePlay = Modifier + {}

MultiplePlay.name = "MultiplePlay"

MultiplePlay.defaultValue = 2
MultiplePlay.values = {2, 3, 4, 5}

MultiplePlay.description = "1 2 1 2 -> 13 24 13 24, doubles the input mode"

---@param config table
---@return string
---@return string
function MultiplePlay:getString(config)
	return tostring(config.value), "P"
end

MultiplePlay.applyMeta = MultiOverPlay.applyMeta

---@param config table
---@param chart ncdk2.Chart
function MultiplePlay:apply(config, chart)
	local value = config.value

	local inputMode = chart.inputMode

	local new_notes = Notes()
	for _, note in ipairs(chart.notes:getLinkedNotes()) do
		local inputType, inputIndex = InputMode:splitInput(note:getColumn())
		local inputCount = inputMode[inputType]
		if inputCount then
			for i = 1, value do
				local newInputIndex = inputIndex + inputCount * (i - 1)
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

return MultiplePlay
