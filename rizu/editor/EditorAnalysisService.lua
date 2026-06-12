local class = require("class")

---@class rizu.editor.EditorAnalysisContext

---@class rizu.editor.EditorAnalysisService
---@operator call: rizu.editor.EditorAnalysisService
local EditorAnalysisService = class()

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

	local firstTime = math.min(
		context:getAudioEngine():getStartTime(),
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
	local graphsGenerator = context:getGraphsGenerator()
	graphsGenerator:genDensityGraph(context:getChart(), firstTime, lastTime)
	graphsGenerator:genVerticesGraph(context:getLayer(), firstTime, lastTime)
end

return EditorAnalysisService
