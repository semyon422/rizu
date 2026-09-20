local class = require("class")
local ChartfileReader = require("rizu.library.ChartfileReader")
local path_util = require("path_util")

---@class rizu.library.PreparedHash
---@field chartmetas rizu.library.PreparedChartmetas
---@field chartdiffs sea.Chartdiff[]

---@class rizu.library.HashingTask
---@operator call: rizu.library.HashingTask
local HashingTask = class()

---@param fs fs.IFilesystem
---@param chartmetaGenerator rizu.library.ChartmetaGenerator
---@param chartdiffGenerator rizu.library.ChartdiffGenerator
---@param taskContext rizu.library.ITaskContext
function HashingTask:new(fs, chartmetaGenerator, chartdiffGenerator, taskContext)
	self.fs = fs
	self.chartmetaGenerator = chartmetaGenerator
	self.chartdiffGenerator = chartdiffGenerator
	self.taskContext = taskContext
end

---@param chartfile sea.ClientChartfile
---@param location_prefix string
---@param context table?
---@return rizu.library.PreparedHash?
---@return string?
function HashingTask:prepareChartfile(chartfile, location_prefix, context)
	local full_path = path_util.join(location_prefix, chartfile.path)
	local content, err = ChartfileReader.read(self.fs, full_path)
	if not content then
		return nil, "HashingTask: read error (" .. chartfile.path .. "): " .. tostring(err)
	end

	local chartmetas, err = self.chartmetaGenerator:prepare(chartfile, content, false, context)
	if not chartmetas then
		return nil, "HashingTask: chartmeta error (" .. chartfile.path .. "): " .. tostring(err)
	end

	---@type sea.Chartdiff[]
	local chartdiffs = {}
	for index, t in ipairs(chartmetas.chart_chartmetas or {}) do
		local existing = self.chartdiffGenerator.chartsRepo:selectDefaultChartdiff(chartmetas.hash, index)
		if t.chartmeta.mode == "mania" and not existing then
			local ok, absolute_err = xpcall(t.chart.layers.main.toAbsolute, debug.traceback, t.chart.layers.main)
			if not ok then
				self.taskContext:addError("HashingTask: toAbsolute error (" .. chartfile.path .. "): " .. tostring(absolute_err))
			else
				local ok_diff, chartdiff = xpcall(self.chartdiffGenerator.compute, debug.traceback, self.chartdiffGenerator, t.chart, 1)
				if not ok_diff then
					self.taskContext:addError("HashingTask: chartdiff error (" .. chartfile.path .. "): " .. tostring(chartdiff))
				else
					---@cast chartdiff sea.Chartdiff
					chartdiff.hash = chartmetas.hash
					chartdiff.index = index
					table.insert(chartdiffs, chartdiff)
				end
			end
		end
	end

	return {chartmetas = chartmetas, chartdiffs = chartdiffs}
end

---@param prepared rizu.library.PreparedHash
function HashingTask:applyPrepared(prepared)
	self.chartmetaGenerator:apply(prepared.chartmetas)
	local time = os.time()
	for _, chartdiff in ipairs(prepared.chartdiffs) do
		self.chartdiffGenerator.chartsRepo:createUpdateChartdiff(chartdiff, time)
	end
end

---@param chartfile sea.ClientChartfile
---@param location_prefix string
---@param context table?
---@return boolean?
---@return string?
function HashingTask:processChartfile(chartfile, location_prefix, context)
	local prepared, err = self:prepareChartfile(chartfile, location_prefix, context)
	if not prepared then
		self.taskContext:addError(err)
		return nil, err
	end
	self:applyPrepared(prepared)
	return true
end

return HashingTask
