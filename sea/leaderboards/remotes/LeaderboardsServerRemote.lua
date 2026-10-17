local class = require("class")

---@class sea.LeaderboardsServerRemote: sea.IServerRemoteContext
---@operator call: sea.LeaderboardsServerRemote
local LeaderboardsServerRemote = class()

---@param leaderboards sea.Leaderboards
function LeaderboardsServerRemote:new(leaderboards)
	self.leaderboards = leaderboards
end

---@return sea.Leaderboard[]?
---@return string?
function LeaderboardsServerRemote:getLeaderboards()
	return self.leaderboards:getLeaderboards()
end

---@return sea.LeaderboardUser[]?
---@return string?
function LeaderboardsServerRemote:getUserLeaderboardUsers()
	return self.leaderboards:getUserLeaderboardUsers(self.user)
end

return LeaderboardsServerRemote
