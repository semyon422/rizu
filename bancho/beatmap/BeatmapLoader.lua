--- Beatmap loader: parses .osu files from local storage and populates the beatmap DB.
---
--- Falls back to the official osu! API v1 when the local file is missing.
--- Computes star rating for osu!mania from parsed notes; other modes default to 0.

local class = require("class")
local RawOsu = require("chart.format.osu.RawOsu")
local RankedStatus = require("bancho.constants.RankedStatus")

local CHARTS_DIR = "storages/charts"

---@class bancho.beatmap.BeatmapLoader
---@operator call: bancho.beatmap.BeatmapLoader
---@field fs fs.IFilesystem
---@field api_key string?
local BeatmapLoader = class()

---@param fs fs.IFilesystem
---@param api_key string?
function BeatmapLoader:new(fs, api_key)
	self.fs = fs
	self.api_key = api_key
end

--- Load a beatmap from local .osu file or API fallback.
--- Returns a table compatible with beatmap_repo:addBeatmap().
---@param md5 string beatmap file MD5
---@return table? beatmap metadata table, string? error
function BeatmapLoader:load(md5)
	-- Try local file first
	local path = CHARTS_DIR .. "/" .. md5
	local content = self:readFile(path)

	if content then
		return self:parseOsu(content, md5)
	end

	-- Fallback: fetch from osu.direct API
	return self:fetchFromApi(md5)
end

--- Read a file from disk.
---@param path string
---@return string? content, string? error
function BeatmapLoader:readFile(path)
	local content, err = self.fs:read(path)
	if not content then
		return nil, err or "file not found: " .. path
	end

	if #content == 0 then
		return nil, "empty file: " .. path
	end

	return content
end

--- Parse an .osu file string into beatmap metadata.
---@param content string raw .osu file content
---@param md5 string beatmap MD5
---@return table? metadata, string? error
function BeatmapLoader:parseOsu(content, md5)
	local rawOsu = RawOsu()
	rawOsu:decode(content)

	local general = rawOsu.General
	local metadata = rawOsu.Metadata
	local difficulty = rawOsu.Difficulty
	local timingPoints = rawOsu.TimingPoints
	local hitObjects = rawOsu.HitObjects

	-- Extract basic metadata
	local mode = tonumber(general.Mode) or 0
	local id = tonumber(metadata.BeatmapID) or 0
	local set_id = tonumber(metadata.BeatmapSetID) or 0

	if id == 0 then
		return nil, "missing BeatmapID in .osu file"
	end

	-- Extract difficulty values
	local cs = tonumber(difficulty.CircleSize) or 0
	local od = tonumber(difficulty.OverallDifficulty) or 0
	local ar = tonumber(difficulty.ApproachRate) or 0
	local hp = tonumber(difficulty.HPDrainRate) or 0

	-- Calculate BPM from timing points
	local bpm = self:calculateBpm(timingPoints)

	-- Calculate total length from hit objects
	local total_length = self:calculateTotalLength(hitObjects)

	-- Calculate max combo
	local max_combo = self:calculateMaxCombo(hitObjects)

	-- Count notes (for mania SR calculation)
	local notes_count = #hitObjects

	-- Compute star rating for mania
	local diff = 0
	if mode == 3 and notes_count > 0 then
		-- cs for mania is number of keys (round to nearest integer)
		local keymode = math.floor(cs + 0.5)
		if keymode > 0 then
			-- Wrap in pcall because starrate can crash on malformed data
			local ok, sr = pcall(self.calculateManiaSr, self, hitObjects, keymode, timingPoints)
			if ok and type(sr) == "number" then
				diff = sr
			end
		end
	end

	return {
		id = id,
		set_id = set_id,
		md5 = md5,
		artist = metadata.Artist or "",
		title = metadata.Title or "",
		version = metadata.Version or "",
		creator = metadata.Creator or "",
		total_length = total_length,
		max_combo = max_combo,
		status = RankedStatus.PENDING,
		mode = mode,
		bpm = bpm,
		cs = cs,
		od = od,
		ar = ar,
		hp = hp,
		diff = diff,
	}
end

