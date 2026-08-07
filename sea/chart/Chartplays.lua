local class = require("class")
local table_util = require("table_util")
local Chartfile = require("sea.chart.Chartfile")
local Chartplay = require("sea.chart.Chartplay")
local Chartdiff = require("sea.chart.Chartdiff")
local ChartplaysAccess = require("sea.chart.access.ChartplaysAccess")
local ComputeInputLoader = require("sea.compute.ComputeInputLoader")

---@class sea.Chartplays
---@operator call: sea.Chartplays
local Chartplays = class()

---@param charts_repo sea.ChartsRepo
---@param chartfiles_repo sea.ChartfilesRepo
---@param compute_data_provider sea.IComputeDataProvider
---@param charts_storage sea.IKeyValueStorage
---@param replays_storage sea.IKeyValueStorage
---@param replay_computer sea.IReplayComputer
---@param compute_version string
function Chartplays:new(
	charts_repo,
	chartfiles_repo,
	compute_data_provider,
	charts_storage,
	replays_storage,
	replay_computer,
	compute_version
)
	self.charts_repo = charts_repo
	self.chartfiles_repo = chartfiles_repo
	self.charts_storage = charts_storage
	self.replays_storage = replays_storage
	self.compute_input_loader = ComputeInputLoader(compute_data_provider, charts_storage, replays_storage)
	self.replay_computer = assert(replay_computer)
	self.compute_version = assert(compute_version)
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

---@param user_id integer
---@param time integer
---@param chartplay_values sea.Chartplay
---@return sea.Chartplay
function Chartplays:getCreateChartplay(user_id, time, chartplay_values)
	local charts_repo = self.charts_repo
	local chartplay = charts_repo:getChartplayByReplayHash(chartplay_values.replay_hash)
	if not chartplay then
		assert(not chartplay_values.id)
		chartplay_values.user_id = user_id
		chartplay_values.submitted_at = time
		chartplay_values.computed_at = time
		chartplay_values.compute_state = "new"
		chartplay = charts_repo:createChartplay(chartplay_values)
	end
	assert(chartplay_values:equalsChartplay(chartplay))
	return chartplay
end

---@param user sea.User
---@param time integer
---@param compute_data_provider sea.IComputeDataProvider
---@param chartplay_values sea.Chartplay
---@param chartdiff_values sea.Chartdiff
---@return {chartplay: sea.Chartplay, chartmeta: sea.Chartmeta, chartdiff: sea.Chartdiff, result: sea.ComputeResult, charts_size: integer, replays_size: integer}?
---@return string?
function Chartplays:submit(user, time, compute_data_provider, chartplay_values, chartdiff_values)
	if user:isAnon() then
		return nil, "anon user"
	end

	local charts_repo = self.charts_repo
	local last_chartplay = charts_repo:getRecentChartplays(user.id, 1)
	local can, err = self.chartplays_access:canSubmit(user, time, last_chartplay[1])
	if not can then
		return nil, "can submit: " .. err
	end

	local chartplay = self:getCreateChartplay(user.id, time, chartplay_values)
	local input_loader = self.compute_input_loader
	local replay_data, replay_uploaded
	replay_data, replay_uploaded, err = input_loader:loadReplay(compute_data_provider, chartplay.replay_hash)
	if not replay_data then
		chartplay.compute_state = "invalid"
		charts_repo:updateChartplay(chartplay)
		return nil, "load replay: " .. err
	end

	local chart_file, chart_uploaded
	chart_file, chart_uploaded, err = input_loader:loadChart(compute_data_provider, chartplay.hash)
	if not chart_file then
		chartplay.compute_state = "invalid"
		charts_repo:updateChartplay(chartplay)
		return nil, "load chart: " .. err
	end

	local chartfile = self.chartfiles_repo:getChartfileByHash(chartplay.hash)
	if not chartfile then
		local chartfile_values = Chartfile()
		chartfile_values.hash = chartplay.hash
		chartfile_values.creator_id = user.id
		chartfile_values.compute_state = "new"
		chartfile_values.computed_at = time
		chartfile_values.submitted_at = time
		chartfile_values.name = chart_file.name
		chartfile_values.size = #chart_file.data
		self.chartfiles_repo:createChartfile(chartfile_values)
	end

	local compute_chartplay = setmetatable(table_util.sub(chartplay, table_util.keys(Chartplay.struct)), Chartplay)
	local compute_chartdiff = setmetatable(table_util.sub(chartdiff_values, table_util.keys(Chartdiff.struct)), Chartdiff)
	---@type sea.ComputeRequest
	local request = {
		version = self.compute_version,
		chartplay = compute_chartplay,
		chartdiff = compute_chartdiff,
		chart_name = chart_file.name,
		chart_data = chart_file.data,
		replay_data = replay_data,
	}
	local result
	result, err = self.replay_computer:compute(request)
	if not result then
		chartplay.compute_state = "invalid"
		chartplay.computed_at = time
		charts_repo:updateChartplay(chartplay)
		return nil, err
	end

	local chartmeta = charts_repo:createUpdateChartmeta(result.chartmeta, time)
	if result.default_chartdiff then
		charts_repo:createUpdateChartdiff(result.default_chartdiff, time)
	end
	if chartplay.custom then
		result.chartdiff.custom_user_id = user.id
	else
		chartplay:importChartplayComputed(assert(result.chartplay_computed))
	end
	local chartdiff = charts_repo:createUpdateChartdiff(result.chartdiff, time)
	chartplay.compute_state = "valid"
	chartplay.computed_at = time
	charts_repo:updateChartplay(chartplay)

	return {
		chartplay = chartplay,
		chartmeta = chartmeta,
		chartdiff = chartdiff,
		result = result,
		charts_size = chart_uploaded and #chart_file.data or 0,
		replays_size = replay_uploaded and #replay_data or 0,
	}
end

return Chartplays
