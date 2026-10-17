local class = require("class")
local sql_util = require("rdb.sql_util")
local table_util = require("table_util")
local RatingCalc = require("sea.leaderboards.RatingCalc")
local Leaderboard = require("sea.leaderboards.Leaderboard")
local LeaderboardUserHistory = require("sea.leaderboards.LeaderboardUserHistory")

---@class sea.LeaderboardsRepo
---@operator call: sea.LeaderboardsRepo
local LeaderboardsRepo = class()

---@param models rdb.Models
function LeaderboardsRepo:new(models)
	self.models = models
end

---@return sea.Leaderboard[]
function LeaderboardsRepo:getLeaderboards()
	local lbs = self.models.leaderboards:select()
	self.models.leaderboards:preload(lbs, "leaderboard_difftables")
	return lbs
end

---@return integer
function LeaderboardsRepo:getLeaderboardsCount()
	return self.models.leaderboards:count()
end

---@param id integer
---@return sea.Leaderboard?
function LeaderboardsRepo:getLeaderboard(id)
	local lb = self.models.leaderboards:find({id = assert(id)})
	self.models.leaderboards:preload({lb}, {leaderboard_difftables = "difftable"})
	return lb
end

---@param name string
---@return sea.Leaderboard?
function LeaderboardsRepo:getLeaderboardByName(name)
	return self.models.leaderboards:find({name = assert(name)})
end

---@param leaderboard sea.Leaderboard
---@return sea.Leaderboard
function LeaderboardsRepo:createLeaderboard(leaderboard)
	return self.models.leaderboards:create(leaderboard)
end

---@param leaderboard sea.Leaderboard
---@return sea.Leaderboard
function LeaderboardsRepo:updateLeaderboard(leaderboard)
	return self.models.leaderboards:update(leaderboard, {id = assert(leaderboard.id)})[1]
end

---@param leaderboard sea.Leaderboard
---@return sea.Leaderboard
function LeaderboardsRepo:updateLeaderboardFull(leaderboard)
	local values = sql_util.null_keys(Leaderboard.struct)
	table_util.copy(leaderboard, values)
	return self.models.leaderboards:update(values, {id = assert(leaderboard.id)})[1]
end

---@param id integer
---@return sea.Leaderboard?
function LeaderboardsRepo:deleteLeaderboard(id)
	return self.models.leaderboards:delete({id = assert(id)})[1]
end

local nearest_cond = {
	disabled = false,
	enabled = true,
	any = nil,
}

---@param lb sea.Leaderboard
---@param user_id integer
---@return rdb.Conditions
---@return rdb.Options
function LeaderboardsRepo:getFilterConds(lb, user_id)
	---@type rdb.Conditions
	local conds = {
		user_id = assert(user_id),
		nearest = nearest_cond[lb.nearest],
		mode = lb.mode,
	}
	if not lb.allow_custom then
		conds.custom = false
	end
	if not lb.allow_pause then
		conds.pause_count = 0
	end
	if not lb.allow_reorder then
		conds.columns_order = {}
	end
	if not lb.allow_modifiers then
		conds.modifiers = {}
	end
	if not lb.allow_tap_only then
		conds.tap_only = false
	end
	if not lb.allow_const then
		conds.const = false
	end
	if not lb.allow_free_timings then
		if lb.timings then
			table.insert(conds, {
				"or",
				timings = lb.timings,
				{
					timings__isnull = true,
					chartmeta_timings = lb.timings,
				},
			})
		else
			table.insert(conds, {
				"or",
				timings__isnull = true,
				timings_ = "chartmeta_timings",
			})
		end
	end
	if not lb.allow_free_healths then
		if lb.healths then
			table.insert(conds, {
				"or",
				healths = lb.healths,
				{
					healths__isnull = true,
					chartmeta_healths = lb.healths,
				},
			})
		else
			table.insert(conds, {
				"or",
				healths__isnull = true,
				healths_ = "chartmeta_healths",
			})
		end
	end
	if lb.pass then
		conds.pass = true
	end
	if lb.judges == "fc" then
		conds.miss_count = 0
	elseif lb.judges == "pfc" then
		conds.miss_count = 0
		conds.not_perfect_count = 0
	end

	local rate = lb.rate
	if type(rate) == "number" then
		conds.rate = rate
	elseif rate[1] then
		conds.rate__in = rate
	elseif rate.min then
		conds.rate__gte, conds.rate__lte = rate.min, rate.max
	end

	if lb.starts_at then
		conds.submitted_at__gte = lb.starts_at
	end
	if lb.ends_at then
		conds.submitted_at__lte = lb.ends_at
	end

	local chartmeta_inputmode = lb.chartmeta_inputmode
	if chartmeta_inputmode[1] then
		conds.chartmeta_inputmode__in = chartmeta_inputmode
	end

	local chartdiff_inputmode = lb.chartdiff_inputmode
	if chartdiff_inputmode[1] then
		conds.chartdiff_inputmode__in = chartdiff_inputmode
	end

	local difftable_ids = {}
	for _, lb_dt in ipairs(lb.leaderboard_difftables) do
		table.insert(difftable_ids, lb_dt.difftable_id)
	end
	if difftable_ids[1] then
		conds.difftable_id__in = difftable_ids
	end

	local rating_column = RatingCalc:column(lb.rating_calc)

	---@type rdb.Options
	local options = {
		group = {"hash", "`index`"},
		limit = 100,
		order = {rating_column .. " DESC"},
		columns = {"*", ("MAX(%s) AS _rating"):format(rating_column)},
	}

	if difftable_ids[1] then
		-- options.columns[3] = "MAX(difftable_level) AS difftable_level"
	end

	return conds, options
