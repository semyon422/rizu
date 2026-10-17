local json = require("json")
local table_util = require("table_util")
local mime = require("mime")
local Replay = require("sea.replays.Replay")
local ReplayEvents = require("sea.replays.ReplayEvents")
local ReplayFrames = require("rizu.engine.replay.ReplayFrames")

---@class sea.ReplayCoder
local ReplayCoder = {}

---@param s string
---@return sea.Replay?
---@return string?
function ReplayCoder.decode(s)
	---@type boolean, table
	local ok, obj = pcall(json.decode, s)
	if not ok then
		return nil, "invalid json: " .. obj
	end

	local replay = setmetatable(obj, Replay)

	local events = mime.unb64(obj.events) -- v1
	local frames = mime.unb64(obj.frames) -- v2

	if not events and not frames then
		return nil, "can't unb64"
	end

	if events then
		replay.events = ReplayEvents.decode(events)
	elseif frames then
		replay.frames = ReplayFrames.decode(frames)
	end

	return obj
end

---@param replay sea.Replay
---@return string?
---@return string?
function ReplayCoder.encode(replay)
	local obj = table_util.copy(replay)
	---@cast obj -sea.Replay
	---@cast replay +{events: {}}

	if replay.events then -- v1
		obj.events = mime.b64(ReplayEvents.encode(replay.events))
	elseif replay.frames then -- v2
		obj.frames = mime.b64(ReplayFrames.encode(replay.frames))
	end

	---@type boolean, string
	local ok, str = pcall(json.encode, obj)
	if not ok then
		return nil, str
	end

	return str
end

return ReplayCoder
