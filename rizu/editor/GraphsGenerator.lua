local class = require("class")
local math_util = require("math_util")

---@class rizu.editor.GraphsGenerator
---@operator call: rizu.editor.GraphsGenerator
local GraphsGenerator = class()

function GraphsGenerator:load()
	self.densityGraph = {}
	self.intervalDatasGraph = {n = 0}
end

---@param chart ncdk2.Chart
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
function GraphsGenerator:genIntervalsGraph(layer, firstTime, lastTime)
	local ivl = layer.points:getFirstPoint().interval

	local offsets = {}
	while ivl do
		table.insert(offsets, ivl.point.absoluteTime)
		ivl = ivl.next
	end
	table.sort(offsets)

	local pointsCount = 2000

	self.intervalDatasGraph = {n = pointsCount}
	local points = self.intervalDatasGraph

	for _, time in ipairs(offsets) do
		local pos = math_util.map(time, firstTime, lastTime, 0, pointsCount)
		local i = math.floor(pos + 0.5)
		points[i] = true
	end
end

return GraphsGenerator
