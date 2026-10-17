local Modifier = require("sphere.models.ModifierModel.Modifier")

---@class sphere.MinLnLength: sphere.Modifier
---@operator call: sphere.MinLnLength
local MinLnLength = Modifier + {}

MinLnLength.name = "MinLnLength"

MinLnLength.defaultValue = 0.4
MinLnLength.values = {}

for i = 0, 39 do
	table.insert(MinLnLength.values, i * 0.025)  -- [0, 1)
end
for i = 0, 40 do
	table.insert(MinLnLength.values, 1 + i * 0.1)
end

MinLnLength.description = "Convert long notes to short notes if they are shorter than this length"

---@param config table
---@return string
---@return string
function MinLnLength:getString(config)
	return "MLL", tostring(config.value * 1000)
end

---@param config table
---@param chart chart.Chart
function MinLnLength:apply(config, chart)
	local duration = config.value

	for _, note in ipairs(chart.notes:getLinkedNotes()) do
		if note:getType() == "hold" and note:getDuration() <= duration then
			if note.endNote then
				note.endNote.type = "ignore"
			end
			note:unlink()
			note:setType("tap")
		end
	end
end

return MinLnLength
