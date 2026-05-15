local class = require("class")
local Converter = require("chartedit.Converter")

---@class rizu.editor.EditorNoteChartLoader
---@operator call: rizu.editor.EditorNoteChartLoader
local NoteChartLoader = class()

---@return chartedit.Layer
---@return chartedit.Notes
function NoteChartLoader:load()
	local chart = self.editorModel.chart
	chart.layers.main:toInterval()
	local layers, notes = Converter:load(chart)
	return layers.main, notes
end

function NoteChartLoader:save()
	local chart = Converter:save({main = self.editorModel.layer}, self.editorModel.notes)
	self.editorModel.chart.layers.main = chart.layers.main
	self.editorModel.chart.notes = chart.notes
end

return NoteChartLoader
