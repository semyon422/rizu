local class = require("class")

---@class rizu.OnlineClient
---@operator call: rizu.OnlineClient
---@field user sea.User?
---@field leaderboards sea.Leaderboard[]
---@field leaderboard_users sea.LeaderboardUser[]
local OnlineClient = class()

function OnlineClient:new()
	self.leaderboards = {}
	self.leaderboards_users = {}
	self.completed_chartplay_ids = {}
end

---@param user sea.User?
function OnlineClient:setUser(user)
	self.user = user
end

---@return sea.User?
function OnlineClient:getUser()
	return self.user
end

---@param leaderboards sea.Leaderboard[]
function OnlineClient:setLeaderboards(leaderboards)
	self.leaderboards = leaderboards
end

---@param leaderboards_users sea.LeaderboardUser[]
function OnlineClient:setLeaderboardUsers(leaderboards_users)
	self.leaderboards_users = leaderboards_users
end

---@param chartplay_id integer
function OnlineClient:chartplaySubmissionCompleted(chartplay_id)
	table.insert(self.completed_chartplay_ids, chartplay_id)
end

---@param lb_id integer
---@return sea.Leaderboard?
function OnlineClient:getLeaderboard(lb_id)
	for _, lb in ipairs(self.leaderboards) do
		if lb.id == lb_id then
			return lb
		end
	end
end

---@param lb_id integer
---@return sea.LeaderboardUser?
function OnlineClient:getLeaderboardUser(lb_id)
	for _, lu in ipairs(self.leaderboards_users) do
		if lu.leaderboard_id == lb_id then
			return lu
		end
	end
end

return OnlineClient
