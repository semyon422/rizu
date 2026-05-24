local class = require("class")
local Layer = require("chart.refchart.Layer")
local Note = require("chart.refchart.Note")

---@class refchart.RefChart
---@operator call: refchart.RefChart
---@field inputmode chart.InputMode
---@field layers {[string]: refchart.Layer}
---@field notes refchart.Note[]
---@field resources string[][]
local RefChart = class()

---@param chart chart.Chart
function RefChart:new(chart)
	self.inputmode = chart.inputMode

	---@type {[chart.VisualPoint]: refchart.VisualPointReference}
	local vp_ref = {}

	self.layers = {}
	local layers = self.layers
	for l_name, layer in pairs(chart.layers) do
		layers[l_name] = Layer(layer, l_name, vp_ref)
	end

	self.notes = {}
	local notes = self.notes
	for i, note in ipairs(chart.notes.notes) do
		notes[i] = Note(note, vp_ref[note.visualPoint])
	end

	self.resources = {}
	local resources = self.resources
	for _type, paths in chart.resources:iter() do
		table.insert(resources, {_type, unpack(paths)})
	end
end

return RefChart
