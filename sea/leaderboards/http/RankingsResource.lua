local brand = require("brand")
local IResource = require("web.framework.IResource")

---@class sea.RankingsResource: web.IResource
---@operator call: sea.RankingsResource
local RankingsResource = IResource + {}

RankingsResource.routes = {
	{"/rankings", {
		GET = "getRankings",
	}},
}

RankingsResource.users_per_page = 50

RankingsResource.ranking_type_tabs = {
	{name = "Rating", id = "rating"},
	-- {name = "Accuracy", id = "accuracy"},
	{name = "Charts", id = "charts"},
	{name = "Play count", id = "play_count"},
	{name = "Play time", id = "play_time"},
	-- {name = "Social rating", id = "social_rating"},
}

---@param users sea.Users
---@param leaderboards sea.Leaderboards
---@param views web.Views
---@param user_connections sea.UserConnections
function RankingsResource:new(users, leaderboards, views, user_connections)
	self.users = users
	self.leaderboards = leaderboards
	self.views = views
	self.user_connections = user_connections
end

---@param leaderboard sea.Leaderboard
---@return string[] rules_allowed
---@return string[] rules_disallowed
function RankingsResource:getRules(leaderboard)
	local rules_allowed = {}
	local rules_disallowed = {}

	local function addRule(condition, text)
		if condition then
			table.insert(rules_allowed, text)
		else
			table.insert(rules_disallowed, text)
		end
	end

	addRule(leaderboard.allow_const, "Constant scroll speed")
	addRule(leaderboard.allow_pause, "Pauses")
	addRule(leaderboard.allow_modifiers, "Modifiers")
	addRule(leaderboard.allow_reorder, "Column reorder (Mirror, Random, etc...)")
	addRule(leaderboard.allow_free_timings, "Score system customization")
	addRule(not leaderboard.pass, "HP fails")

	if leaderboard.judges == "fc" then
		table.insert(rules_disallowed, "Misses")
	elseif leaderboard.judges == "pfc" then
		table.insert(rules_disallowed, "Not perfect hits")
	end

	if leaderboard.nearest == "disabled" then
		table.insert(rules_disallowed, "Nearest input")
	elseif leaderboard.nearest == "enabled" then
		table.insert(rules_disallowed, "Enabled nearest input")
	end

	return rules_allowed, rules_disallowed
end

---@param req web.IRequest
---@param res web.IResponse
---@param ctx sea.RequestContext
function RankingsResource:getRankings(req, res, ctx)
	local query = ctx.query

	local page = math.floor(tonumber(query.page) or 1)
	local leaderboard_id = math.max(tonumber(query.leaderboard_id) or 1)

	ctx.leaderboard_id = leaderboard_id

	---@type sea.RankingType
	local ranking_type = query.ranking_type or "rating"
	local leaderboard_name = ""

	local per_page = self.users_per_page
	ctx.users_per_page = per_page
	if ranking_type == "rating" then
		local lbs = self.leaderboards
		local lb = lbs:getLeaderboard(leaderboard_id)
		ctx.leaderboards = lbs:getLeaderboards()
		ctx.leaderboard = lb
		ctx.pages_count = math.ceil(lbs:getLeaderboardUsersCount(leaderboard_id) / per_page)
		page = math.min(page, ctx.pages_count)
		ctx.leaderboard_users = lbs:getLeaderboardUsersFull(leaderboard_id, per_page, (page - 1) * per_page)
		lbs:loadLeaderboardUsersHistory(leaderboard_id, ctx.leaderboard_users)
		leaderboard_name = ctx.leaderboard.name

		if lb then
			ctx.rules_allowed, ctx.rules_disallowed = self:getRules(lb)
		end

		for _, lb_user in ipairs(ctx.leaderboard_users) do
			lb_user.user.online = self.user_connections:isUserOnline(lb_user.user_id)
		end
	else
		local order = "chartplays_count"
		leaderboard_name = "Play Count"
		if ranking_type == "charts" then
			order = "chartmetas_count"
			leaderboard_name = "Charts"
		elseif ranking_type == "play_time" then
			order = "play_time"
			leaderboard_name = "Play Time"
		end
		ctx.pages_count = math.ceil(self.users:getUsersCount() / per_page)
		page = math.min(page, ctx.pages_count)
		ctx.users = self.users:getUsers(order, per_page, (page - 1) * per_page)

		for _, user in ipairs(ctx.users) do
			user.online = self.user_connections:isUserOnline(user.id)
		end
	end

	ctx.page_num = page
	ctx.ranking_type_tabs = self.ranking_type_tabs

	ctx.ranking_type = ranking_type
	ctx.display_leaderboards = ranking_type == "rating"

	ctx.meta_tags["title"] = ("%s Leaderboard - %s"):format(leaderboard_name, brand.name)

	self.views:render_send(res, "sea/leaderboards/http/rankings.etlua", ctx, true)
end

return RankingsResource
