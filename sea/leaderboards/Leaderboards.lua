local class = require("class")
local table_util = require("table_util")
local LeaderboardsAccess = require("sea.leaderboards.access.LeaderboardsAccess")
local Leaderboard = require("sea.leaderboards.Leaderboard")
local LeaderboardUser = require("sea.leaderboards.LeaderboardUser")
local LeaderboardUserHistory = require("sea.leaderboards.LeaderboardUserHistory")
local LeaderboardDifftable = require("sea.leaderboards.LeaderboardDifftable")
local RatingCalc = require("sea.leaderboards.RatingCalc")
local TotalRating = require("sea.leaderboards.TotalRating")

---@class sea.Leaderboards
---@operator call: sea.Leaderboards
local Leaderboards = class()

---@param leaderboards_repo sea.LeaderboardsRepo
function Leaderboards:new(leaderboards_repo)
	self.total_rating = TotalRating()
	self.leaderboards_repo = leaderboards_repo
	self.leaderboards_access = LeaderboardsAccess()
end

---@return sea.Leaderboard[]
function Leaderboards:getLeaderboards()
	return self.leaderboards_repo:getLeaderboards()
end

---@return integer
function Leaderboards:getLeaderboardsCount()
	return self.leaderboards_repo:getLeaderboardsCount()
end

---@param id integer?
---@return sea.Leaderboard?
function Leaderboards:getLeaderboard(id)
	if not id then
		return
	end
	return self.leaderboards_repo:getLeaderboard(id)
end

---@param lb_id integer
---@param user_id integer
---@return sea.LeaderboardUser?
function Leaderboards:getLeaderboardUser(lb_id, user_id)
	return self.leaderboards_repo:getLeaderboardUser(lb_id, user_id)
end

---@param lb_id integer
---@return integer
function Leaderboards:getLeaderboardUsersCount(lb_id)
	return self.leaderboards_repo:getLeaderboardUsersCount(lb_id)
end

---@param user sea.User
---@return sea.LeaderboardUser[]?
---@return string?
function Leaderboards:getUserLeaderboardUsers(user)
	if user:isAnon() then
		return nil, "not allowed"
	end
	return self.leaderboards_repo:getUserLeaderboardUsers(user.id)
end

---@param lb_id integer
---@param limit integer?
---@param offset integer?
---@return sea.LeaderboardUser[]
function Leaderboards:getLeaderboardUsersFull(lb_id, limit, offset)
	return self.leaderboards_repo:getLeaderboardUsersFull(lb_id, limit, offset)
end

---@param lb_id integer
---@param user_id integer
---@return sea.LeaderboardUserHistory?
function Leaderboards:getLeaderboardUserHistory(lb_id, user_id)
	return self.leaderboards_repo:getLeaderboardUserHistory(lb_id, user_id)
end

---@param lb_id integer
---@param lb_users sea.LeaderboardUser[]
function Leaderboards:loadLeaderboardUsersHistory(lb_id, lb_users)
	self.leaderboards_repo:loadLeaderboardUsersHistory(lb_id, lb_users)
end

---@param lb sea.Leaderboard
---@param user_id integer
---@return sea.Chartplayview[]
function Leaderboards:getBestChartplaysFull(lb, user_id)
	return self.leaderboards_repo:getBestChartplaysFull(lb, user_id)
end

---@param lb sea.Leaderboard
---@param user_id integer
---@return sea.Chartplayview[]
function Leaderboards:getFirstPlaceChartplaysFull(lb, user_id)
	return self.leaderboards_repo:getFirstPlaceChartplaysFull(lb, user_id)
end

---@param lb sea.Leaderboard
---@param user_id integer
---@return sea.Chartplayview[]
function Leaderboards:getRecentChartplaysFull(lb, user_id)
	return self.leaderboards_repo:getRecentChartplaysFull(lb, user_id)
end

---@param lb sea.Leaderboard
---@param user_id integer
---@param no_rank boolean?
---@param time integer?
function Leaderboards:updateLeaderboardUser(lb, user_id, no_rank, time)
	local repo = self.leaderboards_repo
	local total_rating = self.total_rating

	local chartplays = repo:getBestChartplays(lb, user_id, time)
	total_rating:calc(chartplays)
	local rating = total_rating:get(lb.rating_calc)

	time = time or os.time()

	local lb_user = repo:getLeaderboardUser(lb.id, user_id)
	local found = not not lb_user
	if not lb_user then
		lb_user = LeaderboardUser()
		lb_user.leaderboard_id = lb.id
		lb_user.user_id = user_id
		lb_user.rank = 0
	end

	lb_user.total_rating = rating
	lb_user.total_accuracy = total_rating.accuracy
	lb_user.total_plays = repo:getRankedChartplaysCount(lb, user_id, true)
	lb_user.ranked_plays = repo:getRankedChartplaysCount(lb, user_id)
	lb_user.updated_at = time

	if not found then
		repo:createLeaderboardUser(lb_user)
	else
		repo:updateLeaderboardUser(lb_user)
	end

	if no_rank then
		return
	end

	repo:updateLeaderboardUserRanks(lb)

	lb_user = assert(repo:getLeaderboardUser(lb.id, user_id))
	self:updateHistory(lb_user)
end

