local Modifier = require("sphere.models.ModifierModel.Modifier")

---@class sphere.NoLongNote: sphere.Modifier
---@operator call: sphere.NoLongNote
local NoLongNote = Modifier + {}

NoLongNote.name = "NoLongNote"
NoLongNote.shortName = "NLN"

NoLongNote.description = "Remove long notes"

---@param config table
---@param chart chart.Chart
function NoLongNote:apply(config, chart)
	for _, note in ipairs(chart.notes:getLinkedNotes()) do
		if note:getType() == "hold" or note:getType() == "laser" then
			if note.endNote then
				note.endNote.type = "ignore"
			end
			note:unlink()
			note:setType("tap")
		end
	end
end

return NoLongNote
