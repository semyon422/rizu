local class = require("class")

---@class sea.SubmissionServerRemote: sea.IServerRemoteContext
---@operator call: sea.SubmissionServerRemote
local SubmissionServerRemote = class()

---@param chartplay_submission sea.ChartplaySubmission
---@param chartplays sea.Chartplays
function SubmissionServerRemote:new(chartplay_submission, chartplays)
	self.chartplay_submission = chartplay_submission
	self.chartplays = chartplays
end

---@param chartplay sea.Chartplay
---@param chartdiff sea.Chartdiff
---@return sea.ChartplaySubmissionResult?
---@return string?
function SubmissionServerRemote:submitChartplay(chartplay, chartdiff)
	return self.chartplay_submission:enqueueChartplay(self.peer, chartplay, chartdiff)
end

---@param job_id integer
---@return sea.ComputeJobStatus?
---@return string?
function SubmissionServerRemote:getChartplaySubmission(job_id)
	return self.chartplays.compute_jobs:getStatus(self.user.id, job_id)
end

---@param chartmeta_key sea.ChartmetaKey
---@return sea.Chartplay[]?
---@return string?
function SubmissionServerRemote:getBestChartplaysForChartmeta(chartmeta_key)
	return self.chartplays:getBestChartplaysForChartmeta(self.user, chartmeta_key)
end

---@param chartdiff_key sea.ChartdiffKey
---@return sea.Chartplay[]?
---@return string?
function SubmissionServerRemote:getBestChartplaysForChartdiff(chartdiff_key)
	return self.chartplays:getBestChartplaysForChartdiff(self.user, chartdiff_key)
end

---@param replay_hash string
---@return string?
---@return string?
function SubmissionServerRemote:getReplayFile(replay_hash)
	return self.chartplays:getReplayFile(self.user, replay_hash)
end

return SubmissionServerRemote
