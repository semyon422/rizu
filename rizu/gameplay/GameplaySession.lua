local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local class = require("class")
local AutoplayPlayer = require("rizu.engine.autoplay.AutoplayPlayer")
local ReplayRecorder = require("rizu.engine.replay.ReplayRecorder")
local ReplayPlayer = require("rizu.engine.replay.ReplayPlayer")

---@class rizu.GameplaySession
---@operator call: rizu.GameplaySession
local GameplaySession = class()

GameplaySession.play_type = "manual"

---@param rhythm_engine rizu.RhythmEngine
function GameplaySession:new(rhythm_engine)
	self.rhythm_engine = assert(rhythm_engine)
	self.autoplay_player = AutoplayPlayer()
	self.replay_recorder = ReplayRecorder()
	self.replay_player = nil
	self.play_type = GameplaySession.play_type
end

---@param play_type "manual"|"auto"|"replay"
function GameplaySession:setPlayType(play_type)
	self.play_type = play_type
	local frames = play_type == "auto" and self.rhythm_engine:getAutoplayFrames()
	if frames then
		self.replay_player = ReplayPlayer(frames)
	end
end

---@param frames rizu.ReplayFrame[]
function GameplaySession:setReplayFrames(frames)
	self.replay_player = ReplayPlayer(frames)
end

---@param current_time number
function GameplaySession:update(current_time)
	local re = self.rhythm_engine

	re:setGlobalTime(current_time)

	local next_time = re:getTime(true)

	if self.replay_player and self.play_type ~= "manual" then
		self.replay_player:update(re, next_time)
	elseif self.play_type == "auto" then
		self.autoplay_player:update(re, next_time)
	end

	re:update()
end

---@param pending_resync boolean?
function GameplaySession:play(pending_resync)
	self.rhythm_engine:play(pending_resync)
end

function GameplaySession:pause()
	local re = self.rhythm_engine
	re:pause()
	local event = self.play_type == "manual" and re:getPauseEvent()
	if event then
		re:receive(event)
		self.replay_recorder:record(re:getTime(), event)
	end
end

---@return boolean
function GameplaySession:isPaused()
	return self.rhythm_engine:isPaused()
end

---@return boolean
function GameplaySession:hasResult()
	return
		self.play_type == "manual" and
		self.rhythm_engine:hasResult()
end

function GameplaySession:skipIntro()
	self.rhythm_engine:skipIntro()
end

---@param event rizu.VirtualInputEvent
---@param current_time number
function GameplaySession:receive(event, current_time)
	if self.play_type ~= "manual" then
		return
	end

	local re = self.rhythm_engine
	re:setGlobalTime(current_time)
	re:receive(event)
	-- Only rules replay formats use column 2 for paused state updates.
	if re.rules and self:isPaused() then
		event = VirtualInputEvent(event.id, event.value, 2, event.pos)
	end
	self.replay_recorder:record(re:getTime(), event)
end

return GameplaySession
