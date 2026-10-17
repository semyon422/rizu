local class = require("class")

---@class rizu.OnlineWrapper
---@operator call: rizu.OnlineWrapper
local OnlineWrapper = class()

---@param client rizu.OnlineClient
---@param server_remote sea.ServerRemote
function OnlineWrapper:new(client, server_remote)
	self.client = client
	self.server_remote = server_remote
end

function OnlineWrapper:updateLeaderboards()
	local server_remote = self.server_remote
	local client = self.client

	local leaderboards = server_remote.leaderboards:getLeaderboards() or {}
	local leaderboard_users = server_remote.leaderboards:getUserLeaderboardUsers() or {}

	client:setLeaderboards(leaderboards)
	client:setLeaderboardUsers(leaderboard_users)
end

return OnlineWrapper
