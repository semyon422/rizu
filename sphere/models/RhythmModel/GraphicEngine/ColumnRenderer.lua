local class = require("class")
local table_util = require("table_util")
local GraphicalNoteFactory = require("sphere.models.RhythmModel.GraphicEngine.GraphicalNoteFactory")

---@class sphere.ColumnRenderer
---@operator call: sphere.ColumnRenderer
local ColumnRenderer = class()

---@param notes chart.LinkedNote[]
---@param column chart.Column
---@param columnsRenderer sphere.ColumnsRenderer
function ColumnRenderer:new(notes, column, columnsRenderer)
	self._notes = notes
	self.column = column
	self.columnsRenderer = columnsRenderer
end

local function sort_const(a, b)
	return a.startNote.visualPoint.point:compare(b.startNote.visualPoint.point)
end

local function sort_visual(a, b)
	return a.startNote.visualPoint:compare(b.startNote.visualPoint)
end

function ColumnRenderer:load()
	local columnsRenderer = self.columnsRenderer
	local graphicEngine = columnsRenderer.graphicEngine
	local chart = columnsRenderer.chart

	self.notes = {}
	local notes = self.notes

	for _, _note in ipairs(self._notes) do
		local note = GraphicalNoteFactory:getNote(_note)
		if note then
			local visual = chart:getVisualByPoint(_note.startNote.visualPoint)
			note.currentVisualPoint = columnsRenderer.cvp[visual]
			note.visual = visual
			note.graphicEngine = graphicEngine
			note.column = self.column
			table.insert(notes, note)
		end
	end

	if graphicEngine.constant then
		table.sort(notes, sort_const)
	else
		table.sort(notes, sort_visual)
	end

	for i, note in ipairs(notes) do
		note.nextNote = notes[i + 1]
	end

	self.startNoteIndex = 1
	self.endNoteIndex = 0
end

function ColumnRenderer:update()
	local notes = self.notes
	---@type sphere.GraphicalNote
	local note

	for i = self.startNoteIndex, self.endNoteIndex do
		notes[i]:update()
	end

	for i = self.startNoteIndex, 2, -1 do
		note = notes[i - 1]
		note:update()
		if note:willDrawBeforeStart() or i ~= self.startNoteIndex then
			break
		end
		self.startNoteIndex = self.startNoteIndex - 1
	end

	for i = self.endNoteIndex, #notes - 1, 1 do
		note = notes[i + 1]
		note:update()
		if note:willDrawAfterEnd() or i ~= self.endNoteIndex then
			break
		end
		self.endNoteIndex = self.endNoteIndex + 1
	end

	for i = self.startNoteIndex, self.endNoteIndex do
		note = notes[i]
		if not note:willDrawBeforeStart() then
			break
		end
		self.startNoteIndex = self.startNoteIndex + 1
	end

	for i = self.endNoteIndex, self.startNoteIndex, -1 do
		note = notes[i]
		if not note:willDrawAfterEnd() then
			break
		end
		self.endNoteIndex = self.endNoteIndex - 1
	end
end

return ColumnRenderer
