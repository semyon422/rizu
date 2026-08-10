local class = require("class")
local table_util = require("table_util")
local Chartdiff = require("sea.chart.Chartdiff")
local ChartplaysAccess = require("sea.chart.access.ChartplaysAccess")
local ComputeInputLoader = require("sea.compute.ComputeInputLoader")
local ComputeFailure = require("sea.compute.ComputeFailure")

---@class sea.Chartplays
---@operator call: sea.Chartplays
local Chartplays = class()

---@param charts_repo sea.ChartsRepo
---@param chartfiles_repo sea.ChartfilesRepo
---@param compute_data_provider sea.IComputeDataProvider
---@param charts_storage sea.IKeyValueStorage
---@param replays_storage sea.IKeyValueStorage
---@param compute_jobs sea.ComputeJobs
function Chartplays:new(
	charts_repo,
	chartfiles_repo,
	compute_data_provider,
	charts_storage,
	replays_storage,
	compute_jobs
)
	self.charts_repo = charts_repo
	self.chartfiles_repo = chartfiles_repo
	self.charts_storage = charts_storage
	self.replays_storage = replays_storage
	self.compute_input_loader = ComputeInputLoader(compute_data_provider, charts_storage, replays_storage)
	self.compute_jobs = assert(compute_jobs)
	self.chartplays_access = ChartplaysAccess()
end

---@param user sea.User
---@param replay_hash string
---@return string?
---@return string?
function Chartplays:getReplayFile(user, replay_hash)
	if user:isAnon() then
		return nil, "anon user"
	end
	return self.replays_storage:get(replay_hash)
end

---@return sea.Chartplay[]
function Chartplays:getChartplays()
	return self.charts_repo:getChartplays()
end

---@param id integer
---@return sea.Chartplay?
function Chartplays:getChartplay(id)
	return self.charts_repo:getChartplay(id)
end

---@param chartmeta_key sea.ChartmetaKey
---@return sea.Chartplay[]?
---@return string?
function Chartplays:getChartplaysForChartmeta(chartmeta_key)
	return self.charts_repo:getChartplaysForChartmeta(chartmeta_key)
end

---@param chartdiff_key sea.ChartdiffKey
---@return sea.Chartplay[]?
---@return string?
function Chartplays:getChartplaysForChartdiff(chartdiff_key)
	return self.charts_repo:getChartplaysForChartdiff(chartdiff_key)
end

---@param user sea.User
---@param chartmeta_key sea.ChartmetaKey
---@return sea.Chartplay[]?
---@return string?
function Chartplays:getBestChartplaysForChartmeta(user, chartmeta_key)
	if user:isAnon() then
		return nil, "anon user"
	end
	return self.charts_repo:getBestChartplaysForChartmeta(chartmeta_key)
end

---@param user sea.User
---@param chartdiff_key sea.ChartdiffKey
---@return sea.Chartplay[]?
---@return string?
function Chartplays:getBestChartplaysForChartdiff(user, chartdiff_key)
	if user:isAnon() then
		return nil, "anon user"
	end
	return self.charts_repo:getBestChartplaysForChartdiff(chartdiff_key)
end

---@class sea.ComputeSubmission
---@field chartplay sea.Chartplay
---@field job sea.ComputeJob
---@field charts_size integer
---@field replays_size integer
---@field duplicate boolean

---@param user sea.User
---@param time integer
---@param compute_data_provider sea.IComputeDataProvider
---@param chartplay_values sea.Chartplay
---@param chartdiff_values sea.Chartdiff
---@return sea.ComputeSubmission?
---@return string?
---@return sea.ComputeFailure?
function Chartplays:enqueue(user, time, compute_data_provider, chartplay_values, chartdiff_values)
	if user:isAnon() then
		return nil, "anon user"
	end

	local charts_repo = self.charts_repo
	local existing_chartplay = charts_repo:getChartplayByReplayHash(chartplay_values.replay_hash)
	if existing_chartplay and existing_chartplay.user_id ~= user.id then
		return nil, "replay already submitted"
	end
	if not existing_chartplay then
		local last_chartplay = charts_repo:getRecentChartplays(user.id, 1)
		local can, err = self.chartplays_access:canSubmit(user, time, last_chartplay[1])
		if not can then
			return nil, "can submit: " .. err
		end
	end

	local input_loader = self.compute_input_loader
	local replay_data, replay_uploaded
	replay_data, replay_uploaded, err = input_loader:loadReplay(compute_data_provider, chartplay_values.replay_hash)
	if not replay_data then
		---@cast err sea.ComputeFailure
		return nil, "load replay: " .. err.message, err
	end

	local chart_file, chart_uploaded
	chart_file, chart_uploaded, err = input_loader:loadChart(compute_data_provider, chartplay_values.hash)
	if not chart_file then
		---@cast err sea.ComputeFailure
		return nil, "load chart: " .. err.message, err
	end

	local compute_chartdiff = setmetatable(table_util.sub(chartdiff_values, table_util.keys(Chartdiff.struct)), Chartdiff)
	local chartplay, job, duplicate = self.compute_jobs:createSubmission(
		user.id,
		time,
		chartplay_values,
		compute_chartdiff,
		chart_file.name,
		#chart_file.data
	)
	return {
		chartplay = chartplay,
		job = job,
		charts_size = chart_uploaded and #chart_file.data or 0,
		replays_size = replay_uploaded and #replay_data or 0,
		duplicate = duplicate,
	}
end

---@param user sea.User
---@param time integer
---@param compute_data_provider sea.IComputeDataProvider
---@param chartplay_values sea.Chartplay
---@param chartdiff_values sea.Chartdiff
---@return {chartplay: sea.Chartplay, chartmeta: sea.Chartmeta, chartdiff: sea.Chartdiff, result: sea.ComputeResult?, charts_size: integer, replays_size: integer}?
---@return string?
---@return sea.ComputeFailure?
function Chartplays:submit(user, time, compute_data_provider, chartplay_values, chartdiff_values)
	local submission, err, enqueue_failure = self:enqueue(user, time, compute_data_provider, chartplay_values, chartdiff_values)
	if not submission then
		return nil, err, enqueue_failure
	end

	local charts_repo = self.charts_repo
	local chartplay = submission.chartplay
	local job = submission.job
	if job.state == "succeeded" then
		chartplay = assert(charts_repo:getChartplay(assert(chartplay.id)))
		return {
			chartplay = chartplay,
			chartmeta = assert(charts_repo:getChartmetaByHashIndex(chartplay.hash, chartplay.index)),
			chartdiff = assert(charts_repo:getChartdiffByChartdiffKey(chartplay)),
			result = nil,
			charts_size = 0,
			replays_size = 0,
		}
	end

	local result, failure = self.compute_jobs:process(assert(job.id))
	if not result then
		---@cast failure sea.ComputeFailure
		return nil, ComputeFailure.format(failure), failure
	end

	chartplay = assert(charts_repo:getChartplay(assert(chartplay.id)))
	local chartmeta = assert(charts_repo:getChartmetaByHashIndex(chartplay.hash, chartplay.index))
	local chartdiff = assert(charts_repo:getChartdiffByChartdiffKey(chartplay))

	return {
		chartplay = chartplay,
		chartmeta = chartmeta,
		chartdiff = chartdiff,
		result = result,
		charts_size = submission.charts_size,
		replays_size = submission.replays_size,
	}
end

return Chartplays
