--- Score submission processing.
---
--- Handles parsing the MODULAR selector submission, validating checksums,
--- calculating PP, and determining submission status (new best / submitted / failed).
--- Returns the chart response string for the osu! client.

local class = require("class")
local Score = require("bancho.model.Score")
local SubmissionStatus = require("bancho.constants.SubmissionStatus")
local RankedStatus = require("bancho.constants.RankedStatus")
local Grade = require("bancho.constants.Grade")
local Chart = require("bancho.score.Chart")

---@param s string?
---@return string
local function normalize_submission_username(s)
	s = s or ""
	if s:sub(-1) == " " then
		return s:sub(1, -2)
	end
	return s
end

---@class bancho.score.ScoreSubmitter
---@operator call: bancho.score.ScoreSubmitter
---@field server bancho.server.BanchoServer
local ScoreSubmitter = class()

---@param server bancho.server.BanchoServer
function ScoreSubmitter:new(server)
	self.server = server
	return self
end

--- Submit a score from the client.
--- Parses the score data, validates checksums, calculates PP, persists the score,
--- and returns the chart response string for the osu! client.
---@param player bancho.model.Player
---@param parts string[] parsed score data: [1]=map_md5, [2]=username, [3..]=score fields
---@param replay_data string replay file data
---@param fields table form fields from submission
---@return string|nil chart_response pipe-delimited chart string (nil on failure)
function ScoreSubmitter:submit(player, parts, replay_data, fields)
	-- Minimum fields check: map_md5, username, online_checksum, n300, n100, n50, ngeki, nkatu, nmiss, score, max_combo, perfect, grade, mods, passed, mode, play_time
	if #parts < 16 then
		return
	end

	-- Extract map MD5 and username
	local map_md5 = parts[1]
	local username = normalize_submission_username(parts[2])

	-- Parse score from submission data (skip map_md5 and username)
	local score = Score:new()
	score:fromSubmission({
		parts[3], parts[4], parts[5], parts[6], parts[7], parts[8],
		parts[9], parts[10], parts[11], parts[12], parts[13], parts[14],
		parts[15], parts[16], parts[17], parts[18]
	})

	-- Look up beatmap: DB → local .osu file → osu.direct API
	local bmap = nil
	if self.server.beatmap_repo then
		bmap = self.server.beatmap_repo:findBeatmap(map_md5)
	end

	-- If not in DB, try loading from local storage or API
	if not bmap and self.server.beatmap_loader then
		bmap = self.server.beatmap_loader:load(map_md5)
		if bmap and self.server.beatmap_repo then
			-- Cache in DB for future lookups
			self.server.beatmap_repo:addBeatmap(bmap)
		end
	end

	if not bmap then
		return
	end

	-- Calculate accuracy
	score:calculateAccuracy()

	-- Calculate PP
	score:calculatePP(bmap)

	-- Validate online checksum
	local osu_version = fields.osuver or ""
	local client_hash = fields.client_hash or ""
	local storyboard_md5 = fields.sbk or ""

	local server_checksum = score:computeOnlineChecksum(username, map_md5, osu_version, client_hash, storyboard_md5)
	if score.client_checksum ~= server_checksum then
		return
	end

	-- Check if map has leaderboard
	local has_leaderboard = self:mapHasLeaderboard(bmap.status or 0)
	if not has_leaderboard then
		return
	end

	-- Check for existing best score
	local existing_best = nil
	if self.server.score_repo then
		existing_best = self.server.score_repo:findBestScore(map_md5, player.id, score.mode)
	end

	-- Determine submission status
	score.status = self:calculateStatus(
		score.pp or 0,
		score.score or 0,
		existing_best and existing_best.pp or 0,
		existing_best and existing_best.score or 0
	)

	-- If not passed, set status to failed
	if not score.passed then
		score.status = SubmissionStatus.FAILED
	end

	-- Set server time
	score.server_time = os.time()

	-- Save score to database
	local score_id = 0
	if self.server.score_repo then
		local score_values = {
			map_md5 = map_md5,
			score = score.score,
			pp = score.pp or 0,
			acc = score.accuracy,
			max_combo = score.max_combo,
			mods = score.mods,
			n300 = score.n300,
			n100 = score.n100,
			n50 = score.n50,
			nmiss = score.nmiss,
			ngeki = score.ngeki,
			nkatu = score.nkatu,
			grade = score.grade.value,
			status = score.status,
			mode = score.mode,
			play_time = score.server_time,
			time_elapsed = tonumber(fields.st) or 0,
			client_flags = 0,
			user_id = player.id,
			perfect = score.perfect,
			online_checksum = score.client_checksum,
			created_at = score.server_time,
		}
		if self.server.score_repo.submitScore and score.passed and replay_data then
			local err
			score_id, err = self.server.score_repo:submitScore(score_values, bmap, replay_data)
			if not score_id then
				return nil
			end
		else
			score_id = self.server.score_repo:addScore(score_values)
			if score.passed and replay_data and score_id > 0 and self.server.replay_repo then
				self.server.replay_repo:saveReplay(score_id, replay_data)
			end
		end
	end

	-- Update player stats (always use vanilla mode 0-3)
	local prev_stats = nil
	local current_stats = nil
	local vanilla_mode = score.mode % 4
	if self.server.stats_repo then
		-- Capture stats before update for chart comparison
		prev_stats = self.server.stats_repo:getStats(player.id, vanilla_mode)

		local stats_update = {}

		-- Stats updated for all submitted scores
		stats_update.plays = (prev_stats and prev_stats.plays or 0) + 1
		stats_update.playtime = (prev_stats and prev_stats.playtime or 0) + (tonumber(fields.st) or 0) / 1000
		stats_update.tscore = (prev_stats and prev_stats.tscore or 0) + score.score
		local total_hits = score.n300 + score.n100 + score.n50
		if vanilla_mode == 1 or vanilla_mode == 3 then
			-- taiko and mania use geki & katu for total hits
			total_hits = total_hits + score.ngeki + score.nkatu
		end
		stats_update.total_hits = (prev_stats and prev_stats.total_hits or 0) + total_hits

		-- Update max combo if needed (only when passed and has leaderboard)
		if score.passed and has_leaderboard then
			if score.max_combo > (prev_stats and prev_stats.max_combo or 0) then
				stats_update.max_combo = score.max_combo
			end
		end

		-- Update ranked stats only when:
		-- 1. Score is passed
		-- 2. Map has leaderboard (ranked, approved, or loved)
		-- 3. Map awards ranked PP (ranked or approved only)
		-- 4. This is a new best score
		if score.passed and has_leaderboard and self:mapAwardsRankedPP(bmap.status or 0) and score.status == SubmissionStatus.BEST then
			-- Update ranked score
			local additional_rscore = score.score
			if existing_best then
				additional_rscore = additional_rscore - (existing_best.score or 0)
			end
			stats_update.rscore = (prev_stats and prev_stats.rscore or 0) + additional_rscore

			-- Update grade counts
			if score.grade.value >= Grade.A.value then
				local grade_col = score.grade.stats_column
				stats_update[grade_col] = (prev_stats and prev_stats[grade_col] or 0) + 1
			end
			if existing_best and existing_best.grade ~= nil and existing_best.grade >= Grade.A.value then
				local prev_grade = Grade.fromValue(existing_best.grade)
				if prev_grade and prev_grade.stats_column then
					local prev_grade_col = prev_grade.stats_column
					stats_update[prev_grade_col] = (prev_stats and prev_stats[prev_grade_col] or 0) - 1
				end
			end

			-- Calculate weighted PP and accuracy from all best ranked scores
			if self.server.score_repo then
				local best_scores = self.server.score_repo:findBestRankedScores(player.id, vanilla_mode)
				if #best_scores > 0 then
					-- Weighted accuracy: sum(acc * 0.95^i) with bonus
					local weighted_acc = 0
					for i, row in ipairs(best_scores) do
						weighted_acc = weighted_acc + (row.acc or 0) * (0.95 ^ (i - 1))
					end
					local bonus_acc = 100.0 / (20 * (1 - 0.95 ^ #best_scores))
					stats_update.acc = (weighted_acc * bonus_acc) / 100

					-- Weighted PP: sum(pp * 0.95^i) + bonus
					local weighted_pp = 0
					for i, row in ipairs(best_scores) do
						weighted_pp = weighted_pp + (row.pp or 0) * (0.95 ^ (i - 1))
					end
					local bonus_pp = 416.6667 * (1 - 0.9994 ^ #best_scores)
					stats_update.pp = math.floor(weighted_pp + bonus_pp)
				end
			end

			-- Calculate global rank
			if stats_update.pp then
				stats_update.rank = self.server.stats_repo:getGlobalRank(player.id, vanilla_mode, stats_update.pp)
			end
		end

		self.server.stats_repo:updateStats(player.id, vanilla_mode, stats_update)

		-- Get updated stats for chart
		current_stats = self.server.stats_repo:getStats(player.id, vanilla_mode)
	end

	-- If it's a new best and map awards ranked PP, send notification
	if score.status == SubmissionStatus.BEST and self:mapAwardsRankedPP(bmap.status or 0) then
		-- TODO: send notification to player
	end

	-- Generate chart response
	if score.passed then
		return self:generateChart(player, score, bmap, existing_best, prev_stats, current_stats, score_id)
	end

	return nil
end

--- Calculate the submission status for a score.
--- Compares against existing best score on the map.
--- When PP is 0 (e.g. osu!std not yet implemented), falls back to score comparison.
---@param current_pp number
---@param current_score number
---@param existing_best_pp? number
---@param existing_best_score? number
---@return integer submission status (SubmissionStatus.*)
function ScoreSubmitter:calculateStatus(current_pp, current_score, existing_best_pp, existing_best_score)
	if current_pp > 0 then
		-- PP is available, use it
		if current_pp > (existing_best_pp or 0) then
			return SubmissionStatus.BEST
		end
	else
		-- PP not available, fall back to score comparison
		if current_score > (existing_best_score or 0) then
			return SubmissionStatus.BEST
		end
	end
	return SubmissionStatus.SUBMITTED
end

--- Check if a map awards ranked PP.
---@param ranked_status integer RankedStatus.*
---@return boolean
function ScoreSubmitter:mapAwardsRankedPP(ranked_status)
	return RankedStatus.awardsRankedPP(ranked_status)
end

--- Check if a map has a leaderboard.
---@param ranked_status integer RankedStatus.*
---@return boolean
function ScoreSubmitter:mapHasLeaderboard(ranked_status)
	return RankedStatus.hasLeaderboard(ranked_status)
end

--- Generate the chart response for the osu! client.
--- Returns the pipe-delimited chart string.
---@param player bancho.model.Player
---@param score bancho.model.Score
---@param bmap table beatmap data
---@param prev_best table|nil previous best score
---@param prev_stats table|nil previous overall stats
---@param current_stats table|nil current overall stats
---@param score_id integer new score ID
---@return string chart_response
function ScoreSubmitter:generateChart(player, score, bmap, prev_best, prev_stats, current_stats, score_id)
	-- Add player_id to score for chart
	score.player_id = player.id

	local ctx = {
		score_id = score_id or 0,
		bmap = bmap,
		score = score,
		prev_best = prev_best,
		prev_stats = prev_stats,
		current_stats = current_stats or {},
		domain = self.server.config.domain or "rizu.su",
		achievements = "",
	}

	return Chart.generate(ctx)
end

return ScoreSubmitter
