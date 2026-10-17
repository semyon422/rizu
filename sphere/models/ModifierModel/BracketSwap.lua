local SwapModifier = require("sphere.models.ModifierModel.SwapModifier")
local ColumnsOrder = require("sea.chart.ColumnsOrder")

---@class sphere.BracketSwap: sphere.SwapModifier
---@operator call: sphere.BracketSwap
local BracketSwap = SwapModifier + {}

BracketSwap.name = "BracketSwap"
BracketSwap.shortName = "BS"

BracketSwap.description = "Brackets to connected chords"

local hardcodedMaps = {
	[4] = {1, 3, 2, 4},
	[5] = {2, 1, 3, 5, 4},
}

for _, t in pairs(hardcodedMaps) do
	for i, v in ipairs(t) do
		t[i] = nil
		t["key" .. i] = "key" .. v
	end
end

---@param config table
---@param inputMode chart.InputMode
---@return table
function BracketSwap:getMap(config, inputMode)
	local keyCount = inputMode.key

	if keyCount <= 5 then
		return hardcodedMaps[keyCount] or {}
	end

	local co = ColumnsOrder(inputMode)
	co:bracketswap()

	return co.map
end

return BracketSwap
