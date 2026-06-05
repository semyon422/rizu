--- Tests for bancho score Submitter.

local Submitter = require("bancho.score.Submitter")
local SubmissionStatus = require("bancho.constants.SubmissionStatus")
local RankedStatus = require("bancho.constants.RankedStatus")
local Score = require("bancho.model.Score")

local test = {}

function test.calculateStatus_new_best(t)
	local s = Submitter:new()
	-- PP-based: current pp > existing pp
	t:eq(s:calculateStatus(1000, 999999, 500, 500000), SubmissionStatus.BEST)
	-- Score-based fallback: current score > existing score
	t:eq(s:calculateStatus(0, 999999, 0, 500000), SubmissionStatus.BEST)
end

function test.calculateStatus_submitted(t)
	local s = Submitter:new()
	-- PP-based: current pp < existing pp
	t:eq(s:calculateStatus(500, 500000, 1000, 999999), SubmissionStatus.SUBMITTED)
	-- Score-based fallback: current score < existing score
	t:eq(s:calculateStatus(0, 500000, 0, 999999), SubmissionStatus.SUBMITTED)
end

function test.calculateStatus_first_score(t)
	local s = Submitter:new()
	-- No existing score
	t:eq(s:calculateStatus(100, 999999, nil, nil), SubmissionStatus.BEST)
	-- No existing score, pp=0
	t:eq(s:calculateStatus(0, 999999, nil, nil), SubmissionStatus.BEST)
end

function test.mapAwardsRankedPP_ranked(t)
	local s = Submitter:new()
	t:eq(s:mapAwardsRankedPP(RankedStatus.RANKED), true)
	t:eq(s:mapAwardsRankedPP(RankedStatus.APPROVED), true)
	t:eq(s:mapAwardsRankedPP(RankedStatus.LOVED), false)
	t:eq(s:mapAwardsRankedPP(RankedStatus.PENDING), false)
end

function test.mapHasLeaderboard_ranked(t)
	local s = Submitter:new()
	t:eq(s:mapHasLeaderboard(RankedStatus.RANKED), true)
	t:eq(s:mapHasLeaderboard(RankedStatus.APPROVED), true)
	t:eq(s:mapHasLeaderboard(RankedStatus.LOVED), true)
	t:eq(s:mapHasLeaderboard(RankedStatus.PENDING), false)
	t:eq(s:mapHasLeaderboard(RankedStatus.NOT_SUBMITTED), false)
end

function test.checksum_validation_rejects_bad_checksum(t)
	-- Create a score with a valid checksum
	local score = Score:new()
	score:fromSubmission({
		"valid_checksum", "100", "50", "25", "10", "5", "3",
		"123456", "500", "True", "s", "0", "True",
		"0", "240101120000", "20240101"
	})

	-- Compute the correct checksum
	local correct_checksum = score:computeOnlineChecksum(
		"testuser", "abc123def456789012345678",
		"20240101", "client_hash", ""
	)

	-- Verify that a different checksum doesn't match
	t:ne(score.client_checksum, correct_checksum)

	-- Now set the correct checksum and verify it matches
	score.client_checksum = correct_checksum
	local recomputed = score:computeOnlineChecksum(
		"testuser", "abc123def456789012345678",
		"20240101", "client_hash", ""
	)
	t:eq(score.client_checksum, recomputed)
end

function test.checksum_validation_different_inputs(t)
	local score = Score:new()
	score:fromSubmission({
		"checksum", "100", "50", "25", "10", "5", "3",
		"123456", "500", "True", "s", "0", "True",
		"0", "240101120000", "20240101"
	})

	-- Different username produces different checksum
	local cs1 = score:computeOnlineChecksum("user1", "abc123def456789012345678", "20240101", "client_hash", "")
	local cs2 = score:computeOnlineChecksum("user2", "abc123def456789012345678", "20240101", "client_hash", "")
	t:ne(cs1, cs2)

	-- Different map MD5 produces different checksum
	local cs3 = score:computeOnlineChecksum("user1", "different_map_md512345678", "20240101", "client_hash", "")
	t:ne(cs1, cs3)
end

return test
