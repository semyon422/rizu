local Modifier = require("sphere.models.ModifierModel.Modifier")
local InputMode = require("chart.core.InputMode")
local Notes = require("chart.model.notes.Notes")

---@class sphere.Alternate: sphere.Modifier
---@operator call: sphere.Alternate
local Alternate = Modifier + {}

Alternate.name = "Alternate"

Alternate.defaultValue = "key"
Alternate.values = {"key", "scratch"}

Alternate.description = "1 1 1 1 -> 1 2 1 2, doubles the input mode"

---@param config table
---@return string
---@return string
function Alternate:getString(config)
	return "Alt", config.value:sub(1, 1):upper()
end

function Alternate:applyMeta(config, state)
	local inputType = config.value
	local inputMode = state.inputMode
	if not inputMode[inputType] then
		return
	end
	inputMode[inputType] = inputMode[inputType] * 2
end

---@param config table
---@param chart chart.Chart
function Alternate:apply(config, chart)
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
			alt[inputIndex] = math.abs((alt[inputIndex] or 1) - 1)
			local newInputIndex = (inputIndex - 1) * 2 + 1 + alt[inputIndex]
			note:setColumn(_inputType .. newInputIndex)
			new_notes:insertLinked(note)
		end
	end
	chart.notes = new_notes

	inputMode[inputType] = inputMode[inputType] * 2

	chart:compute()
end

return Alternate
