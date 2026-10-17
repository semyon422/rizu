local Modifier = require("sphere.models.ModifierModel.Modifier")
local Alternate = require("sphere.models.ModifierModel.Alternate")
local InputMode = require("chart.core.InputMode")
local Notes = require("chart.model.notes.Notes")

---@class sphere.Alternate2: sphere.Modifier
---@operator call: sphere.Alternate2
local Alternate2 = Modifier + {}

Alternate2.name = "Alternate2"

Alternate2.defaultValue = "key"
Alternate2.values = {"key", "scratch"}

Alternate2.description = "1 1 1 1 -> 1 1 2 2, doubles the input mode"

---@param config table
---@return string
---@return string
function Alternate2:getString(config)
	return "Alt", "2" .. config.value:sub(1, 1):upper()
end

Alternate2.applyMeta = Alternate.applyMeta

---@param config table
---@param chart chart.Chart
function Alternate2:apply(config, chart)
	local inputMode = chart.inputMode

	local inputType = config.value
	if not inputMode[inputType] then
		return
	end

	---@type number[]
	local alt = {}

	local new_notes = Notes()
	for _, note in ipairs(chart.notes:getLinkedNotes()) do
		local _inputType, inputIndex = InputMode:splitInput(note:getColumn())
		if _inputType ~= inputType then
			new_notes:insertLinked(note)
		elseif _inputType and inputIndex then
			alt[inputIndex] = alt[inputIndex] or 3
			alt[inputIndex] = (alt[inputIndex] + 1) % 4
			local plusColumn = alt[inputIndex] < 2 and 1 or 2
			local newInputIndex = (inputIndex - 1) * 2 + plusColumn
			note:setColumn(_inputType .. newInputIndex)
			new_notes:insertLinked(note)
		end
	end
	chart.notes = new_notes

	inputMode[inputType] = inputMode[inputType] * 2

	chart:compute()
end

return Alternate2
