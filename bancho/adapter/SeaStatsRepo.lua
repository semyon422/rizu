local class = require("class")

---@class bancho.adapter.SeaStatsRepo
---@operator call: bancho.adapter.SeaStatsRepo
---@field users_repo sea.UsersRepo
---@field leaderboards_repo sea.LeaderboardsRepo
local SeaStatsRepo = class()

---@param users_repo sea.UsersRepo
---@param leaderboards_repo sea.LeaderboardsRepo
function SeaStatsRepo:new(users_repo, leaderboards_repo)
	self.users_repo = users_repo
	self.leaderboards_repo = leaderboards_repo
end

---@param mode integer
---@return sea.Gamemode?
function SeaStatsRepo:getSeaMode(mode)
	if mode == 0 then
		return "osu"
	elseif mode == 1 then
		return "taiko"
	elseif mode == 3 then
		return "mania"
	end
end

---@param mode integer
---@return sea.Leaderboard?
function SeaStatsRepo:getOsuPpLeaderboard(mode)
	local sea_mode = self:getSeaMode(mode)
	if not sea_mode then
		return nil
	end

	for _, leaderboard in ipairs(self.leaderboards_repo:getLeaderboards()) do
		if leaderboard.rating_calc == "pp"
			and leaderboard.mode == sea_mode
			and leaderboard.name
			and leaderboard.name:lower():find("osu", 1, true)
		then
			return leaderboard
		end
	end
end

---@param user_id integer
---@param mode integer
---@return table?
function SeaStatsRepo:getStats(user_id, mode)
	local user = self.users_repo:getUser(user_id)
	if not user then
		return nil
	end

	local stats = {
		user_id = user_id,
		mode = mode,
		tscore = 0,
		rscore = 0,
		pp = 0,
		acc = 0,
		plays = 0,
		playtime = user.play_time or 0,
		max_combo = 0,
		rank = 0,
		country_rank = 0,
		total_hits = 0,
		xh_count = 0,
		x_count = 0,
		sh_count = 0,
		s_count = 0,
		a_count = 0,
	}

	local leaderboard = self:getOsuPpLeaderboard(mode)
	if not leaderboard then
		return stats
	end

	local leaderboard_user = self.leaderboards_repo:getLeaderboardUser(leaderboard.id, user_id)
	if not leaderboard_user then
		return stats
	end

	stats.pp = math.floor(leaderboard_user.total_rating or 0)
	stats.acc = leaderboard_user:getNormAccuracy() * 100
	stats.plays = leaderboard_user.total_plays or leaderboard_user.ranked_plays or 0
	stats.rank = leaderboard_user.rank or 0

	return stats
end

---@param user_id integer
---@param mode integer
---@param fields table
---@return boolean
function SeaStatsRepo:updateStats(user_id, mode, fields)
	return true
end

---@param user_id integer
---@param mode integer
---@param pp number
---@return integer
function SeaStatsRepo:getGlobalRank(user_id, mode, pp)
	local leaderboard = self:getOsuPpLeaderboard(mode)
	if not leaderboard then
		return 0
	end

	local leaderboard_user = self.leaderboards_repo:getLeaderboardUser(leaderboard.id, user_id)
	if leaderboard_user and leaderboard_user.rank then
		return leaderboard_user.rank
	end

	return self.leaderboards_repo:getLeaderboardUserRank(leaderboard.id, pp)
end

return SeaStatsRepo
