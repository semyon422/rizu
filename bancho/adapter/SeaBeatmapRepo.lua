local class = require("class")
local http_util = require("web.http.util")
local ComputeContext = require("sea.compute.ComputeContext")
local ReplayBase = require("sea.replays.ReplayBase")
local RankedStatus = require("bancho.constants.RankedStatus")

---@class bancho.adapter.SeaBeatmapRepo
---@operator call: bancho.adapter.SeaBeatmapRepo
---@field charts_repo sea.ChartsRepo
---@field osu_repo sea.OsuRepo
---@field osu_beatmaps? sea.OsuBeatmaps
---@field charts_storage? sea.IKeyValueStorage
---@field fetch_osu_file? fun(self: bancho.adapter.SeaBeatmapRepo, beatmap_id: integer): string?, string?
local SeaBeatmapRepo = class()

---@param charts_repo sea.ChartsRepo
---@param osu_repo sea.OsuRepo
---@param osu_beatmaps? sea.OsuBeatmaps
---@param charts_storage? sea.IKeyValueStorage
---@param fetch_osu_file? fun(self: bancho.adapter.SeaBeatmapRepo, beatmap_id: integer): string?, string?
function SeaBeatmapRepo:new(charts_repo, osu_repo, osu_beatmaps, charts_storage, fetch_osu_file)
	self.charts_repo = charts_repo
	self.osu_repo = osu_repo
	self.osu_beatmaps = osu_beatmaps
	self.charts_storage = charts_storage
	self.fetch_osu_file = fetch_osu_file
end

---@param chartmeta sea.Chartmeta?
---@param osu_beatmap sea.OsuBeatmap?
---@return integer
function SeaBeatmapRepo:getRankedStatus(chartmeta, osu_beatmap)
	local status = osu_beatmap and osu_beatmap.status or nil
	if status == nil then
		return RankedStatus.UPDATE_AVAILABLE
	end
	if status == "ranked" then
		return RankedStatus.RANKED
	elseif status == "approved" then
		return RankedStatus.APPROVED
	elseif status == "qualified" then
		return RankedStatus.QUALIFIED
	elseif status == "loved" then
		return RankedStatus.LOVED
	elseif status == "pending" or status == "wip" or status == "graveyard" or status == "missing" then
		return RankedStatus.PENDING
	end
	return RankedStatus.fromOsuApi(status)
end

---@param beatmap_id integer
---@return string?, string?
function SeaBeatmapRepo:fetchOsuFile(beatmap_id)
	if self.fetch_osu_file then
		return self.fetch_osu_file(self, beatmap_id)
	end

	local res, err = http_util.request("https://osu.ppy.sh/osu/" .. beatmap_id)
	if not res then
		return nil, err
	elseif res.status ~= 200 then
		return nil, "status " .. tostring(res.status)
	end
	return res.body
end

---@param md5 string
---@return sea.OsuBeatmap?, sea.Chartmeta?
function SeaBeatmapRepo:ensureBeatmap(md5)
	local charts_repo = self.charts_repo
	local osu_beatmap = self.osu_repo:getBeatmapByHash(md5)
	if not osu_beatmap and self.osu_beatmaps then
		osu_beatmap = self.osu_beatmaps:getOrCreateOsuBeatmapByHash(md5, os.time())
	end
	if not osu_beatmap then
		return nil, nil
	end

	local chartmeta = charts_repo.models.chartmetas:find({hash = md5})
	local chartdiff = charts_repo:selectDefaultChartdiff(md5, 1)
	local content = self.charts_storage and self.charts_storage:get(md5) or nil
	if chartmeta and chartdiff and content then
		return osu_beatmap, chartmeta
	end
	if not osu_beatmap.id or not self.charts_storage then
		return osu_beatmap, chartmeta
	end

	if not content then
		content = self:fetchOsuFile(osu_beatmap.id)
		if not content then
			return osu_beatmap, chartmeta
		end
		self.charts_storage:set(md5, content)
	end

	local ctx = ComputeContext()
	local chart_chartmeta = ctx:fromFileData(osu_beatmap.id .. ".osu", content, 1)
	if not chart_chartmeta then
		return osu_beatmap, chartmeta
	end

	chartmeta = chart_chartmeta.chartmeta
	chartmeta.osu_beatmap_id = chartmeta.osu_beatmap_id or osu_beatmap.id
	chartmeta.osu_beatmapset_id = chartmeta.osu_beatmapset_id or osu_beatmap.beatmapset_id
	chartmeta = charts_repo:createUpdateChartmeta(chartmeta, os.time())

	local chartdiff_computed = ctx:computeBase(ReplayBase())
	charts_repo:createUpdateChartdiff(chartdiff_computed, os.time())

	return osu_beatmap, chartmeta
end

---@param chartmeta sea.Chartmeta?
---@param osu_beatmap sea.OsuBeatmap?
---@return table?
function SeaBeatmapRepo:toBanchoBeatmap(chartmeta, osu_beatmap)
	local id = chartmeta and chartmeta.osu_beatmap_id or osu_beatmap and osu_beatmap.id
	if not id then
		return nil
	end

	local md5 = chartmeta and chartmeta.hash or osu_beatmap and osu_beatmap.hash or ""
	local chartdiff = md5 ~= "" and self.charts_repo:selectDefaultChartdiff(md5, 1) or nil
	local artist = chartmeta and (chartmeta.artist_unicode or chartmeta.artist) or ""
	local title = chartmeta and (chartmeta.title_unicode or chartmeta.title) or ""
	local version = chartmeta and chartmeta.name or ""
	local creator = chartmeta and chartmeta.creator or ""

	return {
		id = id,
		set_id = chartmeta and chartmeta.osu_beatmapset_id or osu_beatmap and osu_beatmap.beatmapset_id or 0,
		md5 = md5,
		artist = artist,
		title = title,
		version = version,
		creator = creator,
		total_length = chartdiff and math.floor(chartdiff.duration) or 0,
		max_combo = chartdiff and chartdiff.notes_count or 0,
		status = self:getRankedStatus(chartmeta, osu_beatmap),
		mode = 3,
		bpm = chartmeta and chartmeta.tempo or 0,
		cs = 0,
		od = 0,
		ar = 0,
		hp = 0,
		diff = chartdiff and chartdiff.osu_diff or chartmeta and chartmeta.level or 0,
		plays = 0,
		passes = 0,
		last_update = osu_beatmap and osu_beatmap.updated_at or chartmeta and chartmeta.computed_at or 0,
		full_name = (artist ~= "" or title ~= "" or version ~= "") and ("%s - %s [%s]"):format(artist, title, version) or "",
	}
end

---@param md5 string
---@return table?
function SeaBeatmapRepo:findBeatmap(md5)
	local osu_beatmap, chartmeta = self:ensureBeatmap(md5)
	return self:toBanchoBeatmap(chartmeta, osu_beatmap)
end

---@param id integer
---@return table?
function SeaBeatmapRepo:findBeatmapById(id)
	local osu_beatmap = self.osu_repo:getBeatmap(id)
	if not osu_beatmap then
		return nil
	end
	local _, chartmeta = self:ensureBeatmap(osu_beatmap.hash)
	return self:toBanchoBeatmap(chartmeta, osu_beatmap)
end

return SeaBeatmapRepo
