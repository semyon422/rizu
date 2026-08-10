
---@type icc.RemoteHandlerWhitelist
local whitelist = {
	auth = {
		checkSession = true,
		updateSession = true,
		loginSession = true,
		loginByToken = true,
		login = true,
		logout = true,
	},
	submission = {
		submitChartplay = true,
		getChartplaySubmission = true,
		getBestChartplaysForChartmeta = true,
		getBestChartplaysForChartdiff = true,
		getReplayFile = true,
	},
	leaderboards = {
		getLeaderboards = true,
		getUserLeaderboardUsers = true,
	},
	difftables = {
		getDifftables = true,
		getDifftableChartmetas = true,
	},
	multiplayer = {
		getRooms = true,
		getUsers = true,
		getUser = true,
		getRoomId = true,
		createRoom = true,
		joinRoom = true,
		leaveRoom = true,
		getCurrentRoom = true,
		setChartplayComputed = true,
		switchReady = true,
		setChartFound = true,
		setPlaying = true,
		sendMessage = true,
		updateRoom = true,
		kickUser = true,
		startMatch = true,
		stopMatch = true,
	},
	getUser = true,
	getSession = true,
	heartbeat = true,
	printAll = true,
	getRandomNumbersFromAllClients = true,
}

return whitelist