--- Calculate average BPM from timing points.
---@param timingPoints chart.osu.TimingPoints
---@return number bpm
function BeatmapLoader:calculateBpm(timingPoints)
	if #timingPoints == 0 then
		return 120 -- default
	end

	-- Use the first timing point with a valid beat length
	for _, p in ipairs(timingPoints) do
		if p.timingChange and p.beatLength > 0 then
			return 60000 / p.beatLength
		end
	end

	return 120
end

--- Calculate total chart length from hit objects.
---@param hitObjects chart.osu.HitObjects
---@return number milliseconds
function BeatmapLoader:calculateTotalLength(hitObjects)
	if #hitObjects == 0 then
		return 0
	end

	local max_time = 0
	for _, obj in ipairs(hitObjects) do
		local end_time = obj.endTime or obj.time
		if end_time and end_time > max_time then
			max_time = end_time
		end
	end

	return max_time
end

--- Calculate max combo from hit objects.
---@param hitObjects chart.osu.HitObjects
---@return number
function BeatmapLoader:calculateMaxCombo(hitObjects)
	-- For mania: count all hit objects (each note = 1 combo)
	-- For other modes: approximate from hit object count
	return #hitObjects
end

--- Calculate star rating for osu!mania using the strain-based formula.
---@param hitObjects chart.osu.HitObjects
---@param keymode number number of keys (CircleSize for mania)
---@param timingPoints chart.osu.TimingPoints
---@return number star_rating
function BeatmapLoader:calculateManiaSr(hitObjects, keymode, timingPoints)
	-- Import the starrate calculator
	local starrate = require("chart.scoring.osu_starrate")

	-- Get time rate from timing points
	local time_rate = 1.0
	if #timingPoints > 0 then
		for _, p in ipairs(timingPoints) do
			if p.timingChange and p.beatLength > 0 then
				time_rate = 60000 / p.beatLength
				break
			end
		end
	end

	-- Convert hit objects to notes for starrate calculator
	local notes = {}
	for _, obj in ipairs(hitObjects) do
		-- Determine column from x position (mania uses keymode keys)
		local column = 1
		if obj.x then
			column = math.max(1, math.min(keymode, math.floor(obj.x / 512 * keymode + 1)))
		end

		table.insert(notes, {
			time = obj.time,
			end_time = obj.endTime,
			column = column,
		})
	end

	if #notes == 0 then
		return 0
	end

	-- Calculate SR
	local beatmap = starrate.Beatmap(notes, keymode, time_rate)
	return beatmap:calculateStarRate()
end

--- Fetch beatmap metadata from the official osu! API v1.
---@param md5 string beatmap MD5
---@return table? metadata, string? error
function BeatmapLoader:fetchFromApi(md5)
	if not self.api_key then
		return nil, "osu_api_key not configured"
	end

	local http_util = require("web.http.util")

	local url = "https://old.ppy.sh/api/get_beatmaps?h=" .. md5 .. "&k=" .. self.api_key

	-- Wrap in pcall because HTTP may not be available in all environments
	local ok, result, err = pcall(function()
		return http_util.request(url)
	end)

	if not ok then
		return nil, err or "API request failed"
	end

	if not result then
		return nil, err or "API request failed"
	end

	if result.status ~= 200 then
		return nil, "API returned status " .. tostring(result.status)
	end

	-- Parse JSON response
	local json = require("json")
	local data = json.decode(result.body)

	if not data or #data == 0 then
		return nil, "no beatmap data from API"
	end

	local api = data[1]

	return {
		id = tonumber(api.beatmap_id) or 0,
		set_id = tonumber(api.beatmapset_id) or 0,
		md5 = md5,
		artist = api.artist or "",
		title = api.title or "",
		version = api.version or "",
		creator = api.creator or "",
		total_length = tonumber(api.total_length) or 0,
		max_combo = tonumber(api.max_combo) or 0,
		status = RankedStatus.fromOsuApi(tonumber(api.approved) or 0),
		mode = tonumber(api.mode) or 0,
		bpm = tonumber(api.bpm) or 0,
		cs = tonumber(api.diff_size) or 0,
		od = tonumber(api.diff_overall) or 0,
		ar = tonumber(api.diff_approach) or 0,
		hp = tonumber(api.diff_drain) or 0,
		diff = tonumber(api.difficultyrating) or 0,
	}
end

return BeatmapLoader