end

---@param lb sea.Leaderboard
---@param chartplay sea.Chartplay
---@return boolean
function LeaderboardsRepo:checkChartplay(lb, chartplay)
	local conds, options = self:getFilterConds(lb, chartplay.user_id)
	conds.chartplay_id = assert(chartplay.id)
	return not not self.models.chartplayviews:select(conds, options)[1]
end

---@param lb sea.Leaderboard
---@param user_id integer
---@param time integer?
---@return sea.Chartplayview[]
function LeaderboardsRepo:getBestChartplays(lb, user_id, time)
	local conds, options = self:getFilterConds(lb, user_id)
	conds.compute_state = "valid"
	if time then
		conds.submitted_at__lte = time
	end
	return self.models.chartplayviews:select(conds, options)
end

---@param lb sea.Leaderboard
---@param user_id integer
---@param total boolean?
---@return integer
function LeaderboardsRepo:getRankedChartplaysCount(lb, user_id, total)
	local conds, options = self:getFilterConds(lb, user_id)
	conds.compute_state = "valid"
	options.limit = nil
	if total then
		options.group = nil
		options.columns = {"*"}
	end
	return self.models.chartplayviews:count(conds, options)
end

---@param lb sea.Leaderboard
---@param user_id integer
---@return sea.Chartplayview[]
function LeaderboardsRepo:getBestChartplaysFull(lb, user_id)
	local chartplayviews = self:getBestChartplays(lb, user_id)
	return self.models.chartplayviews:preload(chartplayviews, "chartdiff", "chartmeta")
end

---@param lb sea.Leaderboard
---@param user_id integer
---@return sea.Chartplayview[]
function LeaderboardsRepo:getFirstPlaceChartplaysFull(lb, user_id)
	local conds, options = self:getFilterConds(lb, user_id)
	conds.user_id = nil
	conds.compute_state = "valid"
	options.group = {"hash", "`index`"}
	options.having = {user_id = user_id}
	local chartplayviews = self.models.chartplayviews:select(conds, options)
	return self.models.chartplayviews:preload(chartplayviews, "chartdiff", "chartmeta")
end

---@param lb sea.Leaderboard
---@param user_id integer
---@return sea.Chartplayview[]
function LeaderboardsRepo:getRecentChartplaysFull(lb, user_id)
	local conds, options = self:getFilterConds(lb, user_id)
	options.order = {"submitted_at DESC"}
	options.group = {"id"}
	local chartplayviews = self.models.chartplayviews:select(conds, options)
	return self.models.chartplayviews:preload(chartplayviews, "chartdiff", "chartmeta")
end

--------------------------------------------------------------------------------

---@param leaderboard_id integer
---@param user_id integer
---@return sea.LeaderboardUser?
function LeaderboardsRepo:getLeaderboardUser(leaderboard_id, user_id)
	return self.models.leaderboard_users:find({
		leaderboard_id = assert(leaderboard_id),
		user_id = assert(user_id),
	})
end

---@param leaderboard_id integer
---@param limit integer?
---@param offset integer?
---@return sea.LeaderboardUser[]
function LeaderboardsRepo:getLeaderboardUsers(leaderboard_id, limit, offset)
	return self.models.leaderboard_users:select({
		leaderboard_id = assert(leaderboard_id),
		total_rating__gt = 0,
	}, {
		order = {"total_rating DESC"},
		limit = limit,
		offset = offset,
	})
end

---@param leaderboard_id integer
---@return sea.LeaderboardUser[]
function LeaderboardsRepo:getLeaderboardUsersAll(leaderboard_id)
	return self.models.leaderboard_users:select({
		leaderboard_id = assert(leaderboard_id),
	})
end

---@param user_id integer
---@return sea.LeaderboardUser[]
function LeaderboardsRepo:getUserLeaderboardUsers(user_id)
	return self.models.leaderboard_users:select({user_id = assert(user_id)})
end

---@param leaderboard_id integer
---@return integer
function LeaderboardsRepo:getLeaderboardUsersCount(leaderboard_id)
	return self.models.leaderboard_users:count({
		leaderboard_id = assert(leaderboard_id),
		total_rating__gt = 0,
	})
end

---@param leaderboard_id integer
---@param limit integer?
---@param offset integer?
---@return sea.LeaderboardUser[]
function LeaderboardsRepo:getLeaderboardUsersFull(leaderboard_id, limit, offset)
	return self.models.leaderboard_users:preload(
		self:getLeaderboardUsers(leaderboard_id, limit, offset),
		"user"
	)
end

