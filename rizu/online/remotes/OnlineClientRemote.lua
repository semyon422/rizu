local class = require("class")

---@class rizu.OnlineClientRemote
---@operator call: rizu.OnlineClientRemote
local OnlineClientRemote = class()

---@param online_client rizu.OnlineClient
function OnlineClientRemote:new(online_client)
	self.online_client = online_client
end

---@param user sea.User?
function OnlineClientRemote:setUser(user)
	self.online_client:setUser(user)
end

---@param leaderboards sea.Leaderboard[]
function OnlineClientRemote:setLeaderboards(leaderboards)
	self.online_client:setLeaderboards(leaderboards)
end

---@param leaderboards_users sea.LeaderboardUser[]
function OnlineClientRemote:setLeaderboardUsers(leaderboards_users)
	self.online_client:setLeaderboardUsers(leaderboards_users)
end

return OnlineClientRemote
