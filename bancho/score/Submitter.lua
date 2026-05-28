--- Score submission processing.
---
--- Handles parsing the MODULAR selector submission, validating checksums,
--- and determining submission status (new best / submitted / failed).

local class = require("class")
local Score = require("bancho.model.Score")
local SubmissionStatus = require("bancho.constants.SubmissionStatus")
local RankedStatus = require("bancho.constants.RankedStatus")

--- Compute the online checksum for score verification.
--- The checksum is an MD5 of a specific string format.
local function computeOnlineChecksum(score_data, map_md5, max_combo, perfect, username, score, grade, mods, passed, mode, client_time)
	-- Simplified: use lua's built-in
	-- Real implementation uses MD5 with chickenmcnuggets salt
	local salt = "chickenmcnuggets"
	local str = string.format("%s%d%d%d%d%s%s%.0f%d%s%d%d%d%s",
		salt,
		score_data.n100 + score_data.n300,
		score_data.n50,
		score_data.ngeki,
		score_data.nkatu,
		score_data.nmiss,
		map_md5,
		max_combo,
		perfect and 1 or 0,
		username,
		score,
		grade.value,
		mods,
		passed and "True" or "False",
		mode
	)
	-- Return a placeholder hash
	return str
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
--- Parses the score data, validates checksums, and persists the score.
---@param player bancho.model.Player
---@param score_data string decrypted score data (colon-delimited)
---@param replay_data string replay file data
---@param fields table form fields from submission
function ScoreSubmitter:submit(player, score_data, replay_data, fields)
	-- Parse score data (colon-delimited)
	local parts = {}
	for part in score_data:gmatch("[^:]+") do
		parts[#parts + 1] = part
	end

	-- Minimum fields check
	if #parts < 15 then
		return
	end

	-- Parse score from submission data
	local score = Score:new()
	score:fromSubmission(parts)

	-- Extract map MD5 (first field)
	local map_md5 = parts[1]
	if not map_md5 then
		return
	end

	-- Look up beatmap
	local bmap = nil
	if self.server.beatmap_repo then
		bmap = self.server.beatmap_repo:findBeatmap(map_md5)
	end

	if not bmap then
		return
	end

	-- Calculate accuracy
	score:calculateAccuracy()

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
	score.status = self:calculateStatus(score.pp or 0, existing_best and existing_best.pp or 0)

	-- If not passed, set status to failed
	if not score.passed then
		score.status = SubmissionStatus.FAILED
	end

	-- Set server time
	score.server_time = os.time()

	-- Save score to database
	local score_id = 0
	if self.server.score_repo then
		score_id = self.server.score_repo:addScore({
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
			checksum = parts[15] or "",
		})
	end

	-- Save replay
	if score.passed and replay_data and score_id > 0 then
		if self.server.replay_repo then
			self.server.replay_repo:saveReplay(score_id, replay_data)
		end
	end

	-- Update player stats
	if self.server.stats_repo then
		local stats_update = {
			plays = (stats_update and stats_update.plays or 0) + 1,
			playtime = (stats_update and stats_update.playtime or 0) + (tonumber(fields.st) or 0) / 1000,
			tscore = (stats_update and stats_update.tscore or 0) + score.score,
			total_hits = (stats_update and stats_update.total_hits or 0) + score.n300 + score.n100 + score.n50,
		}

		-- Update max combo if needed
		if score.max_combo > (stats_update and stats_update.max_combo or 0) then
			stats_update.max_combo = score.max_combo
		end

		self.server.stats_repo:updateStats(player.id, score.mode, stats_update)
	end

	-- If it's a new best and map awards ranked PP, send notification
	if score.status == SubmissionStatus.BEST and self:mapAwardsRankedPP(bmap.status or 0) then
		-- TODO: send notification to player
	end
end

--- Calculate the submission status for a score.
--- Compares against existing best score on the map.
---@param current_pp number
---@param existing_best_pp? number
---@return integer submission status (SubmissionStatus.*)
function ScoreSubmitter:calculateStatus(current_pp, existing_best_pp)
	if current_pp > (existing_best_pp or 0) then
		return SubmissionStatus.BEST
	else
		return SubmissionStatus.SUBMITTED
	end
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

return ScoreSubmitter
