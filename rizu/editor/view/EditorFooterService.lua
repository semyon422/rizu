local class = require("class")
local math_util = require("math_util")
local time_util = require("time_util")

---@class rizu.editor.EditorFooterState
---@field absoluteTime number
---@field absoluteTimeLabel string
---@field playPauseLabel string
---@field rate number
---@field rateLabel string
---@field rateMin number
---@field rateMax number
---@field rateStep number

---@class rizu.editor.EditorFooterInput
---@field togglePlayback boolean
---@field rateFraction number?

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

local rateMin = 0.5
local rateMax = 2
local rateStep = 0.01

---@param value number
---@param step number
---@return number
local function snap(value, step)
	return math.floor(value / step + 0.5) * step
end

---@param context rizu.editor.EditorFooterContext
---@return rizu.editor.EditorFooterState
function EditorFooterService:getState(context)
	local rate = context:getRate()
	return {
		absoluteTime = context:getPoint().absoluteTime,
		absoluteTimeLabel = time_util.format(context:getPoint().absoluteTime, 3),
		playPauseLabel = context:isPlaying() and "pause" or "play",
		rate = rate,
		rateLabel = ("%0.2fx"):format(rate),
		rateMin = rateMin,
		rateMax = rateMax,
		rateStep = rateStep,
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
	context:setRate(math.min(math.max(rate, rateMin), rateMax))
end

---@param context rizu.editor.EditorFooterContext
---@param state rizu.editor.EditorFooterState
---@param input rizu.editor.EditorFooterInput
function EditorFooterService:handleInput(context, state, input)
	if input.togglePlayback then
		self:togglePlayback(context)
	end

	local rateFraction = input.rateFraction
	if not rateFraction then
		return
	end

	local rate = snap(math_util.map(rateFraction, 0, 1, state.rateMin, state.rateMax), state.rateStep)
	if rate ~= state.rate then
		self:setRate(context, rate)
	end
end

return EditorFooterService
