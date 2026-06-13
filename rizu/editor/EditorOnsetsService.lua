local class = require("class")

---@class rizu.editor.EditorOnsetsNodeState
---@field node table
---@field time number
---@field speed number

---@class rizu.editor.EditorOnsetsDistState
---@field onsetsDeltaDist table[]
---@field bins table
---@field binsSize integer

---@class rizu.editor.EditorOnsetsContext
---@field getNcbtContext fun(self: rizu.editor.EditorOnsetsContext): rizu.editor.NcbtContext
---@field getSessionTime fun(self: rizu.editor.EditorOnsetsContext): number
---@field getAudioStartTime fun(self: rizu.editor.EditorOnsetsContext): number

---@class rizu.editor.EditorOnsetsService
---@operator call: rizu.editor.EditorOnsetsService
local EditorOnsetsService = class()

---@param key table
---@return number
local function onsetTime(key)
	return key.time
end

---@param context rizu.editor.EditorOnsetsContext
---@param speed number
---@return rizu.editor.EditorOnsetsNodeState?
function EditorOnsetsService:getOnsetsState(context, speed)
	local onsets = context:getNcbtContext().onsets
	if not onsets then
		return nil
	end

	local time = context:getSessionTime() - context:getAudioStartTime()
	local a, b = onsets:findex(time - 1 / speed, onsetTime)
	local node = a or b
	if not node then
		return nil
	end

	return {
		node = node,
		time = time,
		speed = speed,
	}
end

---@param state rizu.editor.EditorOnsetsNodeState
---@param node table
---@return boolean
function EditorOnsetsService:isNodeVisible(state, node)
	return node.key.time < state.time + 1 / state.speed
end

---@param context rizu.editor.EditorOnsetsContext
---@return rizu.editor.EditorOnsetsDistState?
function EditorOnsetsService:getDistributionState(context)
	local ncbtContext = context:getNcbtContext()
	local onsetsDeltaDist = ncbtContext.onsetsDeltaDist
	if not onsetsDeltaDist or not ncbtContext.bins then
		return nil
	end

	return {
		onsetsDeltaDist = onsetsDeltaDist,
		bins = ncbtContext.bins,
		binsSize = ncbtContext.binsSize,
	}
end

return EditorOnsetsService
