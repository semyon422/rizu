local RankedStatus = require("bancho.constants.RankedStatus")

local test = {}

function test.enum_values(t)
	t:eq(RankedStatus.NOT_SUBMITTED, -1)
	t:eq(RankedStatus.PENDING, 0)
	t:eq(RankedStatus.UPDATE_AVAILABLE, 1)
	t:eq(RankedStatus.RANKED, 2)
	t:eq(RankedStatus.APPROVED, 3)
	t:eq(RankedStatus.QUALIFIED, 4)
	t:eq(RankedStatus.LOVED, 5)
end

function test.hasLeaderboard(t)
	t:eq(RankedStatus.hasLeaderboard(RankedStatus.RANKED), true)
	t:eq(RankedStatus.hasLeaderboard(RankedStatus.APPROVED), true)
	t:eq(RankedStatus.hasLeaderboard(RankedStatus.LOVED), true)
	t:eq(RankedStatus.hasLeaderboard(RankedStatus.PENDING), false)
	t:eq(RankedStatus.hasLeaderboard(RankedStatus.QUALIFIED), false)
end

function test.awardsRankedPP(t)
	t:eq(RankedStatus.awardsRankedPP(RankedStatus.RANKED), true)
	t:eq(RankedStatus.awardsRankedPP(RankedStatus.APPROVED), true)
	t:eq(RankedStatus.awardsRankedPP(RankedStatus.LOVED), false)
	t:eq(RankedStatus.awardsRankedPP(RankedStatus.PENDING), false)
end

function test.fromOsuApi(t)
	-- Graveyard and WIP → PENDING
	t:eq(RankedStatus.fromOsuApi(-2), RankedStatus.PENDING)
	t:eq(RankedStatus.fromOsuApi(-1), RankedStatus.PENDING)
	-- Pending → PENDING
	t:eq(RankedStatus.fromOsuApi(0), RankedStatus.PENDING)
	-- Ranked → RANKED
	t:eq(RankedStatus.fromOsuApi(1), RankedStatus.RANKED)
	-- Approved → APPROVED
	t:eq(RankedStatus.fromOsuApi(2), RankedStatus.APPROVED)
	-- Qualified → QUALIFIED
	t:eq(RankedStatus.fromOsuApi(3), RankedStatus.QUALIFIED)
	-- Loved → LOVED
	t:eq(RankedStatus.fromOsuApi(4), RankedStatus.LOVED)
	-- Unknown → UPDATE_AVAILABLE
	t:eq(RankedStatus.fromOsuApi(99), RankedStatus.UPDATE_AVAILABLE)
	t:eq(RankedStatus.fromOsuApi(-99), RankedStatus.UPDATE_AVAILABLE)
end

return test
