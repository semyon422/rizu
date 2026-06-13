local class = require("class")

---@class rizu.editor.EditorFooterState
---@field absoluteTime number
---@field playPauseLabel string
---@field rate number

---@class rizu.editor.EditorFooterContext
---@field getPoint fun(self: rizu.editor.EditorFooterContext): chartedit.Point
---@field isPlaying fun(self: rizu.editor.EditorFooterContext): boolean
---@field play fun(self: rizu.editor.EditorFooterContext)
---@field pause fun(self: rizu.editor.EditorFooterContext)
---@field getRate fun(self: rizu.editor.EditorFooterContext): number
---@field setRate fun(self: rizu.editor.EditorFooterContext, rate: number)

---@class rizu.editor.EditorFooterService
---@operator call: rizu.editor.EditorFooterService
local EditorFooterService = class()

---@param context rizu.editor.EditorFooterContext
---@return rizu.editor.EditorFooterState
function EditorFooterService:getState(context)
	return {
		absoluteTime = context:getPoint().absoluteTime,
		playPauseLabel = context:isPlaying() and "pause" or "play",
		rate = context:getRate(),
	}
end

---@param context rizu.editor.EditorFooterContext
function EditorFooterService:togglePlayback(context)
	if context:isPlaying() then
		context:pause()
	else
		context:play()
	end
end

---@param context rizu.editor.EditorFooterContext
---@param rate number
function EditorFooterService:setRate(context, rate)
	context:setRate(math.min(math.max(rate, 0.25), 1))
end

return EditorFooterService
