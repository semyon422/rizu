local M = {}
M.NOT_SUBMITTED   = -1
M.PENDING         = 0
M.UPDATE_AVAILABLE = 1
M.RANKED          = 2
M.APPROVED        = 3
M.QUALIFIED       = 4
M.LOVED           = 5

function M.hasLeaderboard(status)
	return status == M.RANKED or status == M.APPROVED or status == M.LOVED
end

function M.awardsRankedPP(status)
	return status == M.RANKED or status == M.APPROVED
end

--- Convert from osu! API v1 `approved` value to internal RankedStatus.
--- @param api_status integer osu! API approved value
--- @return integer internal status
function M.fromOsuApi(api_status)
	-- osu! API v1 approved values:
	-- -2: graveyard, -1: WIP, 0: pending, 1: ranked, 2: approved, 3: qualified, 4: loved
	local mapping = {
		[-2] = M.PENDING,
		[-1] = M.PENDING,
		[0]  = M.PENDING,
		[1]  = M.RANKED,
		[2]  = M.APPROVED,
		[3]  = M.QUALIFIED,
		[4]  = M.LOVED,
	}
	return mapping[api_status] or M.UPDATE_AVAILABLE
end

return M