---@param lb sea.Leaderboard
function Leaderboards:updateRanks(lb)
	self.leaderboards_repo:updateLeaderboardUserRanks(lb)
end

---@param lb_user sea.LeaderboardUser
---@param last_only boolean?
function Leaderboards:updateHistory(lb_user, last_only)
	local repo = self.leaderboards_repo

	local lb_user_his = repo:getLeaderboardUserHistory(lb_user.leaderboard_id, lb_user.user_id)
	if not lb_user_his then
		lb_user_his = repo:createLeaderboardUserHistory(lb_user)
	end

	local j = lb_user_his:getIndex(1, lb_user.updated_at)

	local indexes = {j}
	if not last_only then
		indexes = {}
		local i = lb_user_his:getIndex(0)
		if i - 1 > j then
			j = j + lb_user_his.size
		end
		for k = i, j do
			table.insert(indexes, (k - 1) % lb_user_his.size + 1)
		end
	end

	repo:updateLeaderboardUserHistory(lb_user, indexes)
end

---@param time integer
---@param lb sea.Leaderboard
function Leaderboards:updateHistories(time, lb)
	local repo = self.leaderboards_repo

	local lb_users = repo:getLeaderboardUsers(lb.id)
	for _, lb_user in ipairs(lb_users) do
		lb_user.updated_at = time
		self:updateHistory(lb_user)
	end
end

---@param time integer
---@param lb sea.Leaderboard
function Leaderboards:computeHistories(time, lb)
	local repo = self.leaderboards_repo
	local day_dur = 3600 * 24

	for i = LeaderboardUserHistory.size, 1, -1 do
		print(i)
		local updated_at = time - (i - 1) * day_dur

		local lb_users = repo:getLeaderboardUsersAll(lb.id)
		for _, lb_user in ipairs(lb_users) do
			self:updateLeaderboardUser(lb, lb_user.user_id, true, updated_at)
		end

		repo:updateLeaderboardUserRanks()

		lb_users = repo:getLeaderboardUsersAll(lb.id)
		for _, lb_user in ipairs(lb_users) do
			self:updateHistory(lb_user, true)
		end
	end
end

---@param chartplay sea.Chartplay
function Leaderboards:addChartplay(chartplay)
	local repo = self.leaderboards_repo

	-- TODO: optimize: cache leaderboards, fast check in lua before sql
	for _, lb in ipairs(repo:getLeaderboards()) do
		if repo:checkChartplay(lb, chartplay) then
			self:updateLeaderboardUser(lb, chartplay.user_id)
		end
	end
end

---@param user sea.User
---@param lb_values sea.Leaderboard
---@return sea.Leaderboard?
---@return string?
function Leaderboards:create(user, lb_values)
	local can, err = self.leaderboards_access:canManage(user, os.time())
	if not can then
		return nil, err
	end

	local lb = self.leaderboards_repo:getLeaderboardByName(lb_values.name)
	if lb then
		return nil, "name_taken"
	end

	lb_values.created_at = os.time()

	lb = self.leaderboards_repo:createLeaderboard(lb_values)
	self:updateLeaderboardDifftables(lb.id, lb_values.leaderboard_difftables)

	return lb
end

---@param user sea.User
---@param id integer
---@param lb_values sea.Leaderboard
---@return sea.Leaderboard?
---@return string?
function Leaderboards:update(user, id, lb_values)
	local can, err = self.leaderboards_access:canManage(user, os.time())
	if not can then
		return nil, err
	end

	local lb = self.leaderboards_repo:getLeaderboardByName(lb_values.name)
	if lb and lb.id ~= id then
		return nil, "name_taken"
	end

	lb = lb or self.leaderboards_repo:getLeaderboard(id)

	if not lb then
		return nil, "not_found"
	end

	lb_values.id = lb.id

	lb = self.leaderboards_repo:updateLeaderboardFull(lb_values)
	self:updateLeaderboardDifftables(id, lb_values.leaderboard_difftables)

	return lb
end

---@param user sea.User
---@param id integer
---@return true?
---@return string?
function Leaderboards:delete(user, id)
	local can, err = self.leaderboards_access:canManage(user, os.time())
	if not can then
		return nil, err
	end

	self.leaderboards_repo:deleteLeaderboard(id)

	return true
end

---@param leaderboard_id integer
---@param lb_dts sea.LeaderboardDifftable[]
---@return true?
---@return string?
function Leaderboards:updateLeaderboardDifftables(leaderboard_id, lb_dts)
	local leaderboard_difftables = self.leaderboards_repo:getLeaderboardDifftables(leaderboard_id)

	local function get_id(ld) return ld.difftable_id end
	local new_difftable_ids, old_difftable_ids = table_util.array_update(
		lb_dts,
		leaderboard_difftables,
		get_id,
		get_id
	)

	for _, difftable_id in ipairs(old_difftable_ids) do
		self.leaderboards_repo:deleteLeaderboardDifftable(leaderboard_id, difftable_id)
	end

	for _, difftable_id in ipairs(new_difftable_ids) do
		local lb_dt = LeaderboardDifftable()
		lb_dt.leaderboard_id = leaderboard_id
		lb_dt.difftable_id = difftable_id
		self.leaderboards_repo:createLeaderboardDifftable(lb_dt)
	end
end

return Leaderboards
