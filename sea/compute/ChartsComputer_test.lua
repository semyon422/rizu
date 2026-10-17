local TableStorage = require("sea.chart.storage.TableStorage")
local ComputeDataProvider = require("sea.compute.ComputeDataProvider")
local ComputeDataLoader = require("sea.compute.ComputeDataLoader")
local FakeClient = require("sea.compute.FakeClient")
local ChartsRepo = require("sea.chart.repos.ChartsRepo")
local ChartfilesRepo = require("sea.chart.repos.ChartfilesRepo")
local ChartsComputer = require("sea.compute.ChartsComputer")
local ReplayComputer = require("sea.compute.ReplayComputer")
local ComputeFailure = require("sea.compute.ComputeFailure")
local ComputeJobs = require("sea.compute.ComputeJobs")
local ComputeJobsRepo = require("sea.compute.repos.ComputeJobsRepo")
local Chartplays = require("sea.chart.Chartplays")
local User = require("sea.access.User")

local LjsqliteDatabase = require("rdb.db.LjsqliteDatabase")
local ServerSqliteDatabase = require("sea.storage.server.ServerSqliteDatabase")

local chart_samples = require("sea.chart.samples.Samples")

local test = {}

local function create_test_ctx()
	local db = ServerSqliteDatabase(LjsqliteDatabase())
	db.path = ":memory:"
	db:open()

	-- db.orm:debug(true)

	local models = db.models

	local charts_repo = ChartsRepo(models)
	local chartfiles_repo = ChartfilesRepo(models)

	local charts_storage = TableStorage()
	local replays_storage = TableStorage()

	local compute_data_provider = ComputeDataProvider(chartfiles_repo, charts_storage, replays_storage)
	local compute_data_loader = ComputeDataLoader(compute_data_provider)
	local replay_computer = ReplayComputer()
	local charts_computer = ChartsComputer(compute_data_loader, charts_repo, replay_computer, "test")
	local compute_jobs = ComputeJobs(
		ComputeJobsRepo(models),
		charts_repo,
		chartfiles_repo,
		compute_data_provider,
		replay_computer,
		"test",
		function(f, ...) return f(...) end
	)

	local chartplays = Chartplays(
		charts_repo,
		chartfiles_repo,
		compute_data_provider,
		charts_storage,
		replays_storage,
		compute_jobs
	)

	local user = User()
	user.id = 1

	return {
		db = db,
		charts_repo = charts_repo,
		chartfiles_repo = chartfiles_repo,
		charts_storage = charts_storage,
		replays_storage = replays_storage,
		chartplays = chartplays,
		charts_computer = charts_computer,
		user = user,
	}
end

---@param t testing.T
function test.chartplays_full(t)
	local ctx = create_test_ctx()
	local sample = chart_samples[1]

	local client = FakeClient(0.02, 100)

	local count = 4
	for i = 1, count do
		local time = i * ctx.chartplays.chartplays_access.submit_interval
		local play = client:play(sample.name, sample.data, 1, time, 0)
		local c, err = ctx.chartplays:submit(ctx.user, time, client.compute_data_provider, play.chartplay, play.chartdiff)
		t:assert(c, err)
	end

	local chartplays = ctx.chartplays:getChartplays()
	if not t:eq(#chartplays, count) then
		return
	end

	for _, p in ipairs(chartplays) do
		t:assert(p.rating > 0)
	end

	ctx.db.models.chartplays:update({rating = 0})

	chartplays = ctx.chartplays:getChartplays()
	for _, p in ipairs(chartplays) do
		t:eq(p.rating, 0)
	end

	ctx.charts_computer:computeChartplay(chartplays[1])
	ctx.charts_computer:computeChartplay(chartplays[2])

	chartplays = ctx.chartplays:getChartplays()
	t:assert(chartplays[1].rating > 0)
	t:assert(chartplays[2].rating > 0)
	t:assert(chartplays[3].rating == 0)
	t:assert(chartplays[4].rating == 0)
end

---@param t testing.T
function test.transient_compute_failure_remains_new(t)
	local ctx = create_test_ctx()
	local client = FakeClient(0.02, 100)
	local sample = chart_samples[1]
	local play = client:play(sample.name, sample.data, 1, 1, 0)
	ctx.chartplays.compute_jobs.replay_computer = {
		compute = function()
			return nil, ComputeFailure.transient("worker_unavailable", "worker unavailable")
		end,
	}

	local result, err, failure = ctx.chartplays:submit(
		ctx.user,
		1,
		client.compute_data_provider,
		play.chartplay,
		play.chartdiff
	)
	local chartplay = ctx.chartplays:getChartplays()[1]
	t:eq(result, nil)
	t:eq(err, "worker_unavailable: worker unavailable")
	t:eq(failure.kind, "transient")
	t:eq(chartplay.compute_state, "new")
end

---@param t testing.T
function test.permanent_compute_failure_is_invalid(t)
	local ctx = create_test_ctx()
	local client = FakeClient(0.02, 100)
	local sample = chart_samples[1]
	local play = client:play(sample.name, sample.data, 1, 1, 0)
	ctx.chartplays.compute_jobs.replay_computer = {
		compute = function()
			return nil, ComputeFailure.permanent("invalid_replay", "bad replay")
		end,
	}

	local result, err, failure = ctx.chartplays:submit(
		ctx.user,
		1,
		client.compute_data_provider,
		play.chartplay,
		play.chartdiff
	)
	local chartplay = ctx.chartplays:getChartplays()[1]
	t:eq(result, nil)
	t:eq(err, "invalid_replay: bad replay")
	t:eq(failure.kind, "permanent")
	t:eq(chartplay.compute_state, "invalid")
end

---@param t testing.T
function test.chartdiffs_full(t)
	local ctx = create_test_ctx()
end

return test
