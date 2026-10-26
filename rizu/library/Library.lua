local thread = require("thread")
local class = require("class")
local Observable = require("Observable")
local ThreadRemote = require("threadremote.ThreadRemote")
local ChartviewsRepo = require("rizu.library.repos.ChartviewsRepo")
local LocationsRepo = require("rizu.library.repos.LocationsRepo")
local Database = require("rizu.library.Database")
local Status = require("rizu.library.Status")
local Collections = require("rizu.library.Collections")
local Locations = require("rizu.library.Locations")
local ChartfilesRepo = require("rizu.library.repos.ChartfilesRepo")
local ChartplayHitsRepo = require("rizu.library.repos.ChartplayHitsRepo")
local Settings = require("rizu.config.Settings")
local ComputeDataProvider = require("rizu.library.ComputeDataProvider")
local RemoteCatalogLoader = require("rizu.library.RemoteCatalogLoader")
require("rizu.library.views")

local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local DifftablesRepo = require("sea.difftables.repos.DifftablesRepo")

---@class rizu.library.LibraryTask
---@field f fun()
---@field co thread?

---@return thread
local function getCurrentTaskCoroutine()
	return assert(coroutine.running(), "attempt to wait for a library task from outside a coroutine")
end

local function yieldTaskCompletion()
	coroutine.yield()
end

---@param co thread
local function resumeTaskCoroutine(co)
	assert(coroutine.resume(co))
end

---@class rizu.library.Library
---@operator call: rizu.library.Library
---@field onStatusChanged util.Observable
---@field onChartsChanged util.Observable
local Library = class()

---@param fs fs.IFilesystem
---@param workingDirectory string
---@param timer time.ITimer
function Library:new(fs, workingDirectory, timer)
	self.fs = fs
	self.workingDirectory = workingDirectory

	---@type rizu.library.LibraryTask[]
	self.tasks = {}

	---@type string[]
	self.errors = {}

	self.timer = assert(timer, "timer is required")

	self.onStatusChanged = Observable()
	-- Emitted after chart-processing batches commit queryable data.
	self.onChartsChanged = Observable()

	---@type rizu.library.TaskStatus
	self.status = {
		stage = "idle",
		current = 0,
		total = 0,
		errorCount = 0
	}
	self.stageStartTime = self.timer:getTime()
	self.is_sync = false

	self.database = Database(fs)

	self.chartsRepo = ChartsRepo(self.database.models)
	self.difftablesRepo = DifftablesRepo(self.database.models, "immediate")
	self.chartviewsRepo = ChartviewsRepo(self.database.models)
	self.locationsRepo = LocationsRepo(self.database.models)
	self.chartfilesRepo = ChartfilesRepo(self.database.models)
	self.chartplayHitsRepo = ChartplayHitsRepo(self.database.models)

	self.statusUpdate = Status(self.chartfilesRepo, self.chartsRepo)
	self.collections = Collections(self.chartfilesRepo, self.locationsRepo)
	self.locations = Locations(
		self.locationsRepo,
		self.chartfilesRepo,
		fs,
		workingDirectory,
		"mounted_charts"
	)

	self.computeDataProvider = ComputeDataProvider(
		self.chartfilesRepo,
		self.chartsRepo,
		self.locationsRepo,
		self.locations,
		fs
	)
end

---@param is_sync boolean
function Library:setSync(is_sync)
	self.is_sync = is_sync
end

---@param db_path string?
function Library:load(db_path)
	self.database:load(db_path)
	self.statusUpdate:update()

	self.locations:load()

	if self.is_sync then
		self.worker = self:createAndLoadWorker(self.workingDirectory)
		self.reader = self.worker
	else
		self.tr = ThreadRemote("rizu.library.Library", self)
		self.tr.task_handler.timeout = 60 * 60 * 24
		self.worker = self.tr:start(self.createAndLoadWorker, self.workingDirectory)
		-- Reads on their own thread and connection: the worker answers only between the items of a task.
		self.reader_tr = ThreadRemote("rizu.library.Library.reader", self)
		self.reader = self.reader_tr:start(self.createAndLoadWorker, self.workingDirectory)
	end
end

---@param workingDirectory string
function Library:createAndLoadWorker(workingDirectory)
	local Worker = require("rizu.library.Worker")
	local FunctionTimer = require("time.FunctionTimer")
	local Filesystem
	if love and love.filesystem and love.filesystem.getWorkingDirectory then
		Filesystem = require("fs.LoveFilesystem")
	else
		Filesystem = require("fs.LinuxFilesystem")
	end

	local getTime
	if love and love.timer and love.timer.getTime then
		getTime = love.timer.getTime
	else
		getTime = os.clock
	end

	local worker = Worker(self, Filesystem(), workingDirectory, FunctionTimer(getTime))
	worker:load()
	return worker
