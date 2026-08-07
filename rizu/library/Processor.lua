local LocationsRepo = require("rizu.library.repos.LocationsRepo")
local Finder = require("rizu.library.Finder")
local FileCacheGenerator = require("rizu.library.generators.FileCacheGenerator")
local IidxCatalog = require("chart.format.iidx.Catalog")
local IidxDecodeContext = require("chart.format.iidx.DecodeContext")
local IidxFileCacheGenerator = require("rizu.library.iidx.FileCacheGenerator")
local ChartmetaGenerator = require("rizu.library.generators.ChartmetaGenerator")
local ChartdiffGenerator = require("rizu.library.generators.ChartdiffGenerator")
local ChartfilesRepo = require("rizu.library.repos.ChartfilesRepo")
local ChartFactory = require("chart.format.notechart.ChartFactory")
local ChartfileReader = require("rizu.library.ChartfileReader")
local DifficultyModel = require("chart.difficulty.DifficultyModel")
local Locations = require("rizu.library.Locations")
local ComputeDataProvider = require("rizu.library.ComputeDataProvider")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local ComputeDataLoader = require("sea.compute.ComputeDataLoader")
local ChartsComputer = require("sea.compute.ChartsComputer")
local ReplayComputer = require("sea.compute.ReplayComputer")
local ComputeVersion = require("sea.compute.ComputeVersion")
local HashingTask = require("rizu.library.tasks.HashingTask")
local DifficultyTask = require("rizu.library.tasks.DifficultyTask")
local ScoreTask = require("rizu.library.tasks.ScoreTask")
local TaskContext = require("rizu.library.tasks.TaskContext")
local BatchProcessor = require("rizu.library.tasks.BatchProcessor")
local class = require("class")
local path_util = require("path_util")

---@class rizu.library.Processor
---@operator call: rizu.library.Processor
local Processor = class()

---@param db rizu.library.Database
---@param fs fs.IFilesystem
---@param workingDirectory string
---@param timer time.ITimer
function Processor:new(db, fs, workingDirectory, timer)
	self.needStop = false
	---@type rizu.library.TaskStage
	self.stage = "idle"
	---@type string?
	self.stage_label = nil
	self.errorCount = 0
	self.errors = {}
	self.fs = fs

	self.difficultyModel = DifficultyModel()

	self.db = db

	self.chartsRepo = ChartsRepo(self.db.models, self.difficultyModel.registry.fields)
	self.locationsRepo = LocationsRepo(self.db.models)
	self.chartfilesRepo = ChartfilesRepo(self.db.models)

	self.finder = Finder(self.fs)

	self.taskContext = TaskContext(self)

	self.fileCacheGenerator = FileCacheGenerator(self.chartfilesRepo, self.finder, self.taskContext)
	self.iidxFileCacheGenerator = IidxFileCacheGenerator(self.chartfilesRepo, self.fs, self.taskContext)
	self.chartdiffGenerator = ChartdiffGenerator(self.chartsRepo, self.difficultyModel)
	self.chartmetaGenerator = ChartmetaGenerator(self.chartsRepo, self.chartfilesRepo, ChartFactory)

	self.hashingTask = HashingTask(self.fs, self.chartmetaGenerator, self.chartdiffGenerator, self.taskContext)
	self.difficultyTask = DifficultyTask(self.difficultyModel, self.chartdiffGenerator, self.chartsRepo, self.taskContext, timer, function(hash)
		return self:getChartsByHash(hash)
	end)

	self.locations = Locations(
		self.locationsRepo,
		self.chartfilesRepo,
		self.fs,
		workingDirectory,
		"mounted_charts"
	)

	self.computeDataProvider = ComputeDataProvider(
		self.chartfilesRepo,
		self.chartsRepo,
		self.locationsRepo,
		self.locations,
		self.fs
	)
	self.computeDataLoader = ComputeDataLoader(self.computeDataProvider)

	self.chartsComputer = ChartsComputer(
		self.computeDataLoader,
		self.chartsRepo,
		ReplayComputer(),
		ComputeVersion.current()
	)
	self.scoreTask = ScoreTask(self.chartsRepo, self.chartsComputer, self.taskContext, timer)
	self.timer = timer
end

function Processor:begin()
	self.db.orm:begin()
end

function Processor:commit()
	self.db.orm:commit()
end

