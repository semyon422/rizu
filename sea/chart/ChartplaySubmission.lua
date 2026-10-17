local class = require("class")
local ComputeJobStatus = require("sea.compute.ComputeJobStatus")

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
---@return sea.ChartplaySubmissionResult?
---@return string?
function ChartplaySubmission:enqueueChartplay(peer, chartplay_values, chartdiff_values)
	local user, remote = peer.user, peer.remote
	local submission, err = self.chartplays:enqueue(user, os.time(), remote.compute_data_provider, chartplay_values, chartdiff_values)
	if not submission then
		return nil, err
	end
	return {
		status = ComputeJobStatus.create(
			submission.job,
			submission.job.state == "succeeded" and submission.chartplay or nil,
			self.chartplays.compute_jobs.chartplay_effects
				and self.chartplays.compute_jobs.chartplay_effects:isComplete(assert(submission.chartplay.id))
		),
		duplicate = submission.duplicate,
	}
end

---@param peer sea.Peer
---@param chartplay_values sea.Chartplay
---@param chartdiff_values sea.Chartdiff
---@return sea.Chartplay?
---@return string?
function ChartplaySubmission:submitChartplay(peer, chartplay_values, chartdiff_values)
	local user = peer.user
	local time = os.time()

	local ctx, err = self.chartplays:submit(user, time, peer.remote.compute_data_provider, chartplay_values, chartdiff_values)
	if not ctx then
		return nil, err
	end

	local chartplay = assert(ctx.chartplay)
	local effects = self.chartplays.compute_jobs.chartplay_effects
	if effects then
		while not effects:isComplete(assert(chartplay.id)) do
			local effect, failure = effects:process()
			if not effect then
				return nil, failure and failure.message or "chartplay effects did not complete"
			end
		end
	end
	return chartplay
end

return ChartplaySubmission
