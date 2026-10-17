local ReplayBase = require("rizu.gameplay.ReplayBase")

---@class rizu.gameplay.taiko.ReplayBase : rizu.gameplay.ReplayBase
---@operator call: rizu.gameplay.taiko.ReplayBase
local TaikoReplayBase = ReplayBase + {}

TaikoReplayBase.mode = "taiko"
TaikoReplayBase.formats = {"rizu-taiko-1"}
TaikoReplayBase.directory = "taiko"
TaikoReplayBase.max_event_id = 4

return TaikoReplayBase