----------------------------------------------------------------

function Processor:resetProgress()
	self.chartfiles_count = 0
	self.chartfiles_current = 0
	self.stage = "idle"
	self.stage_label = nil
	self.errorCount = 0
	---@type string[]
	self.errors = {}
end

function Processor:addError(err)
	table.insert(self.errors, tostring(err))
	self:checkProgress()
end

function Processor:checkProgress() end

---@param path string?
---@param location_id number
function Processor:computeLocation(path, location_id)
	print("start caching", path, location_id)

	local location = self.locationsRepo:selectLocationById(location_id)
	if not location then
		self:addError("location not found")
		return
	end

	local location_prefix = self.locations:getPrefix(location)
	local is_iidx_location = IidxCatalog.isLocation(self.fs, location_prefix)
	print("location type", is_iidx_location and "iidx" or "regular", location_prefix)

	self:resetProgress()

	self.taskContext:startStage("scanning", 0)

	self:begin()
	print("fileCacheGenerator.scan", path, location_id, location_prefix)
	if is_iidx_location then
		self.iidxFileCacheGenerator:scan(path, location_id, location_prefix)
	else
		self.fileCacheGenerator:scan(path, location_id, location_prefix)
	end
	self:commit()

	self.stage = "hashing"
	self:checkProgress()

	---@type sea.ClientChartfileSet?, integer?, string?
	local chartfile_set, set_id, unhashed_path
	local dir, name = Finder.get_dir_name(path)
	if name then
		chartfile_set = self.chartfilesRepo:selectChartfileSet(dir, name, location_id)
	end
	if chartfile_set then
		set_id = chartfile_set.id
		print("chartfile_set.id = " .. set_id)
	else
		unhashed_path = path
	end

	print("chartfilesRepo.selectUnhashedChartfiles", unhashed_path, location_id, set_id)
	local chartfiles = self.chartfilesRepo:selectUnhashedChartfiles(unhashed_path, location_id, set_id)
	print(("hashing: %d chartfiles queued"):format(#chartfiles))

	local batchProcessor = BatchProcessor(self.taskContext, self.timer, is_iidx_location and 1 or 100)
	local hashed_count = 0
	batchProcessor:process(chartfiles, "hashing", #chartfiles, function(chartfile)
		local context
		if is_iidx_location then
			local song = self.iidxFileCacheGenerator:getSongByChartfileName(chartfile.name)
			context = {
				song_id = song and song.song_id,
				iidx_song = song,
			}
		end
		local start_time = self.timer:getTime()
		self.hashingTask:processChartfile(chartfile, location_prefix, context)
		hashed_count = hashed_count + 1
		if is_iidx_location then
			print(("iidx hashing: done %d/%d %s %.2fs"):format(
				hashed_count,
				#chartfiles,
				chartfile.name,
				self.timer:getTime() - start_time
			))
		end
		return chartfile.name
	end)
	print("caching complete", path, location_id)

	self.taskContext:finish()
end

---@param hash string
---@return chart.Chart[]?
---@return string?
function Processor:getChartsByHash(hash)
	local chartfile = self.chartfilesRepo:selectChartfileByHash(hash)
	if not chartfile then
		return nil, "chartfile not found for " .. hash
	end

	local location = self.locationsRepo:selectLocationById(chartfile.location_id)
	if not location then
		return nil, "location not found"
	end

	local prefix = self.locations:getPrefix(location)

	local full_path = path_util.join(prefix, chartfile.path)
	local data, err = ChartfileReader.read(self.fs, full_path)
	if not data then
		return nil, err
	end

	local chart_chartmetas, err = ChartFactory:getCharts(
		chartfile.name,
		data,
		nil,
		IidxDecodeContext.fromLocation(self.fs, prefix, chartfile.name)
	)
	if not chart_chartmetas then
		return nil, err
	end

	---@type chart.Chart[]
	local charts = {}
	for i, t in ipairs(chart_chartmetas) do
		charts[i] = t.chart
	end

	return charts
end

function Processor:computeChartdiffs()
	self.difficultyTask:computeMissing()
end

---@param prefer_preview boolean
function Processor:computeIncompleteChartdiffs(prefer_preview)
	self.difficultyTask:computeIncomplete(prefer_preview)
end

function Processor:computeChartplays()
	self.scoreTask:computeAll()
end

return Processor
