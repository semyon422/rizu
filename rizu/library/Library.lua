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
local ComputeDataProvider = require("rizu.library.ComputeDataProvider")
require("rizu.library.views")

local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local DifftablesRepo = require("sea.difftables.repos.DifftablesRepo")

---@class rizu.library.LibraryTask
---@field f fun()
---@field co thread?

---@class rizu.library.Library
---@operator call: rizu.library.Library
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

	---@type rizu.library.TaskStatus
	self.status = {
		stage = "idle",
		current = 0,
		total = 0,
		errorCount = 0
	}
	self.stageStartTime = self.timer:getTime()
	self.is_sync = false

	local migrations = {}
	setmetatable(migrations, {__index = function(_, k)
		local path = ("rizu/library/sql/migrate%s.sql"):format(k)
		if self.fs:getInfo(path) then
			return self.fs:read(path)
		end
	end})

	self.database = Database(fs, migrations)

	self.chartsRepo = ChartsRepo(self.database.models)
	self.difftablesRepo = DifftablesRepo(self.database.models)
	self.chartviewsRepo = ChartviewsRepo(self.database.models)
	self.locationsRepo = LocationsRepo(self.database.models)
	self.chartfilesRepo = ChartfilesRepo(self.database.models)

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
	else
		self.tr = ThreadRemote("rizu.library.Library", self)
		self.tr.task_handler.timeout = 60 * 60 * 24
		self.worker = self.tr:start(self.createAndLoadWorker, self.workingDirectory)
	end
end

---@param workingDirectory string
function Library:createAndLoadWorker(workingDirectory)
	require("preload")
	local Worker = require("rizu.library.Worker")
	local FunctionTimer = require("time.FunctionTimer")
	local Filesystem
	if love and love.filesystem then
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
	if self.tr then
		self.tr:stop()
	end
	self.database:unload()
end

Library.unload = thread.coro(Library.unload)

function Library:stopThread()
	if self.tr then
		self.tr:stopDetached()
		self.tr = nil
	end
end

---@param status rizu.library.TaskStatus
---@param errors string[]
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

---@param f fun(worker: rizu.library.Library)
---@param async boolean?
function Library:addTask(f, async)
	---@type rizu.library.LibraryTask
	local task = {f = f}
	table.insert(self.tasks, task)

	if async then
		task.co = coroutine.running()
		coroutine.yield()
	end
end

---@param path string?
---@param location_id number
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

function Library:stopTask()
	self.worker:stopTask()
end

Library.stopTask = thread.coro(Library.stopTask)

---@param params table
---@return table result
function Library:queryAsync(params)
	if self.is_sync or not self.worker then
		self.chartviewsRepo.params = params
		return self.chartviewsRepo:query()
	end
	return self.worker:query(params)
end

---@param params table
---@param chartview table
---@return table result
function Library:getViewsAsync(params, chartview)
	if self.is_sync or not self.worker then
		self.chartviewsRepo.params = params
		return self.chartviewsRepo:getViews(chartview)
	end
	return self.worker:getViews(params, chartview)
end

---@param params table
---@param _chartview table
---@return table result
function Library:getChartviewAsync(params, _chartview)
	if self.is_sync or not self.worker then
		self.chartviewsRepo.params = params
		return self.chartviewsRepo:getChartview(_chartview)
	end
	return self.worker:getChartview(params, _chartview)
end

---@param chartdiff_key sea.ChartdiffKey
---@return sea.Chartplay[]
function Library:getChartplaysForChartdiffAsync(chartdiff_key)
	if self.is_sync or not self.worker then
		return self.chartsRepo:getChartplaysForChartdiff(chartdiff_key)
	end
	return self.worker:getChartplaysForChartdiff(chartdiff_key)
end

---@param chartmeta_key sea.ChartmetaKey
---@return sea.Chartplay[]
function Library:getChartplaysForChartmetaAsync(chartmeta_key)
	if self.is_sync or not self.worker then
		return self.chartsRepo:getChartplaysForChartmeta(chartmeta_key)
	end
	return self.worker:getChartplaysForChartmeta(chartmeta_key)
end

function Library:update()
	if self.tr then
		self.tr:update()
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
			assert(coroutine.resume(task.co))
		end

		task = table.remove(tasks, 1)
	end

	self.statusUpdate:update()

	self.isProcessing = false
end

Library.process = thread.coro(Library.process)

return Library