end

function Library:unload()
	if self.worker then
		self.worker:unload()
	end
	if self.reader and self.reader ~= self.worker then
		self.reader:unload()
	end
	if self.tr then
		self.tr:stop()
	end
	if self.reader_tr then
		self.reader_tr:stop()
	end
	self.database:unload()
end

Library.unload = thread.coro(Library.unload)

function Library:stopThread()
	if self.tr then
		self.tr:stopDetached()
		self.tr = nil
	end
	if self.reader_tr then
		self.reader_tr:stopDetached()
		self.reader_tr = nil
	end
end

---@param status rizu.library.TaskStatus
---@param errors string[]
function Library:notifyChartsChanged()
	self.onChartsChanged:send()
end

function Library:updateProgress(status, errors)
	local now = self.timer:getTime()
	if self.status.stage ~= status.stage then
		self.stageStartTime = now
	end

	self.status = status

	local elapsed = self.stageStartTime and (now - self.stageStartTime) or 0
	if elapsed > 0.5 and status.current > 0 then
		status.itemsPerSecond = status.current / elapsed
		if status.total > status.current then
			status.eta = (status.total - status.current) / status.itemsPerSecond
		end
	end

	for _, err in ipairs(errors) do
		print("Library error: " .. tostring(err))
		table.insert(self.errors, err)
	end

	self.onStatusChanged:send(self.status)
end

---@param locations_in_collections boolean
---@return rizu.library.Collections.TreeNode
function Library:getCollectionTree(locations_in_collections)
	return self.collections:getTree(locations_in_collections)
end

---@param chart rizu.library.LocatedChartview
function Library:enrichChartview(chart)
	self.locations:enrichChartview(chart)
end

---@param f fun()
---@param async boolean?
function Library:addTask(f, async)
	---@type rizu.library.LibraryTask
	local task = {f = f}
	table.insert(self.tasks, task)

	if async then
		task.co = getCurrentTaskCoroutine()
		yieldTaskCompletion()
	end
end

---@param path string?
---@param location_id integer
function Library:computeLocation(path, location_id)
	self:addTask(function()
		self.worker:computeLocation(path, location_id)
	end)
end

---@param path string?
---@param location_id integer
function Library:computeLocationAsync(path, location_id)
	self:addTask(function()
		self.worker:computeLocation(path, location_id)
	end, true)
end

function Library:computeChartdiffs()
	self:addTask(function()
		self.worker:computeChartdiffs()
	end)
end

---@param prefer_preview boolean
function Library:computeIncompleteChartdiffs(prefer_preview)
	self:addTask(function()
		self.worker:computeIncompleteChartdiffs(prefer_preview)
	end)
end

function Library:computeChartplays()
	self:addTask(function()
		self.worker:computeChartplays()
	end)
end

---Computes every local chartplay again, also the ones computed long ago, and stores its hits.
function Library:recomputeChartplays()
	self:addTask(function()
		self.worker:recomputeChartplays()
	end)
end

---Stores the hits of the local chartplays saved without them, see HitsTask. Once per
---ChartplayHitsRepo.hits_version, so plays whose chart or replay is gone are not retried at every start.
---@param settings rizu.config.Config
function Library:updateHits(settings)
	local key = Settings.keys.scores.hits_version
	local version = ChartplayHitsRepo.hits_version
	if settings:getNumber(key) == version then
		return
	end
	self:addTask(function()
		-- A stopped task leaves the rest to the next one.
		if self.worker:computeMissingHits() then
			settings:setNumber(key, version)
		end
	end)
end

function Library:stopTask()
	self.worker:stopTask()
end

Library.stopTask = thread.coro(Library.stopTask)

---@return boolean
function Library:hasChartfilesAsync()
	if self.is_sync or not self.worker then
		return self.chartfilesRepo:hasChartfiles()
	end

	local has_chartfiles
	self:addTask(function()
		has_chartfiles = self.worker:hasChartfiles()
	end, true)
	return has_chartfiles
end

---@param hashes string[]
---@return string[] hashes Of the given ones that are in the library.
function Library:getKnownHashesAsync(hashes)
	if self.is_sync or not self.reader then
		return self.chartfilesRepo:getKnownHashes(hashes)
	end
	return self.reader:getKnownHashes(hashes)
end

