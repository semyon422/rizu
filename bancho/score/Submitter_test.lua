--- Tests for bancho score Submitter.

local Submitter = require("bancho.score.Submitter")
local SubmissionStatus = require("bancho.constants.SubmissionStatus")
local RankedStatus = require("bancho.constants.RankedStatus")

local test = {}

function test.calculateStatus_new_best(t)
	local s = Submitter:new()
	t:eq(s:calculateStatus(1000, 500), SubmissionStatus.BEST)
end

function test.calculateStatus_submitted(t)
	local s = Submitter:new()
	t:eq(s:calculateStatus(500, 1000), SubmissionStatus.SUBMITTED)
end

function test.calculateStatus_first_score(t)
	local s = Submitter:new()
	t:eq(s:calculateStatus(100, nil), SubmissionStatus.BEST)
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

return test
