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

return M
