local class = require("class")
local Processor = require("rizu.library.Processor")
local Database = require("rizu.library.Database")
local ChartviewsRepo = require("rizu.library.repos.ChartviewsRepo")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")

---@class rizu.library.Worker
---@operator call: rizu.library.Worker
---@field library rizu.library.Library
---@field db rizu.library.Database
---@field processor rizu.library.Processor
---@field errors string[]
---@field needStop boolean?
local Worker = class()

---@param library rizu.library.Library
---@param fs fs.IFilesystem
---@param workingDirectory string
---@param timer time.ITimer
function Worker:new(library, fs, workingDirectory, timer)
	self.library = library
	self.db = Database(fs)
	self.processor = Processor(self.db, fs, workingDirectory, timer)
	self.errors = {}
end

function Worker:load()
	self.db:load()

	function self.processor.checkProgress(processor)
		if #processor.errors > 0 then
			for _, err in ipairs(processor.errors) do
				table.insert(self.errors, err)
			end
			processor.errors = {}
		end

		self.library:updateProgress({
			stage = processor.stage,
			total = processor.chartfiles_count,
			current = processor.chartfiles_current,
			label = processor.stage_label,
			errorCount = processor.errorCount
		}, self.errors)
		self.errors = {}

		if self.needStop then
			processor.needStop = true
			self.needStop = false
		end
	end
end

function Worker:unload()
	self.db:unload()
end

function Worker:stopTask()
	self.needStop = true
end

---@param path string?
---@param location_id integer
function Worker:computeLocation(path, location_id)
	self.processor:computeLocation(path, location_id)
end

function Worker:computeChartdiffs()
	self.processor:computeChartdiffs()
end

---@param prefer_preview boolean
function Worker:computeIncompleteChartdiffs(prefer_preview)
	self.processor:computeIncompleteChartdiffs(prefer_preview)
end

function Worker:computeChartplays()
	self.processor:computeChartplays()
end

---@param params rizu.library.ChartviewsRepo.QueryParams
---@return rizu.library.ChartviewsRepo.PackedQueryResult
function Worker:query(params)
	local repo = ChartviewsRepo(self.db.models)
	repo.params = params
	return repo:query()
end

---@param params rizu.library.ChartviewsRepo.QueryParams
---@param chartview rizu.library.IChartviewBase
---@return rizu.library.ChartviewsRepo.PackedQueryResult
function Worker:getViews(params, chartview)
	local repo = ChartviewsRepo(self.db.models)
	repo.params = params
	return repo:getViews(chartview)
end

---@param params rizu.library.ChartviewsRepo.QueryParams
---@param _chartview rizu.library.IChartviewBase
---@return rizu.library.Chartview?
function Worker:getChartview(params, _chartview)
	local repo = ChartviewsRepo(self.db.models)
	repo.params = params
	return repo:getChartview(_chartview)
end

---@param chartdiff_key sea.ChartdiffKey
---@return sea.Chartplay[]
function Worker:getChartplaysForChartdiff(chartdiff_key)
	local repo = ChartsRepo(self.db.models)
	return repo:getChartplaysForChartdiff(chartdiff_key)
end

---@param chartmeta_key sea.ChartmetaKey
---@return sea.Chartplay[]
function Worker:getChartplaysForChartmeta(chartmeta_key)
	local repo = ChartsRepo(self.db.models)
	return repo:getChartplaysForChartmeta(chartmeta_key)
end

return Worker
