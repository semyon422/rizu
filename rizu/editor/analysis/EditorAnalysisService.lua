local class = require("class")

---@class rizu.editor.EditorAnalysisContext
---@field getNcbtContext fun(self: rizu.editor.EditorAnalysisContext): rizu.editor.NcbtContext
---@field getAudioEngine fun(self: rizu.editor.EditorAnalysisContext): rizu.engine.audio.Engine
---@field getLayer fun(self: rizu.editor.EditorAnalysisContext): chartedit.Layer
---@field getWave fun(self: rizu.editor.EditorAnalysisContext): table?
---@field setWave fun(self: rizu.editor.EditorAnalysisContext, wave: table?)
---@field getGraphsGenerator fun(self: rizu.editor.EditorAnalysisContext): rizu.editor.GraphsGenerator
---@field getChart fun(self: rizu.editor.EditorAnalysisContext): chart.Chart

---@class rizu.editor.EditorAnalysisService
---@operator call: rizu.editor.EditorAnalysisService
local EditorAnalysisService = class()

---@param layer chartedit.Layer|chart.Layer
---@return table
local function getLayerPointList(layer)
	if layer.getPointList then
		return layer:getPointList()
	end

	local points = layer.points
	if points.getPointList then
		return points:getPointList()
	end

	local point = points:getFirstPoint()
	local list = {}
	while point do
		table.insert(list, point)
		point = point.next
	end
	return list
end

---@param context rizu.editor.EditorAnalysisContext
function EditorAnalysisService:detectTempoOffset(context)
	context:getNcbtContext():detect(context:getAudioEngine():renderWave())
end

---@param context rizu.editor.EditorAnalysisContext
function EditorAnalysisService:applyNcbt(context)
	context:getNcbtContext():apply(context:getLayer())
end

---@param context rizu.editor.EditorAnalysisContext
function EditorAnalysisService:renderWave(context)
	context:setWave(context:getAudioEngine():renderWave())
end

---@param context rizu.editor.EditorAnalysisContext
---@return number
---@return number
function EditorAnalysisService:getFirstLastTime(context)
	local layer = context:getLayer()
	local audioStartTime = context:getAudioEngine():getStartTime()
	local wave = context.getWave and context:getWave()

	local firstTime = math.min(
		audioStartTime,
		layer.points:getFirstPoint():tonumber()
	)
	local lastTime = math.max(
		layer.points:getLastPoint():tonumber()
	)
	if wave then
		lastTime = math.max(lastTime, audioStartTime + wave:getDuration())
	end

	return firstTime, lastTime
end

---@param context rizu.editor.EditorAnalysisContext
---@return number
---@return number
function EditorAnalysisService:getTimelineRange(context)
	return self:getFirstLastTime(context)
end

---@param context rizu.editor.EditorAnalysisContext
---@return number totalBeats
---@return number avgBeatDuration
function EditorAnalysisService:getTotalBeats(context)
	local layer = context:getLayer()
	local points = getLayerPointList(layer)
	local firstPoint = points[1]
	local lastPoint = points[#points]
	local totalBeats = (lastPoint.time - firstPoint.time):tonumber()
	local avgBeatDuration = (lastPoint.absoluteTime - firstPoint.absoluteTime) / totalBeats

	return totalBeats, avgBeatDuration
end

---@param context rizu.editor.EditorAnalysisContext
function EditorAnalysisService:genGraphs(context)
	local firstTime, lastTime = self:getTimelineRange(context)
	local graphsGenerator = context:getGraphsGenerator()
	graphsGenerator:genDensityGraph(context:getChart(), firstTime, lastTime)
	graphsGenerator:genVerticesGraph(context:getLayer(), firstTime, lastTime)
end

return EditorAnalysisService
