local NativeNoteTypes = require("chart.model.NativeNoteTypes")
local Note = require("chart.model.notes.Note")
local table_util = require("table_util")

-- Bridges parser/rules DTOs and ordinary chart notes; never stores object arrays on Chart.
local ModeNotes = {}

---@param chart chart.Chart
---@param layer chart.AbsoluteLayer
---@param visual chart.Visual
---@param mode sea.Gamemode
---@param source table
function ModeNotes.write(chart, layer, visual, mode, source)
	chart.data = {}
	for key, value in pairs(source) do
		if key ~= "objects" and key ~= "buttons" and key ~= "lasers" then
			chart.data[key] = table_util.deepcopy(value)
		end
	end
	---@param object table
	---@param group string
	---@param column chart.Column
	---@param time number
	local function insert(object, group, column, time)
		local data = table_util.deepcopy(object)
		local note = Note(visual:newPoint(layer:getPoint(time)), column, mode .. ":" .. group, 0, data)
		chart.notes:insert(note)
	end
	if mode == "sdvx" then
		for _, object in ipairs(source.buttons) do
			insert(object, "button", object.lane <= 4 and "bt" .. object.lane or "fx" .. (object.lane - 4), object.time)
		end
		for _, object in ipairs(source.lasers) do
			insert(object, "laser", "laser" .. object.lane, object.segments[1].time)
		end
	else
		for _, object in ipairs(source.objects) do insert(object, object.kind, mode .. "1", object.time) end
	end
end

---@param chart chart.Chart
---@param mode sea.Gamemode
---@return table
function ModeNotes.read(chart, mode)
	local result = table_util.copy(chart.data)
	if mode == "sdvx" then result.buttons, result.lasers = {}, {} else result.objects = {} end
	for _, note in chart.notes:iter() do
		if NativeNoteTypes[note.type] == mode then
			local objects = result.objects
			if mode == "sdvx" then
				objects = note.type == "sdvx:button" and result.buttons or result.lasers
			end
			objects[#objects + 1] = note.data
		end
	end
	return result
end

return ModeNotes
