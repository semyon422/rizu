local class = require("class")
local math_util = require("math_util")
local Observable = require("Observable")
local TimeManager = require("sphere.models.RhythmModel.TimeEngine.TimeManager")
local NearestTime = require("sphere.models.RhythmModel.TimeEngine.NearestTime")
local VisualTimeInfo = require("sphere.models.RhythmModel.TimeEngine.VisualTimeInfo")

---@class sphere.TimeEngine
---@operator call: sphere.TimeEngine
local TimeEngine = class()

TimeEngine.timeToPrepare = 2
TimeEngine.constant = false

function TimeEngine:new()
	self.observable = Observable()
	self.nearestTime = NearestTime(0.001)

	self.timer = TimeManager()
	self.timer.timeEngine = self
	self.timer:setGlobalTime(0)

	self.visualTimeInfo = VisualTimeInfo()
end

TimeEngine.startTime = 0
TimeEngine.currentTime = 0
TimeEngine.timeRate = 1
TimeEngine.baseTimeRate = 1
TimeEngine.windUp = nil

function TimeEngine:load()
	self.timer:pause()
	self.timer:setRate(self.timeRate)

	self.nearestTime:loadTimePoints(self.noteChart)

	local t = -self.timeToPrepare * self.baseTimeRate
	self.timer:setTime(t)

	self.startTime = t
	self.currentTime = t
	self.visualTimeInfo.time = t
	self.visualTimeInfo.rate = self.timeRate
end

---@param start_time number
---@param duration number
function TimeEngine:setPlayTime(start_time, duration)
	self.minTime = start_time
	self.maxTime = start_time + duration
end

---@param time number
function TimeEngine:sync(time)
	local timer = self.timer

	timer:setGlobalTime(time)

	self.currentTime = timer:getTime()
	self.visualTimeInfo.time = self.constant and self.currentTime or self.nearestTime:getVisualTime(self.currentTime)

	if self.windUp then
		self:updateWindUp()
	end
end

function TimeEngine:stepTimePoint(is_left)
	local nt = self.nearestTime
	local time
	if is_left then
		time = nt:getPrevTime(self.currentTime)
	else
		time = nt:getNextTime(self.currentTime)
	end
	if time then
		self:setPosition(time)
	end
end

function TimeEngine:stepTime(dt)
	self:setPosition(math_util.round(self.currentTime + dt, math.abs(dt)))
end

function TimeEngine:skipIntro()
	local skipTime = self.minTime - self.timeToPrepare * self.timeRate
	if self.currentTime < skipTime and self.timer.is_playing then
		self:setPosition(skipTime)
	end
end

function TimeEngine:updateWindUp()
	local currentTime = self.currentTime
	local startTime = self.minTime or currentTime
	local endTime = self.maxTime or currentTime

	local a, b = unpack(self.windUp)
	local timeRate = math_util.map(currentTime, startTime, endTime, a, b)
	timeRate = math.min(math.max(timeRate, a), b)

	self:setTimeRate(timeRate * self.baseTimeRate)
end

---@param position number
function TimeEngine:setPosition(position)
	local timer = self.timer
	local audioEngine = self.audioEngine

	audioEngine:setPosition(position)
	timer:setTime(position)
	self.currentTime = timer:getTime()
	self.visualTimeInfo.time = self.constant and self.currentTime or self.nearestTime:getVisualTime(self.currentTime)

	audioEngine.forcePosition = true
	self.logicEngine:update()
	audioEngine.forcePosition = false
end

---@param timeRate number
function TimeEngine:setBaseTimeRate(timeRate)
	self.baseTimeRate = timeRate
	self:setTimeRate(timeRate)
end

---@param timeRate any
function TimeEngine:setTimeRate(timeRate)
	self.timeRate = timeRate
	self.timer:setRate(timeRate)
	self.visualTimeInfo.rate = timeRate
end

function TimeEngine:pause()
	self.timer:pause()
end

function TimeEngine:play()
	self.timer:play()
end

return TimeEngine
