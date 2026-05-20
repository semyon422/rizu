local class = require("class")
local valid = require("valid")
local math_util = require("math_util")
local Chartplay = require("sea.chart.Chartplay")
local Chartfile = require("sea.chart.Chartfile")
local ComputeContext = require("sea.compute.ComputeContext")
local ComputeDataProvider = require("sea.compute.ComputeDataProvider")
local ComputeDataLoader = require("sea.compute.ComputeDataLoader")
local TableStorage = require("sea.chart.storage.TableStorage")
local ReplayBase = require("sea.replays.ReplayBase")
local ChartfilesRepo = require("sea.chart.repos.ChartfilesRepo")
local simplify_notechart = require("chart.transform.simplify_notechart")
local VirtualInputEvent = require("rizu.input.VirtualInputEvent")
local ReplayFactory = require("rizu.engine.replay.ReplayFactory")

local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")

---@class sea.FakeClient
---@operator call: sea.FakeClient
local FakeClient = class()

---@param accuracy number
---@param miss_ratio integer
function FakeClient:new(accuracy, miss_ratio)
	self.accuracy = accuracy
	self.miss_ratio = miss_ratio

	self.computeContext = ComputeContext()
	self.replayBase = ReplayBase()

	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:open()

	local models = db.models

	self.chartfiles_repo = ChartfilesRepo(models)
	self.charts_storage = TableStorage()
	self.replays_storage = TableStorage()

	self.compute_data_provider = ComputeDataProvider(self.chartfiles_repo, self.charts_storage, self.replays_storage)
	self.compute_data_loader = ComputeDataLoader(self.compute_data_provider)
end

---@param chart ncdk2.Chart
---@param accuracy number
---@param miss_ratio integer?
---@return rizu.ReplayFrame[]
function FakeClient:createFakeEvents(chart, accuracy, miss_ratio)
	miss_ratio = miss_ratio or math.huge

	---@type rizu.ReplayFrame[]
	local frames = {}

	math.randomseed(0)

	local notes = simplify_notechart(chart, {"tap"})
	for i, note in ipairs(notes) do
		if i % miss_ratio ~= 0 then
			local t = note.time + math_util.nrandom() * accuracy
			table.insert(frames, {
				time = t,
				event = VirtualInputEvent(1, true, note.column)
			})
			table.insert(frames, {
				time = t + 0.05,
				event = VirtualInputEvent(1, false, note.column)
			})
		end
	end

	table.sort(frames, function(a, b)
		if a.event.column == a.event.column then
			return a.time < b.time
		end
		return a.time < b.time
	end)

	return frames
end

---@param chartfile_name string
---@param chartfile_data string
---@param index integer
---@param created_at integer
---@param pause_count integer
function FakeClient:play(chartfile_name, chartfile_data, index, created_at, pause_count)
	local computeContext = self.computeContext
	local replayBase = self.replayBase

	local chart_chartmeta = assert(computeContext:fromFileData(chartfile_name, chartfile_data, index))
	local chart, chartmeta = chart_chartmeta.chart, chart_chartmeta.chartmeta

	computeContext:applyModifierReorder(replayBase)
	computeContext:computeBase(replayBase)

	local frames = self:createFakeEvents(chart, self.accuracy, self.miss_ratio)

	local replay, replay_data, replay_hash = ReplayFactory:createReplay(
		replayBase,
		chartmeta,
		frames,
		created_at,
		pause_count
	)

	local chartplay_computed = assert(computeContext:computeReplay(replay))

	local chartplay = Chartplay()

	chartplay:importChartmetaKey(chartmeta)
	chartplay:importChartplayBase(replay)
	chartplay:importChartplayComputed(chartplay_computed)

	chartplay.replay_hash = replay_hash
	chartplay.pause_count = pause_count
	chartplay.created_at = created_at

	assert(valid.format(chartplay:validate()))

	self.computeContext.chartplay = chartplay

	if not self.chartfiles_repo:getChartfileByHash(chartplay.hash) then
		local chartfile = Chartfile()
		chartfile.hash = chartplay.hash
		chartfile.name = chartfile_name
		chartfile.size = #chartfile_data
		chartfile.compute_state = "valid"
		chartfile.computed_at = created_at
		chartfile.creator_id = 1
		chartfile.submitted_at = created_at

		self.chartfiles_repo:createChartfile(chartfile)

		self.charts_storage:set(chartplay.hash, chartfile_data)
	end

	self.replays_storage:set(replay_hash, replay_data)

	return {
		chartplay = chartplay,
		chartdiff = computeContext.chartdiff,
		chartmeta = computeContext.chartmeta,
		replay = replay,
		replay_hash = replay_hash,
		replay_data = replay_data,
	}
end

return FakeClient
