local class = require("class")

---@class sea.OsuRepo
---@operator call: sea.OsuRepo
local OsuRepo = class()

---@param models rdb.Models
function OsuRepo:new(models)
	self.models = models
end

---@return sea.OsuBeatmapset[]
function OsuRepo:getBeatmapsets()
	return self.models.osu_beatmapsets:select()
end

---@param id integer
---@return sea.OsuBeatmapset?
function OsuRepo:getBeatmapset(id)
	return self.models.osu_beatmapsets:find({id = assert(id)})
end

---@param beatmapset sea.OsuBeatmapset
---@return sea.OsuBeatmapset
function OsuRepo:createBeatmapset(beatmapset)
	assert(beatmapset.id)
	return self.models.osu_beatmapsets:create(beatmapset)
end

---@param beatmapset sea.OsuBeatmapset
---@return sea.OsuBeatmapset
function OsuRepo:updateBeatmapset(beatmapset)
	return self.models.osu_beatmapsets:update(beatmapset, {id = assert(beatmapset.id)})[1]
end

---@param id integer
---@return sea.OsuBeatmapset?
function OsuRepo:deleteBeatmapset(id)
	return self.models.osu_beatmapsets:delete({id = assert(id)})[1]
end

--------------------------------------------------------------------------------

---@return sea.OsuBeatmap[]
function OsuRepo:getBeatmaps()
	return self.models.osu_beatmaps:select()
end

---@param id integer
---@return sea.OsuBeatmap?
function OsuRepo:getBeatmap(id)
	return self.models.osu_beatmaps:find({id = assert(id)})
end

---@param hash string
---@return sea.OsuBeatmap?
function OsuRepo:getBeatmapByHash(hash)
	return self.models.osu_beatmaps:find({hash = assert(hash)})
end

---@param beatmap sea.OsuBeatmap
---@return sea.OsuBeatmap
function OsuRepo:createBeatmap(beatmap)
	return self.models.osu_beatmaps:create(beatmap)
end

---@param beatmap sea.OsuBeatmap
---@return sea.OsuBeatmap
function OsuRepo:updateBeatmap(beatmap)
	return self.models.osu_beatmaps:update(beatmap, {id = assert(beatmap.id)})[1]
end

---@param id integer
---@return sea.OsuBeatmap?
function OsuRepo:deleteBeatmap(id)
	return self.models.osu_beatmaps:delete({id = assert(id)})[1]
end

return OsuRepo
