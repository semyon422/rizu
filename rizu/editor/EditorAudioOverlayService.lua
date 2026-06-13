local class = require("class")

---@class rizu.editor.EditorAudioOverlayState
---@field playingCount integer
---@field offsync number

---@class rizu.editor.EditorAudioOverlayContext
---@field getAudioEngine fun(self: rizu.editor.EditorAudioOverlayContext): rizu.engine.audio.Engine
---@field getTimerTime fun(self: rizu.editor.EditorAudioOverlayContext): number

---@class rizu.editor.EditorAudioOverlayService
---@operator call: rizu.editor.EditorAudioOverlayService
local EditorAudioOverlayService = class()

---@param source table?
---@return integer
local function playingSourceCount(source)
	if source and source.is_playing then
		return 1
	end
	return 0
end

---@param context rizu.editor.EditorAudioOverlayContext
---@return rizu.editor.EditorAudioOverlayState
function EditorAudioOverlayService:getState(context)
	local audioEngine = context:getAudioEngine()
	local audioPosition = audioEngine:getPosition()

	return {
		playingCount = playingSourceCount(audioEngine.source) + playingSourceCount(audioEngine.foregroundSource),
		offsync = audioPosition and context:getTimerTime() - audioPosition or 0,
	}
end

return EditorAudioOverlayService
