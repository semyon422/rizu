local valid = require("valid")
local table_util = require("table_util")
local ReplayBase = require("sea.replays.ReplayBase")
local ChartmetaKey = require("sea.chart.ChartmetaKey")
local ReplayFrames = require("rizu.engine.replay.ReplayFrames")
local types = require("sea.shared.types")

---@class sea.Replay: sea.ChartmetaKey, sea.ReplayBase
---@operator call: sea.Replay
---@field version integer
---@field frames rizu.ReplayFrame[]
---@field pause_count integer
---@field created_at integer
local Replay = ChartmetaKey + ReplayBase

Replay.struct = {
	version = types.integer,
	frames = valid.array(valid.struct(ReplayFrames.frame_struct), 2e6),
	pause_count = types.count,
	created_at = types.time,
}
table_util.copy(ChartmetaKey.struct, Replay.struct)
table_util.copy(ReplayBase.struct, Replay.struct)

assert(#table_util.keys(Replay.struct) == 19)

local validate_replay = valid.struct(Replay.struct)

---@return true?
---@return string|valid.Errors?
function Replay:validate()
	return validate_replay(self)
end

return Replay
