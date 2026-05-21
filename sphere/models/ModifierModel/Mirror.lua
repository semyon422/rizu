local SwapModifier = require("sphere.models.ModifierModel.SwapModifier")

---@class sphere.Mirror: sphere.SwapModifier
---@operator call: sphere.Mirror
local Mirror = SwapModifier + {}

Mirror.name = "Mirror"

Mirror.defaultValue = "all"
Mirror.values = {"all", "left", "right"}

Mirror.description = "Mirror the note chart"

---@param config table
---@return string
---@return string
function Mirror:getString(config)
	return "MR", config.value:sub(1, 1):upper()
end

---@param config table
---@param inputMode ncdk.InputMode
---@return table
function Mirror:getMap(config, inputMode)
	---@type {[chart.Column]: chart.Column}
	local map = {}

	local value = config.value
	for inputType, inputCount in pairs(inputMode) do
		local halfFloor = math.floor(inputCount / 2)
		local halfCeil = math.ceil(inputCount / 2)
		if value == "all" then
			for i = 1, inputCount do
				map[inputType .. i] = inputType .. (inputCount - i + 1)
			end
		elseif value == "left" then
			for i = 1, halfFloor do
				map[inputType .. i] = inputType .. (halfFloor - i + 1)
			end
		elseif value == "right" then
			for i = 1, halfFloor do
				map[inputType .. (halfCeil + i)] = inputType .. (inputCount - i + 1)
			end
		end
	end

	return map
end

return Mirror
