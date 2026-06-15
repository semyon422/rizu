local class = require("class")

---@class rizu.editor.EditorChartSliderState
---@field firstTime number
---@field lastTime number
---@field fullLength number
---@field value number
---@field densityPoints table
---@field vertexPoints table
---@field previewTime number?

---@class rizu.editor.EditorChartSliderInput
---@field active boolean
---@field newValue number?

---@class rizu.editor.EditorChartSliderContext
---@field getPoint fun(self: rizu.editor.EditorChartSliderContext): chartedit.Point
---@field getTimelineRange fun(self: rizu.editor.EditorChartSliderContext): number, number
---@field getDensityGraph fun(self: rizu.editor.EditorChartSliderContext): table
---@field getVertexDataGraph fun(self: rizu.editor.EditorChartSliderContext): table
---@field getPreviewTime fun(self: rizu.editor.EditorChartSliderContext): number?
---@field scrollSeconds fun(self: rizu.editor.EditorChartSliderContext, time: number)
---@field isPlaying fun(self: rizu.editor.EditorChartSliderContext): boolean
---@field play fun(self: rizu.editor.EditorChartSliderContext)
---@field pause fun(self: rizu.editor.EditorChartSliderContext)
---@field isDragging fun(self: rizu.editor.EditorChartSliderContext, owner?: string): boolean
---@field setDragging fun(self: rizu.editor.EditorChartSliderContext, dragging: boolean, owner?: string)

---@class rizu.editor.EditorChartSliderService
---@operator call: rizu.editor.EditorChartSliderService
local EditorChartSliderService = class()

---@param context rizu.editor.EditorChartSliderContext
---@return rizu.editor.EditorChartSliderState
function EditorChartSliderService:getState(context)
	local point = context:getPoint()
	local firstTime, lastTime = context:getTimelineRange()
	local fullLength = lastTime - firstTime

	return {
		firstTime = firstTime,
		lastTime = lastTime,
		fullLength = fullLength,
		value = (point.absoluteTime - firstTime) / fullLength,
		densityPoints = context:getDensityGraph(),
		vertexPoints = context:getVertexDataGraph(),
		previewTime = context:getPreviewTime(),
	}
end

---@param context rizu.editor.EditorChartSliderContext
---@param state rizu.editor.EditorChartSliderState
---@param input rizu.editor.EditorChartSliderInput
function EditorChartSliderService:updateDrag(context, state, input)
	if input.active then
		local newValue = input.newValue
		if newValue then
			context:scrollSeconds(newValue * state.fullLength + state.firstTime)
		end
		if context:isPlaying() then
			context:pause()
			context:setDragging(true, "chartSlider")
		end
	elseif context:isDragging("chartSlider") then
		context:play()
		context:setDragging(false, "chartSlider")
	end
end

return EditorChartSliderService
