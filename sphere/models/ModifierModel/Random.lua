local SwapModifier = require("sphere.models.ModifierModel.SwapModifier")

---@class sphere.Random: sphere.SwapModifier
---@operator call: sphere.Random
local Random = SwapModifier + {}

Random.name = "Random"

Random.defaultValue = "all"
Random.values = {"all", "left", "right"}

Random.description = "Randomize the note chart"

---@param config table
---@return string
---@return string
function Random:getString(config)
	return "RD", config.value:sub(1, 1):upper()
end

---@param config table
---@param inputMode chart.InputMode
---@return table
function Random:getMap(config, inputMode)
	local value = config.value

	local inputs = {}
	for inputType, inputCount in pairs(inputMode) do
		inputs[inputType] = inputs[inputType] or {}
		local t = inputs[inputType]
		for i = 1, inputCount do
			t[i] = i
		end
	end

	local filteredInputs = {}
	for inputType, subInputs in pairs(inputs) do
		local inputCount = inputMode[inputType]
		filteredInputs[inputType] = {}
		local filteredSubInputs = filteredInputs[inputType]

		local halfFloor = math.floor(inputCount / 2)
		local halfCeil = math.ceil(inputCount / 2)
		for i = 1, #subInputs do
			if value == "all" then
				filteredSubInputs[#filteredSubInputs + 1] = subInputs[i]
			elseif value == "left" then
				if subInputs[i] <= halfFloor then
					filteredSubInputs[#filteredSubInputs + 1] = subInputs[i]
				end
			elseif value == "right" then
				if subInputs[i] > halfCeil then
					filteredSubInputs[#filteredSubInputs + 1] = subInputs[i]
				end
			end
		end
	end

	inputs = filteredInputs

	local map = {}

	for inputType, subInputs in pairs(inputs) do
		local availableIndices = {}
		for i = 1, #subInputs do
			availableIndices[i] = subInputs[i]
		end

		for i = 1, #subInputs do
			local index = math.random(1, #availableIndices)
			map[inputType .. subInputs[i]] = inputType .. availableIndices[index]
			table.remove(availableIndices, index)
		end
	end

	return map
end

return Random
