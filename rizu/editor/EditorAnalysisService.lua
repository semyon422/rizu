local class = require("class")

---@class rizu.editor.EditorAnalysisContext
---@field ncbtContext rizu.editor.NcbtContext
---@field audio_engine rizu.engine.audio.Engine
---@field layer chartedit.Layer
---@field chart chart.Chart
---@field graphsGenerator rizu.editor.GraphsGenerator
---@field setWave fun(wave: table?)

---@class rizu.editor.EditorAnalysisService
---@operator call: rizu.editor.EditorAnalysisService
local EditorAnalysisService = class()

---@param context rizu.editor.EditorAnalysisContext
function EditorAnalysisService:detectTempoOffset(context)
	context.ncbtContext:detect(context.audio_engine:renderWave())
end

---@param context rizu.editor.EditorAnalysisContext
function EditorAnalysisService:applyNcbt(context)
	context.ncbtContext:apply(context.layer)
end

---@param context rizu.editor.EditorAnalysisContext
function EditorAnalysisService:renderWave(context)
	context.setWave(context.audio_engine:renderWave())
end

---@param context rizu.editor.EditorAnalysisContext
---@return number
---@return number
function EditorAnalysisService:getFirstLastTime(context)
	local layer = context.layer

	local firstTime = math.min(
		context.audio_engine:getStartTime(),
		layer.points:getFirstPoint():tonumber()
	)
	local lastTime = math.max(
		layer.points:getLastPoint():tonumber()
	)

	return firstTime, lastTime
end

---@param context rizu.editor.EditorAnalysisContext
---@return number
---@return number
function EditorAnalysisService:getTimelineRange(context)
	return self:getFirstLastTime(context)
end

---@param context rizu.editor.EditorAnalysisContext
function EditorAnalysisService:genGraphs(context)
	local firstTime, lastTime = self:getTimelineRange(context)
	context.graphsGenerator:genDensityGraph(context.chart, firstTime, lastTime)
	context.graphsGenerator:genVerticesGraph(context.layer, firstTime, lastTime)
end

return EditorAnalysisService