---Copies a downloaded remote catalog into the library. See `RemoteCatalogLoader.import`.
---@param path string
---@param base_url string
---@return integer? location_id
---@return string? err
function Library:importCatalogAsync(path, base_url)
	local location_id, err
	if self.is_sync or not self.worker then
		location_id, err = RemoteCatalogLoader.import(self.database.db, path, base_url)
	else
		self:addTask(function()
			location_id, err = self.worker:importCatalog(path, base_url)
		end, true)
	end
	if location_id then
		self.locations:selectLocations()
	end
	return location_id, err
end

---@class rizu.library.RemoteAssets
---@field chart_url string
---@field audio_url string The whole audio, encoded.
---@field audio_preview_url string A short part of the audio.
---@field background_url string?

---Where the files of a chart of a remote location are downloaded from.
---@param chartview rizu.library.LocatedChartview
---@return rizu.library.RemoteAssets? assets nil for a chart of a local location.
function Library:getRemoteAssets(chartview)
	local url = chartview.location_url
	if not url or not chartview.hash or not chartview.index then
		return
	end
	local row = self.database.models.remote_assets:find({hash = chartview.hash, index = chartview.index})
	if not row then
		return
	end
	return {
		chart_url = url .. "/" .. row.chart_path,
		audio_url = url .. "/" .. row.audio_path,
		audio_preview_url = url .. "/" .. row.audio_preview_path,
		background_url = row.background_path and url .. "/" .. row.background_path,
	}
end

---@param params rizu.library.ChartviewsRepo.QueryParams
---@return rizu.library.ChartviewsRepo.PackedQueryResult result
function Library:queryAsync(params)
	if self.is_sync or not self.reader then
		self.chartviewsRepo.params = params
		return self.chartviewsRepo:query()
	end
	return self.reader:query(params)
end

---@param params rizu.library.ChartviewsRepo.QueryParams
---@param chartview rizu.library.IChartviewBase
---@return rizu.library.ChartviewsRepo.PackedQueryResult result
function Library:getViewsAsync(params, chartview)
	if self.is_sync or not self.reader then
		self.chartviewsRepo.params = params
		return self.chartviewsRepo:getViews(chartview)
	end
	return self.reader:getViews(params, chartview)
end

---@param params rizu.library.ChartviewsRepo.QueryParams
---@param chartviews rizu.library.IChartviewBase[]
---@return (rizu.library.Chartview|false)[] result
function Library:getChartviewsAsync(params, chartviews)
	if self.is_sync or not self.reader then
		self.chartviewsRepo.params = params
		return self.chartviewsRepo:getChartviews(chartviews)
	end
	return self.reader:getChartviews(params, chartviews)
end

---@param chartdiff_key sea.ChartdiffKey
---@return sea.Chartplay[]
function Library:getChartplaysForChartdiffAsync(chartdiff_key)
	if self.is_sync or not self.reader then
		return self.chartsRepo:getChartplaysForChartdiff(chartdiff_key)
	end
	return self.reader:getChartplaysForChartdiff(chartdiff_key)
end

---@param chartmeta_key sea.ChartmetaKey
---@return sea.Chartplay[]
function Library:getChartplaysForChartmetaAsync(chartmeta_key)
	if self.is_sync or not self.reader then
		return self.chartsRepo:getChartplaysForChartmeta(chartmeta_key)
	end
	return self.reader:getChartplaysForChartmeta(chartmeta_key)
end

---Accuracies of chartplays in another system, see ChartplayHitsRepo:getAccuracies().
---@param ids integer[]
---@param timings integer
---@param subtimings integer
---@return {[integer]: number}
function Library:getAccuraciesAsync(ids, timings, subtimings)
	if self.is_sync or not self.reader then
		return self.chartplayHitsRepo:getAccuracies(ids, timings, subtimings)
	end
	return self.reader:getAccuracies(ids, timings, subtimings)
end

function Library:update()
	if self.tr then
		self.tr:update()
	end
	if self.reader_tr then
		self.reader_tr:update()
	end
	if not self.isProcessing and #self.tasks > 0 then
		self:process()
	end
end

function Library:process()
	if self.isProcessing then
		return
	end
	self.isProcessing = true

	local tasks = self.tasks
	---@type rizu.library.LibraryTask?
	local task = table.remove(tasks, 1)
	while task do
		task.f()
		if task.co then
			resumeTaskCoroutine(task.co)
		end

		task = table.remove(tasks, 1)
	end

	self.statusUpdate:update()

	self.isProcessing = false
end

Library.process = thread.coro(Library.process)

return Library
