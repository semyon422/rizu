local class = require("class")
local valid = require("valid")
local Chartplay = require("sea.chart.Chartplay")
local Chartdiff = require("sea.chart.Chartdiff")
local FakeComputeDataProvider = require("sea.compute.FakeComputeDataProvider")
local OsuReplayConverter = require("sea.replays.OsuReplayConverter")
local Grade = require("bancho.constants.Grade")
local SubmissionStatus = require("bancho.constants.SubmissionStatus")

---@class bancho.adapter.SeaScoreRepo
---@operator call: bancho.adapter.SeaScoreRepo
---@field users_repo sea.UsersRepo
---@field charts_repo sea.ChartsRepo
---@field chartplay_submission sea.ChartplaySubmission
---@field charts_storage sea.IKeyValueStorage
---@field beatmap_repo? bancho.adapter.SeaBeatmapRepo
local SeaScoreRepo = class()

---@param users_repo sea.UsersRepo
---@param charts_repo sea.ChartsRepo
---@param chartplay_submission sea.ChartplaySubmission
---@param charts_storage sea.IKeyValueStorage
---@param beatmap_repo? bancho.adapter.SeaBeatmapRepo
function SeaScoreRepo:new(users_repo, charts_repo, chartplay_submission, charts_storage, beatmap_repo)
	self.users_repo = users_repo
	self.charts_repo = charts_repo
	self.chartplay_submission = chartplay_submission
	self.charts_storage = charts_storage
	self.beatmap_repo = beatmap_repo
	self.osu_replay_converter = OsuReplayConverter()
end

---@param chartplay sea.Chartplay
---@param chartmeta? sea.Chartmeta
---@return table
function SeaScoreRepo:chartplayToScore(chartplay, chartmeta)
	local converter = self.osu_replay_converter
	local n300, n100, n50, ngeki, nkatu, nmiss = converter:getHitCounts(chartplay.judges or {})
	local accuracy = (chartplay.accuracy or 0) * 100
	local grade = Grade.fromString(chartplay:getGrade():lower())
	local score_value = converter:getScoreValue(chartplay)
	return {
		id = chartplay.id,
		chartplay_id = chartplay.id,
		map_md5 = chartplay.hash,
		score = score_value,
		pp = chartplay.rating_pp,
		acc = accuracy,
		accuracy = accuracy,
		max_combo = chartplay.max_combo,
		mods = converter:getModsFromReplay(chartplay, chartmeta and chartmeta.inputmode or chartplay.chartmeta_inputmode or chartplay.inputmode),
		n300 = n300,
		n100 = n100,
		n50 = n50,
		nmiss = nmiss,
		ngeki = ngeki,
		nkatu = nkatu,
		grade = grade.value,
		status = SubmissionStatus.BEST,
		mode = 3,
		play_time = chartplay.submitted_at,
		time_elapsed = 0,
		client_flags = 0,
		user_id = chartplay.user_id,
		userid = chartplay.user_id,
		perfect = chartplay.not_perfect_count == 0,
		online_checksum = "",
		beatmap_status = 2,
		replay_hash = chartplay.replay_hash,
		created_at = chartplay.submitted_at,
	}
end

---@param rows table[]
---@return table[]
function SeaScoreRepo:sortScores(rows)
	table.sort(rows, function(a, b)
		if (a.pp or 0) == (b.pp or 0) then
			return (a.score or 0) > (b.score or 0)
		end
		return (a.pp or 0) > (b.pp or 0)
	end)
	return rows
end

