local class = require("class")
local flux = require("flux")
local Settings = require("rizu.config.Settings")

---@class sphere.PauseModel
---@field state string
---@field progress number
---@operator call: sphere.PauseModel
local PauseModel = class()

---@param settings rizu.config.Config
---@param rhythm_engine rizu.RhythmEngine
function PauseModel:new(settings, rhythm_engine)
	self.settings = settings
	self.rhythm_engine = rhythm_engine
end

---@param rhythm_engine rizu.RhythmEngine
function PauseModel:setRhythmEngine(rhythm_engine)
	self.rhythm_engine = rhythm_engine
end

function PauseModel:load()
	self:startProgress()
	self.state = "play"
	self.progress = 0
	self.needRetry = false
end

---@param state string
---@return number?
function PauseModel:getProgressTime(state)
	local keys = Settings.keys.gameplay
	if state == "play-pause" then return self.settings:getNumber(keys.time_play_pause) end
	if state == "pause-play" then return self.settings:getNumber(keys.time_pause_play) end
	if state == "play-retry" then return self.settings:getNumber(keys.time_play_retry) end
	if state == "pause-retry" then return self.settings:getNumber(keys.time_pause_retry) end
end

function PauseModel:update()
	self:updateState()

	if self.progress == 1 then
		self.progress = 0
	end
end

function PauseModel:updateState()
	local state = self.state
	local progress = self.progress

	if state == "play-pause" then
		if progress == 1 then
			self:pause()
		end
	elseif state == "pause-play" then
		if progress == 1 then
			self:play()
		end
	elseif state:find("retry") then
		if progress == 1 then
			self:retry()
		end
	end
end

---@param newState string
function PauseModel:changePlayState(newState)
	local state = self.state
	local progressState = state .. "-" .. newState
	local time
	if not self:getProgressTime(state) and self:getProgressTime(progressState) then
		state = progressState
		time = self:getProgressTime(progressState)
	elseif self:getProgressTime(state) and state:sub(1, #newState) == newState then
		state = newState
	end
	self.state = state
	self:startProgress(time)
end

---@param time number?
function PauseModel:startProgress(time)
	self.progress = 0
	if self.tween then
		self.tween:stop()
	end
	if not time then
		return
	elseif time == 0 then
		self.progress = 1
		self:updateState()
		return
	end
	self.tween = flux.to(self, time, {progress = 1}):ease("linear")
end

function PauseModel:play()
	self.rhythm_engine:play()
	self.state = "play"
	love.mouse.setVisible(false)
end

function PauseModel:pause()
	self.rhythm_engine:pause()
	self.state = "pause"
	love.mouse.setVisible(true)
end

function PauseModel:retry()
	self.needRetry = true
	self.state = "play"
end

return PauseModel
