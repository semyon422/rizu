local class = require("class")
local table_util = require("table_util")
local ReplayBase = require("sea.replays.ReplayBase")
local Chartplay = require("sea.chart.Chartplay")
local ChartdiffKey = require("sea.chart.ChartdiffKey")
local ComputeContext = require("sea.compute.ComputeContext")
local ComputeFailure = require("sea.compute.ComputeFailure")

---@class sea.ChartsComputer
---@operator call: sea.ChartsComputer
local ChartsComputer = class()

---@param compute_data_loader sea.ComputeDataLoader
---@param charts_repo sea.ChartsRepo
---@param replay_computer sea.IReplayComputer
---@param compute_version string
function ChartsComputer:new(compute_data_loader, charts_repo, replay_computer, compute_version)
	self.compute_data_loader = compute_data_loader
	self.charts_repo = charts_repo
	self.replay_computer = assert(replay_computer)
	self.compute_version = assert(compute_version)
end

---@param computed_at integer
---@param state sea.ComputeState
---@param limit integer?
---@return sea.Chartplay[]
function ChartsComputer:getChartplaysComputed(computed_at, state, limit)
	return self.charts_repo:getChartplaysComputed(computed_at, state, limit)
end

---@param computed_at integer
---@param state sea.ComputeState
---@return integer
function ChartsComputer:getChartplaysComputedCount(computed_at, state)
	return self.charts_repo:getChartplaysComputedCount(computed_at, state)
end

---@param chartplay sea.Chartplay
---@return {chartplay_computed: sea.ChartplayComputed, chartdiff: sea.Chartdiff, chartmeta: sea.Chartmeta}?
---@return string?
function ChartsComputer:computeChartplay(chartplay)
	local charts_repo = self.charts_repo
	local time = os.time()

	local ok, ret, err, failure = xpcall(self.computeChartplayNoUpdate, debug.traceback, self, chartplay, time)
	if not ok then
		failure = ComputeFailure.transient("internal_error", tostring(ret))
		ret = nil
		err = ComputeFailure.format(failure)
	end

	if not ret then
		if failure and failure.kind == "permanent" then
			chartplay.compute_state = "invalid"
			chartplay.computed_at = time
			charts_repo:updateChartplay(chartplay)
		end
		return nil, err
	end

	chartplay.compute_state = "valid"
	chartplay.computed_at = time
	charts_repo:updateChartplay(chartplay)

	return ret
end

---@param chartplay sea.Chartplay
---@param time integer
---@return {chartplay_computed: sea.ChartplayComputed, chartdiff: sea.Chartdiff, chartmeta: sea.Chartmeta}?
---@return string?
---@return sea.ComputeFailure?
function ChartsComputer:computeChartplayNoUpdate(chartplay, time)
	local charts_repo = self.charts_repo
	local compute_data_loader = self.compute_data_loader

	local chart_file_data, err = compute_data_loader:requireChart(chartplay.hash)
	if not chart_file_data then
		return nil, "require chart: " .. err
	end
	local replay_and_data
	replay_and_data, err = compute_data_loader:requireReplay(chartplay.replay_hash)
	if not replay_and_data then
		return nil, "require replay: " .. err
	end

	local compute_chartplay = setmetatable(table_util.sub(chartplay, table_util.keys(Chartplay.struct)), Chartplay)
	---@type sea.ComputeRequest
	local request = {
		version = self.compute_version,
		chartplay = compute_chartplay,
		chartdiff = self.charts_repo:getChartdiffByChartdiffKey(chartplay) or {},
		chart_name = chart_file_data.name,
		chart_data = chart_file_data.data,
		replay_data = replay_and_data.data,
	}
	local result
	local failure
	result, failure = self.replay_computer:compute(request)
	if not result then
		failure = failure or ComputeFailure.transient("compute_failed", "compute failed without a classified error")
		return nil, ComputeFailure.format(failure), failure
	end
	local chartmeta = charts_repo:createUpdateChartmeta(result.chartmeta, time)
	if result.default_chartdiff then
		charts_repo:createUpdateChartdiff(result.default_chartdiff, time)
	end
	local chartdiff = charts_repo:createUpdateChartdiff(result.chartdiff, time)
	local chartplay_computed = assert(result.chartplay_computed)
	chartplay:importChartplayBase(replay_and_data.replay)
	chartplay:importChartplayComputed(chartplay_computed)

	return {
		chartplay_computed = chartplay_computed,
		chartdiff = chartdiff,
		chartmeta = chartmeta,
	}
end

---@param name string
---@param data string
---@param time integer
---@return boolean?
---@return string?
function ChartsComputer:computeChartfile(name, data, time)
	local charts_repo = self.charts_repo

	local ctx = ComputeContext()

	local ok, err = ctx:fromFileData(name, data, 1)
	if not ok then
		return nil, "from file data: " .. err
	end

	local chart_chartmetas = assert(ctx.chart_chartmetas)

	for _, chart_chartmeta in ipairs(chart_chartmetas) do
		local chartmeta = charts_repo:createUpdateChartmeta(chart_chartmeta.chartmeta, time)

		local default_chartdiff_key = ChartdiffKey()
		default_chartdiff_key.hash = chartmeta.hash
		default_chartdiff_key.index = chartmeta.index
		default_chartdiff_key.rate = 1
		default_chartdiff_key.modifiers = {}
		default_chartdiff_key.mode = "mania"

		local default_chartdiff = charts_repo:getChartdiffByChartdiffKey(default_chartdiff_key)
		if not default_chartdiff then
			local chartdiff = ctx:computeBase(ReplayBase())
			chartdiff = charts_repo:createUpdateChartdiff(chartdiff, time)
		end
	end

	return true
end

return ChartsComputer
