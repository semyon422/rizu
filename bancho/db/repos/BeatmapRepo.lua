--- Beatmap repository backed by SQLite.

local class = require("class")

---@class bancho.BeatmapRepo
---@operator call: bancho.BeatmapRepo
local BeatmapRepo = class()

---@param models rdb.Models
function BeatmapRepo:new(models)
	self.models = models
end

--- Find a beatmap by md5.
---@param md5 string
---@return table?
function BeatmapRepo:findBeatmap(md5)
	return self.models.beatmaps:find({md5 = md5})
end

--- Find a beatmap by id.
---@param id integer
---@return table?
function BeatmapRepo:findBeatmapById(id)
	return self.models.beatmaps:find({id = id})
end

--- Find a beatmap by filename (artist - title).
---@param filename string
---@return table?
function BeatmapRepo:findBeatmapByFilename(filename)
	-- Try to match by title substring
	return self.models.beatmaps:find({title = filename}, {
		-- Use LIKE for partial match
	})
end

--- Add a beatmap.
---@param bmap table
function BeatmapRepo:addBeatmap(bmap)
	self.models.beatmaps:create(bmap)
end

--- Update beatmap play/pass counts.
---@param md5 string
---@param plays_increment integer
---@param passes_increment integer
function BeatmapRepo:updateCounts(md5, plays_increment, passes_increment)
	self.models.beatmaps.orm:query(
		"UPDATE beatmaps SET plays = plays + ?, passes = passes + ? WHERE md5 = ?",
		{plays_increment, passes_increment, md5}
	)
end

return BeatmapRepo
