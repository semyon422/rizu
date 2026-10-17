local Note = require("chart.model.notes.Note")
local NativeNoteTypes = require("chart.model.NativeNoteTypes")

local Objects = {}

---@param chart chart.Chart
---@param mode sea.Gamemode
---@return table[]
function Objects.get(chart, mode)
	local objects = {}
	for _, note in chart.notes:iter() do
		if NativeNoteTypes[note.type] == mode then objects[#objects + 1] = note.data end
	end
	return objects
end

---@param chart chart.Chart
---@param layer chart.AbsoluteLayer
---@param visual chart.Visual
---@param mode sea.Gamemode
---@param object table
function Objects.insert(chart, layer, visual, mode, object)
	chart.notes:insert(Note(visual:newPoint(layer:getPoint(object.time)), mode .. "1", mode .. ":" .. object.kind, 0, object))
end

return Objects