---@param lb_id integer
---@param lb_users sea.LeaderboardUser[]
function LeaderboardsRepo:loadLeaderboardUsersHistory(lb_id, lb_users)
	---@type integer[]
	local user_ids = {}

	---@type {[integer]: sea.LeaderboardUser}
	local lb_user_by_user_id = {}

	for _, lb_user in ipairs(lb_users) do
		table.insert(user_ids, lb_user.user_id)
		lb_user_by_user_id[lb_user.user_id] = lb_user
	end

	---@type sea.LeaderboardUserHistory[]
	local hs = self.models.leaderboard_user_histories:select({
		leaderboard_id = assert(lb_id),
		user_id__in = user_ids,
	})

	for _, h in ipairs(hs) do
		lb_user_by_user_id[h.user_id].history = h
	end
end

---@param lb_user sea.LeaderboardUser
---@return sea.LeaderboardUser
function LeaderboardsRepo:createLeaderboardUser(lb_user)
	return self.models.leaderboard_users:create(lb_user)
end

---@param lb_user sea.LeaderboardUser
---@return sea.LeaderboardUser
function LeaderboardsRepo:updateLeaderboardUser(lb_user)
	return self.models.leaderboard_users:update(lb_user, {id = assert(lb_user.id)})[1]
end

---@param leaderboard_id integer
---@param total_rating number
---@return integer
function LeaderboardsRepo:getLeaderboardUserRank(leaderboard_id, total_rating)
	return self.models.leaderboard_users:count({
		leaderboard_id = assert(leaderboard_id),
		total_rating__gt = assert(total_rating),
	}) + 1
end

---@param lb sea.Leaderboard?
function LeaderboardsRepo:updateLeaderboardUserRanks(lb)
	local where = ""
	local partition = "PARTITION BY leaderboard_id"
	if lb then
		where = "WHERE leaderboard_id = " .. lb.id
		partition = ""
	end

	self.models._orm.db:query(([[
		UPDATE leaderboard_users
		SET rank = lb_users.rank
		FROM (
			SELECT
				ROW_NUMBER() OVER (%s ORDER BY total_rating DESC) AS rank,
				id
			FROM leaderboard_users
			%s
		) AS lb_users
		WHERE
			leaderboard_users.id = lb_users.id AND
			leaderboard_users.rank != lb_users.rank
	]]):format(partition, where))
end
--------------------------------------------------------------------------------

---@param leaderboard_id integer
---@param user_id integer
---@return sea.LeaderboardUserHistory?
function LeaderboardsRepo:getLeaderboardUserHistory(leaderboard_id, user_id)
	return self.models.leaderboard_user_histories:find({
		leaderboard_id = assert(leaderboard_id),
		user_id = assert(user_id),
	})
end

---@param lb_user sea.LeaderboardUser
---@return sea.LeaderboardUserHistory
function LeaderboardsRepo:createLeaderboardUserHistory(lb_user)
	local obj = LeaderboardUserHistory()
	obj.leaderboard_id = lb_user.leaderboard_id
	obj.user_id = lb_user.user_id
	obj.updated_at = lb_user.updated_at

	---@type rdb.Row
	local row = obj

	for i = 1, LeaderboardUserHistory.size do
		row["total_rating_" .. i] = 0
		row["total_accuracy_" .. i] = 0
		row["rank_" .. i] = lb_user.user_id
	end

	return self.models.leaderboard_user_histories:create(obj)
end

---@param lb_user sea.LeaderboardUser
---@param indexes integer[]
---@return sea.LeaderboardUser
function LeaderboardsRepo:updateLeaderboardUserHistory(lb_user, indexes)
	local conds = {
		leaderboard_id = lb_user.leaderboard_id,
		user_id = lb_user.user_id,
	}
	---@type rdb.Row
	local values = {}
	values.updated_at = lb_user.updated_at
	for _, i in ipairs(indexes) do
		values["total_rating_" .. i] = lb_user.total_rating
		values["total_accuracy_" .. i] = lb_user.total_accuracy
		values["rank_" .. i] = lb_user.rank
	end
	return self.models.leaderboard_user_histories:update(values, conds)[1]
end

--------------------------------------------------------------------------------

---@param leaderboard_id integer
---@return sea.LeaderboardDifftable[]
function LeaderboardsRepo:getLeaderboardDifftables(leaderboard_id)
	return self.models.leaderboard_difftables:select({leaderboard_id = assert(leaderboard_id)})
end

---@param leaderboard_difftable sea.LeaderboardDifftable
---@return sea.LeaderboardDifftable
function LeaderboardsRepo:createLeaderboardDifftable(leaderboard_difftable)
	return self.models.leaderboard_difftables:create(leaderboard_difftable)
end

---@param leaderboard_id integer
---@param difftable_id integer
---@return sea.LeaderboardDifftable
function LeaderboardsRepo:deleteLeaderboardDifftable(leaderboard_id, difftable_id)
	return self.models.leaderboard_difftables:delete({
		leaderboard_id = assert(leaderboard_id),
		difftable_id = assert(difftable_id),
	})[1]
end

return LeaderboardsRepo
