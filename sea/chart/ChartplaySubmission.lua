local class = require("class")

---@class sea.ChartplaySubmission
---@operator call: sea.ChartplaySubmission
local ChartplaySubmission = class()

---@param chartplays sea.Chartplays
---@param leaderboards sea.Leaderboards
---@param users sea.Users
---@param dans sea.Dans
---@param user_activity_graph sea.UserActivityGraph
---@param external_ranked sea.ExternalRanked
function ChartplaySubmission:new(chartplays, leaderboards, users, dans, user_activity_graph, external_ranked)
	self.chartplays = chartplays
	self.leaderboards = leaderboards
	self.users = users
	self.dans = dans
	self.user_activity_graph = user_activity_graph
	self.external_ranked = external_ranked
end

---@param peer sea.Peer
---@param chartplay_values sea.Chartplay
---@param chartdiff_values sea.Chartdiff
---@return sea.Chartplay?
---@return string?
function ChartplaySubmission:submitChartplay(peer, chartplay_values, chartdiff_values)
	local user, remote = peer.user, peer.remote
	local time = os.time()

	local ctx, err = self.chartplays:submit(user, time, remote.compute_data_provider, chartplay_values, chartdiff_values)
	if not ctx then
		return nil, err
	end

	local chartplay = assert(ctx.chartplay)
	local chartmeta = assert(ctx.chartmeta)

	self.external_ranked:submit(chartmeta, time)

	if not chartplay.custom then
		self.leaderboards:addChartplay(chartplay)
	end

	self.user_activity_graph:increaseUserActivity(user.id, time)

	user = self.users:getUser(user.id)

	user.latest_activity = time
	user.play_time = user.play_time + ctx.chartdiff.duration
	user.chartplays_upload_size = user.chartplays_upload_size + ctx.replays_size
	user.chartfiles_upload_size = user.chartfiles_upload_size + ctx.charts_size
	user.chartplays_count = self.chartplays.charts_repo:getUserChartplaysCount(user.id)
	user.chartmetas_count = self.chartplays.charts_repo:getUserChartmetasCount(user.id)
	user.chartdiffs_count = self.chartplays.charts_repo:getUserChartdiffsCount(user.id)

	self.users.users_repo:updateUser(user)

	if self.dans:isDan(chartdiff_values) then
		local dan_clear, err = self.dans:submit(user, chartplay, chartdiff_values, time)
		remote:print(dan_clear and "dan cleared" or err)
	end

	local leaderboard_users = self.leaderboards:getUserLeaderboardUsers(user)
	if leaderboard_users then
		remote.client:setLeaderboardUsers(leaderboard_users)
	end

	return chartplay
end

return ChartplaySubmission
