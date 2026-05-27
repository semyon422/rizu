--- Score submission processing.
---
--- Handles parsing the MODULAR selector submission, validating checksums,
--- and determining submission status (new best / submitted / failed).

local class = require("class")

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
local ScoreSubmitter = class()

function ScoreSubmitter:new()
	return self
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
