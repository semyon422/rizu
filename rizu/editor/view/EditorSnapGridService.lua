local class = require("class")

---@class rizu.editor.EditorSnapGridLabel
---@field point chartedit.Point
---@field text string
---@field lane integer
---@field kind "timing"|"comment"

---@class rizu.editor.EditorSnapGridContext
---@field getLayer fun(self: rizu.editor.EditorSnapGridContext): chartedit.Layer
---@field getIterRange fun(self: rizu.editor.EditorSnapGridContext): number, number
---@field getVisualPointFor fun(self: rizu.editor.EditorSnapGridContext, point: chartedit.Point): chartedit.VisualPoint

---@class rizu.editor.EditorSnapGridService
---@operator call: rizu.editor.EditorSnapGridService
local EditorSnapGridService = class()

---@param value number
---@return string
local function formatNumber(value)
	if value % 1 == 0 then
		return tostring(value)
	end
	local formatted = ("%.3f"):format(value):gsub("0+$", "")
	return (formatted:gsub("%.$", ""))
end

---@param point chartedit.Point
---@return string?
function EditorSnapGridService:getTimingText(point)
	local vertex = point._vertex or point.vertex
	if not vertex then
		return nil
	end
	return "tempo " .. formatNumber(vertex:getTempo()) .. " bpm"
end

---@param context rizu.editor.EditorSnapGridContext
---@param showTimings boolean
---@return rizu.editor.EditorSnapGridLabel[]
function EditorSnapGridService:getLabels(context, showTimings)
	---@type rizu.editor.EditorSnapGridLabel[]
	local labels = {}
	local layer = context:getLayer()
	---@type string?
	local lastTimingText
	local first_time, last_time = context:getIterRange()
	for point in layer:iter(first_time, last_time) do
		local timingText = showTimings and self:getTimingText(point)
		if timingText and timingText ~= lastTimingText then
			labels[#labels + 1] = {
				point = point,
				text = timingText,
				lane = 0,
				kind = "timing",
			}
			lastTimingText = timingText
		end

		local visualPoint = context:getVisualPointFor(point)
		local comment = visualPoint.comment
		if comment then
			labels[#labels + 1] = {
				point = point,
				text = comment,
				lane = 1,
				kind = "comment",
			}
		end
	end
	return labels
end

return EditorSnapGridService
