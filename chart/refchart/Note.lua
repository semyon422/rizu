local class = require("class")
local table_util = require("table_util")

---@class refchart.Note
---@operator call: refchart.Note
---@field point refchart.VisualPointReference
---@field column chart.Column
---@field type chart.NoteType
---@field weight integer
local Note = class()

---@param note chart.Note
---@param point refchart.VisualPointReference
function Note:new(note, point)
	self.point = point
	self.column = note.column
	self.type = note.type
	self.weight = note.weight
	self.data = table_util.deepcopy(note.data)
end

return Note