---@param map_md5 string
---@param mode integer
---@return table[]
function SeaScoreRepo:findScores(map_md5, mode)
	if mode % 4 ~= 3 then
		return {}
	end

	local rows = {}
	for _, chartplay in ipairs(self.charts_repo.models.chartplayviews:select({
		compute_state = "valid",
		hash = map_md5,
		index = 1,
		mode = "mania",
		pass = true,
	})) do
		rows[#rows + 1] = self:chartplayToScore(chartplay)
	end

	return self:sortScores(rows)
end

---@param map_md5 string
---@param user_id integer
---@param mode integer
---@return table?
function SeaScoreRepo:findBestScore(map_md5, user_id, mode)
	if mode % 4 ~= 3 then
		return nil
	end

	local best
	for _, chartplay in ipairs(self.charts_repo:getBestChartplaysForChartmeta({hash = map_md5, index = 1})) do
		if chartplay.user_id == user_id and chartplay.mode == "mania" and chartplay.pass then
			local row = self:chartplayToScore(chartplay)
			if not best or row.pp > best.pp or (row.pp == best.pp and row.score > best.score) then
				best = row
			end
		end
	end

	return best
end

---@param id integer
---@return table?
function SeaScoreRepo:findScore(id)
	local chartplay = self.charts_repo:getChartplay(id)
	if not chartplay or chartplay.mode ~= "mania" or not chartplay.pass then
		return nil
	end
	local chartmeta = self.charts_repo.models.chartmetas:find({hash = chartplay.hash, index = chartplay.index})
	return self:chartplayToScore(chartplay, chartmeta)
end

---@param user_id integer
---@param mode integer
---@return table[]
function SeaScoreRepo:findBestRankedScores(user_id, mode)
	if mode % 4 ~= 3 then
		return {}
	end

	local rows = {}
	for _, chartplay in ipairs(self.charts_repo.models.best_chartmeta_chartplays:select({
		user_id = user_id,
		mode = "mania",
		pass = true,
		compute_state = "valid",
	})) do
		rows[#rows + 1] = self:chartplayToScore(chartplay)
	end
	return self:sortScores(rows)
end

---@param map_md5 string
---@return string?
---@return string?
function SeaScoreRepo:ensureChartData(map_md5)
	local chart_data, err = self.charts_storage:get(map_md5)
	if chart_data then
		return chart_data
	end
	if self.beatmap_repo and self.beatmap_repo.ensureBeatmap then
		self.beatmap_repo:ensureBeatmap(map_md5)
		chart_data, err = self.charts_storage:get(map_md5)
		if chart_data then
			return chart_data
		end
	end
	return nil, err or "missing chart data"
end

---@param replay sea.Replay
---@param inputmode string
---@return sea.Chartdiff
local function create_chartdiff_values(replay, inputmode)
	local chartdiff = Chartdiff()
	chartdiff.hash = replay.hash
	chartdiff.index = replay.index
	chartdiff.modifiers = replay.modifiers
	chartdiff.rate = replay.rate
	chartdiff.mode = replay.mode
	chartdiff.inputmode = inputmode
	chartdiff.duration = 0
	chartdiff.start_time = 0
	chartdiff.notes_count = 0
	chartdiff.judges_count = 0
	chartdiff.note_types_count = {}
	chartdiff.density_data = {}
	chartdiff.sv_data = {}
	chartdiff.enps_diff = 0
	chartdiff.osu_diff = 0
	chartdiff.msd_diff = 0
	chartdiff.msd_diff_data = {
		overall = 0,
		stream = 0,
		jumpstream = 0,
		handstream = 0,
		stamina = 0,
		jackspeed = 0,
		chordjack = 0,
		technical = 0,
	}
	chartdiff.msd_diff_rates = {}
	chartdiff.user_diff = 0
	chartdiff.user_diff_data = ""
	chartdiff.notes_preview = ""
	return chartdiff
end

---@param replay sea.Replay
---@param replay_hash string
---@return sea.Chartplay
local function create_chartplay_values(replay, replay_hash)
	local chartplay = Chartplay()
	chartplay:importChartplayBase(replay)
	chartplay.judges = {}
	chartplay.accuracy = 0
	chartplay.max_combo = 0
	chartplay.miss_count = 0
	chartplay.not_perfect_count = 0
	chartplay.pass = false
	chartplay.rating = 0
	chartplay.rating_pp = 0
	chartplay.rating_msd = 0
	chartplay.hash = replay.hash
	chartplay.index = replay.index
	chartplay.replay_hash = replay_hash
	chartplay.pause_count = replay.pause_count
	chartplay.created_at = replay.created_at
	return chartplay
end

---@param score table
---@param beatmap table
---@param replay_data string
---@return integer?
---@return string?
function SeaScoreRepo:submitScore(score, beatmap, replay_data)
	local chart_data, err = self:ensureChartData(score.map_md5)
	if not chart_data then
		return nil, err
	end

	local key_count = beatmap.cs
	if type(key_count) ~= "number" or key_count <= 0 or key_count ~= math.floor(key_count) then
		return nil, "invalid mania key count"
	end
	local inputmode = tostring(key_count) .. "key"

	local replay, replay_file_data, replay_hash = self.osu_replay_converter:fromSubmissionReplay(
		replay_data,
		score.map_md5,
		1,
		beatmap.od or 0,
		inputmode,
		score.mods or 0,
		score.play_time or score.created_at or os.time()
	)
	if not replay then
		return nil, "convert replay: " .. tostring(replay_file_data)
	end

	local chartdiff_values = create_chartdiff_values(replay, inputmode)
	local chartplay_values = create_chartplay_values(replay, replay_hash)

	assert(valid.format(chartplay_values:validate()))
	assert(valid.format(chartdiff_values:validate()))

	local provider = FakeComputeDataProvider()
	provider:addChart(score.map_md5, (beatmap.id or 0) .. ".osu", chart_data)
	provider:addReplay(replay_hash, replay_file_data)

	local user = assert(self.users_repo:getUser(score.user_id))
	local peer = {
		user = user,
		remote = {
			compute_data_provider = provider,
			print = function() end,
			client = {setLeaderboardUsers = function() end},
		},
	}

	local chartplay, serr = self.chartplay_submission:submitChartplay(peer, chartplay_values, chartdiff_values)
	if not chartplay then
		return nil, "submit chartplay: " .. serr
	end

	return chartplay.id
end

return SeaScoreRepo
