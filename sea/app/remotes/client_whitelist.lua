---@type icc.RemoteHandlerWhitelist
local whitelist = {
	client = {
		setUser = true,
		setLeaderboards = true,
		setLeaderboardUsers = true,
		chartplaySubmissionCompleted = true,
		setRecentScores = true,
	},
	multiplayer = {
		setRooms = true,
		setRoomUsers = true,
		setUsers = true,
		startMatch = true,
		stopMatch = true,
		addMessage = true,
		syncRules = true,
		syncChart = true,
		syncReplayBase = true,
	},
	chat = {
		addMessage = true,
	},
	compute_data_provider = {
		getChartData = true,
		getIidxMetadata = true,
		getReplayData = true,
	},
	print = true,
	getRandomNumber = true,
}

return whitelist
