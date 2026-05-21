local class = require("class")
local ColumnRenderer = require("sphere.models.RhythmModel.GraphicEngine.ColumnRenderer")
local Point = require("chart.model.tp.Point")
local VisualPoint = require("chart.model.visual.VisualPoint")

---@class sphere.ColumnsRenderer
---@operator call: sphere.ColumnsRenderer
local ColumnsRenderer = class()

---@param chart chart.Chart
---@param graphicEngine sphere.GraphicEngine
function ColumnsRenderer:new(chart, graphicEngine)
	self.chart = chart
	self.graphicEngine = graphicEngine
end

function ColumnsRenderer:load()
	---@type {[chart.Visual]: chart.VisualPoint}
	self.cvp = {}

	for _, visual in ipairs(self.chart:getVisuals()) do
		self.cvp[visual] = VisualPoint(Point())
	end

	---@type {[chart.Column]: sphere.ColumnRenderer}
	self.columnRenderers = {}
	for column, notes in pairs(self.chart.notes:getColumnLinkedNotes()) do
		local columnRenderer = ColumnRenderer(notes, column, self)
		columnRenderer:load()
		self.columnRenderers[column] = columnRenderer
	end
end

function ColumnsRenderer:update()
	local graphicEngine = self.graphicEngine
	local currentTime = graphicEngine:getCurrentTime()

	for _, visual in ipairs(self.chart:getVisuals()) do
		local cvp = self.cvp[visual]
		cvp.point.absoluteTime = currentTime - graphicEngine:getInputOffset()
		visual.interpolator:interpolate(visual.points, cvp, "absolute")
	end

	for _, columnRenderer in pairs(self.columnRenderers) do
		columnRenderer:update()
	end
end

---@generic T
---@param f fun(obj: T, note: sphere.GraphicalNote)
---@param obj T
function ColumnsRenderer:iterNotes(f, obj)
	for _, columnRenderer in pairs(self.columnRenderers) do
		for i = columnRenderer.startNoteIndex, columnRenderer.endNoteIndex do
			f(obj, columnRenderer.notes[i])
		end
	end
end

return ColumnsRenderer
