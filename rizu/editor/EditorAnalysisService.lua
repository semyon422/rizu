local class = require("class")

---@class rizu.editor.EditorAnalysisContext
---@field getNcbtContext fun(self: rizu.editor.EditorAnalysisContext): rizu.editor.NcbtContext
---@field getAudioEngine fun(self: rizu.editor.EditorAnalysisContext): rizu.engine.audio.Engine
---@field getLayer fun(self: rizu.editor.EditorAnalysisContext): chartedit.Layer
---@field setWave fun(self: rizu.editor.EditorAnalysisContext, wave: table?)
---@field getGraphsGenerator fun(self: rizu.editor.EditorAnalysisContext): rizu.editor.GraphsGenerator
---@field getChart fun(self: rizu.editor.EditorAnalysisContext): chart.Chart

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
