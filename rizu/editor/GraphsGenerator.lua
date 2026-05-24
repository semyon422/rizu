local class = require("class")
local math_util = require("math_util")

---@class rizu.editor.GraphsGenerator
---@operator call: rizu.editor.GraphsGenerator
local GraphsGenerator = class()

function GraphsGenerator:load()
	self.densityGraph = {}
	self.vertexDatasGraph = {n = 0}
end

---@param chart chart.Chart
---@param firstTime number
---@param lastTime number
function GraphsGenerator:genDensityGraph(chart, firstTime, lastTime)
	local notes = {}
	for _, note in chart.notes:iter() do
		local offset = note:getTime()
		if note.weight >= 0 then
			table.insert(notes, offset)
		end
	end
	table.sort(notes)

	local pointsCount = math.floor(lastTime - firstTime) * 2

	if pointsCount == 0 then
		return
	end

	self.densityGraph = {}
	local points = self.densityGraph
	for i = 0, pointsCount do
		points[i] = 0
	end

	local maxValue = 0
	for _, time in ipairs(notes) do
		local pos = math_util.map(time, firstTime, lastTime, 0, pointsCount)
		local i = math.floor(pos + 0.5)
		points[i] = points[i] + 1
		maxValue = math.max(maxValue, points[i])
	end

	for i = 0, pointsCount do
		points[i] = points[i] / maxValue
	end
end

---@param layer chartedit.Layer
---@param firstTime number
---@param lastTime number
function GraphsGenerator:genVerticesGraph(layer, firstTime, lastTime)
	local vertex = layer.points:getFirstPoint().vertex

	local offsets = {}
	while vertex do
		table.insert(offsets, vertex.point.absoluteTime)
		vertex = vertex.next
	end
	table.sort(offsets)

	local pointsCount = 2000

	self.vertexDatasGraph = {n = pointsCount}
	local points = self.vertexDatasGraph

	for _, time in ipairs(offsets) do
		local pos = math_util.map(time, firstTime, lastTime, 0, pointsCount)
		local i = math.floor(pos + 0.5)
		points[i] = true
	end
end

return GraphsGenerator
