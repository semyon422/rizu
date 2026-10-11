local ReplayBase = require("rizu.gameplay.ReplayBase")

---@class rizu.gameplay.catch.ReplayBase : rizu.gameplay.ReplayBase
---@operator call: rizu.gameplay.catch.ReplayBase
local CatchReplayBase = ReplayBase + {}

CatchReplayBase.mode = "catch"
CatchReplayBase.formats = {"rizu-catch-1"}
CatchReplayBase.directory = "catch"
CatchReplayBase.max_event_id = 6

return CatchReplayBase
