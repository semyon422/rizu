local class = require("class")
local valid = require("valid")
local ReplayCoder = require("sea.replays.ReplayCoder")
local ReplayConverter = require("sea.replays.ReplayConverter")

---@class sea.ReplayLoader
---@operator call: sea.ReplayLoader
local ReplayLoader = class()

---@param replay_data string
---@return sea.Replay?
---@return string?
function ReplayLoader.load(replay_data)
	local replay, err = ReplayCoder.decode(replay_data)
	if not replay then
		return nil, "can't decode replay: " .. err
	end

	replay = ReplayConverter:convert(replay)

	local ok, err = valid.format(replay:validate())
	if not ok then
		return nil, "invalid replay: " .. err
	end

	return replay
end

return ReplayLoader
