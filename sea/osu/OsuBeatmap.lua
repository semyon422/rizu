local class = require("class")

---@class sea.OsuBeatmap
---@operator call: sea.OsuBeatmap
---@field id integer?
---@field beatmapset_id integer?
---@field status sea.BeatmapStatus
---@field hash string
---@field updated_at integer
local OsuBeatmap = class()

return OsuBeatmap
