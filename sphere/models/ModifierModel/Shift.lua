local SwapModifier = require("sphere.models.ModifierModel.SwapModifier")

---@class sphere.Shift: sphere.SwapModifier
---@operator call: sphere.Shift
local Shift = SwapModifier + {}

Shift.name = "Shift"

Shift.defaultValue = 1
Shift.values = {}

for i = -5, 5 do
	if i ~= 0 then
		table.insert(Shift.values, i)
	end
end

Shift.description = "Shift the note chart"

---@param config table
---@return string?
---@return string?
function Shift:getString(config)
	if config.value > 0 then
		return "S+", math.abs(config.value)
	elseif config.value < 0 then
		return "S-", math.abs(config.value)
	end
end

---@param config table
---@param inputMode chart.InputMode
---@return table
function Shift:getMap(config, inputMode)
	local map = {}

	local value = config.value
	for inputType, inputCount in pairs(inputMode) do
		for i = 1, inputCount do
			map[inputType .. i] = inputType .. ((i + value - 1) % inputCount + 1)
		end
	end

	return map
end

return Shift
