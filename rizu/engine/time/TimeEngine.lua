local class = require("class")
local TimeAdjust = require("rizu.engine.time.TimeAdjust")
local LocalTimer = require("rizu.engine.time.LocalTimer")
local VisualEnhancer = require("rizu.engine.time.VisualEnhancer")

---@class rizu.TimeEngine
---@operator call: rizu.TimeEngine
local TimeEngine = class()

TimeEngine.const = false

function TimeEngine:new()
	self.adjust = TimeAdjust()
	self.enhancer = VisualEnhancer()
	self.timer = LocalTimer()
	self:updateTime()
end

---@param global_time number
function TimeEngine:setGlobalTime(global_time)
	self.timer:setGlobalTime(global_time)
	self:adjustTime()
	self:updateTime()
end

---@param time number
function TimeEngine:setTime(time)
	self.timer:setTime(time, true)
	self:updateTime()
end

---@param rate number
function TimeEngine:setRate(rate)
	self.timer:setRate(rate)
end

---@param adjust_factor number
function TimeEngine:setAdjustFactor(adjust_factor)
	self.adjust:setFactor(adjust_factor)
end

---@param adjust_time fun(): number?
function TimeEngine:setAdjustFunction(adjust_time)
	self.adjust_time = adjust_time
end

---@return number
function TimeEngine:getOffsync()
	local adjust_time = self.adjust_time and self.adjust_time()
	if not adjust_time then
		return 0
	end

	return self.time - adjust_time
end

---@private
function TimeEngine:adjustTime()
	if not self.timer.is_playing then
		return
	end

	local adjust_time = self.adjust_time and self.adjust_time()
	if not adjust_time then
		return
	end

	local adjusted_time = self.adjust:adjust(self.timer:getTime(true), adjust_time)
	if not adjusted_time then
		return
	end

	self.timer:setTime(adjusted_time)
end

---@private
function TimeEngine:updateTime()
	self.time = self.timer:getTime()
	self.time_no_mono = self.timer:getTime(true)

	local enh_time = self.time
	if not self.const then
		enh_time = self.enhancer:get(enh_time)
	end
	self.enh_time = enh_time
end

function TimeEngine:pause()
	self.timer:pause()
end

function TimeEngine:play()
	self.timer:play()
end

return TimeEngine
