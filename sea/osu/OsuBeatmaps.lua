local class = require("class")
local OsuBeatmap = require("sea.osu.OsuBeatmap")

---@class sea.OsuBeatmaps
---@operator call: sea.OsuBeatmaps
local OsuBeatmaps = class()

---@param api sea.OsuApi
---@param osu_repo sea.OsuRepo
function OsuBeatmaps:new(api, osu_repo)
	self.api = api
	self.osu_repo = osu_repo
end

function OsuBeatmaps:sync()
	local api = self.api

	local res, err = api:beatmapsets_search({
		r = "ranked",
	})

	if not res then
		return nil, err
	end

	print(require("stbl").encode(res))
end

---@param hash string
---@param time integer
---@return sea.OsuBeatmap?
---@return string?
function OsuBeatmaps:getOrCreateOsuBeatmapByHash(hash, time)
	local api = self.api
	local repo = self.osu_repo

	local osu_beatmap = repo:getBeatmapByHash(hash)
	if osu_beatmap then
		return osu_beatmap
	end

	local beatmap, err = api:beatmaps_lookup({
		checksum = hash,
	})

	if not beatmap then
		return nil, "beatmaps lookup: " .. err
	end

	osu_beatmap = OsuBeatmap()
	osu_beatmap.id = beatmap.id
	osu_beatmap.beatmapset_id = beatmap.beatmapset_id
	osu_beatmap.hash = beatmap.checksum or hash
	osu_beatmap.status = beatmap.status or "missing"
	osu_beatmap.updated_at = time

	osu_beatmap = repo:createBeatmap(osu_beatmap)

	return osu_beatmap
end

return OsuBeatmaps
