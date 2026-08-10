local class = require("class")
local Leaderboard = require("sea.leaderboards.Leaderboard")
local LeaderboardUser = require("sea.leaderboards.LeaderboardUser")

---@class rizu.OnlineClientRemoteValidation
---@operator call: rizu.OnlineClientRemoteValidation
local OnlineClientRemoteValidation = class()

---@param remote rizu.OnlineClientRemote
function OnlineClientRemoteValidation:new(remote)
	self.remote = remote
end

---@param user sea.User?
function OnlineClientRemoteValidation:setUser(user)
	self.remote:setUser(user)
end

---@param leaderboards sea.Leaderboard[]
function OnlineClientRemoteValidation:setLeaderboards(leaderboards)
	assert(type(leaderboards) == "table")
	for _, lb in ipairs(leaderboards) do
		setmetatable(lb, Leaderboard)
	end
	self.remote:setLeaderboards(leaderboards)
end

---@param chartplay_id integer
function OnlineClientRemoteValidation:chartplaySubmissionCompleted(chartplay_id)
	assert(type(chartplay_id) == "number" and chartplay_id >= 1 and chartplay_id == math.floor(chartplay_id))
	self.remote:chartplaySubmissionCompleted(chartplay_id)
end

---@param leaderboards_users sea.LeaderboardUser[]
function OnlineClientRemoteValidation:setLeaderboardUsers(leaderboards_users)
	assert(type(leaderboards_users) == "table")
	for _, lb in ipairs(leaderboards_users) do
		setmetatable(lb, LeaderboardUser)
	end
	self.remote:setLeaderboardUsers(leaderboards_users)
end

return OnlineClientRemoteValidation
