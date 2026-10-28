local LibraryTestContext = require("rizu.library.LibraryTestContext")
local FakeFilesystem = require("fs.FakeFilesystem")
local Settings = require("rizu.config.Settings")
local ChartplayHitsRepo = require("rizu.library.repos.ChartplayHitsRepo")
local ScoreTask = require("rizu.library.tasks.ScoreTask")

local test = {}

---@param t testing.T
function test.empty_library_has_no_chartfiles(t)
	local ctx = LibraryTestContext()

	t:eq(ctx.lib:hasChartfilesAsync(), false)
	ctx:cleanup()
end

---@param t testing.T
function test.library_with_chartfile_has_chartfiles(t)
	local ctx = LibraryTestContext()
	local location = ctx.lib.database.models.locations:create({
		name = "Test", path = "/test", is_relative = false, is_internal = false,
	})
	ctx.lib.database.models.chartfile_sets:create({
		id = 1, location_id = location.id, name = "Set", modified_at = 0, is_file = false,
	})
	ctx.lib.database.models.chartfiles:create({set_id = 1, name = "chart.osu", modified_at = 0})

	t:eq(ctx.lib:hasChartfilesAsync(), true)
	ctx:cleanup()
end

---@param t testing.T
function test.happy_path(t)
	local ctx = LibraryTestContext()

	-- Trigger a simple task using the fluent API
	ctx.lib:addTask(function()
		local tc = ctx.lib.worker.processor.taskContext
		tc:startStage("hashing", 10)
		ctx:advanceTime(1)
		tc:advance(5, "halfway")
		tc:report("halfway")
		tc:finish()
	end)

	ctx:process()

	-- Verify progress metrics via injected time
	local hashingUpdate = nil
	for _, update in ipairs(ctx.statusUpdates) do
		if update.stage == "hashing" and update.current == 5 then
			hashingUpdate = update
		end
	end

	t:assert(hashingUpdate, "Should have received hashing update with current=5")
	---@cast hashingUpdate -?
	t:eq(hashingUpdate.itemsPerSecond, 5)
	t:eq(hashingUpdate.eta, 1)
	t:eq(ctx.lib.status.stage, "idle")

	ctx:cleanup()
end

---@param t testing.T
function test.observability_sequence(t)
	local ctx = LibraryTestContext()

	-- Mock a multi-stage flow
	ctx.lib:addTask(function()
		local tc = ctx.lib.worker.processor.taskContext
		tc:startStage("scanning", 100)
		tc:finish()
		tc:startStage("hashing", 50)
		tc:finish()
	end)

	ctx:process()

	local stages = {}
	for _, u in ipairs(ctx.statusUpdates) do
		table.insert(stages, u.stage)
	end

	-- Sequence should be: scanning -> idle -> hashing -> idle
	t:tdeq(stages, {"scanning", "idle", "hashing", "idle"})

	ctx:cleanup()
end

---@param t testing.T
function test.filesystem_corrupted(t)
	local ctx = LibraryTestContext()

	-- Inject a failing fs.read into the existing context
	local original_read = ctx.fs.read
	function ctx.fs:read(path)
		if path:find("%.sql$") then return original_read(self, path) end
		return nil, "Read permission denied"
	end

	local chartfile = {
		path = "junk.sph",
		name = "junk.sph",
		hash = "junk",
	}

	-- Attempt a task that requires reading
	ctx.lib:addTask(function()
		local processor = ctx.lib.worker.processor
		processor.hashingTask:processChartfile(chartfile, "")
		-- Explicitly report to sync status
		processor.taskContext:report()
	end)

	ctx:process()

	t:eq(ctx.lib.status.errorCount, 1)

	-- Check library errors
	local found = false
	for _, err in ipairs(ctx.lib.errors) do
		-- The error might be wrapped in traceback or HashingTask prefix
		if err:find("Read permission denied") or err:find("junk%.sph") then
			found = true
			break
		end
	end
	t:assert(found, "Error message should be recorded in Library.errors")

	ctx:cleanup()
end

---@param t testing.T
function test.main_and_worker_databases_are_isolated_from_userdata(t)
	local ctx = LibraryTestContext()
	for _, db in ipairs({ctx.lib.database, ctx.lib.worker.db}) do
		local database_info = db.db:query("PRAGMA database_list")
		t:eq(database_info[1].file, "")
	end
	ctx:cleanup()
end

---@param t testing.T
function test.hits_update_once_per_version(t)
	local ctx = LibraryTestContext()
	local settings = Settings.createConfig(FakeFilesystem())
	local calls = 0
	local completed = false
	ctx.lib.worker.computeMissingHits = function()
		calls = calls + 1
		return completed
	end

	-- A stopped update leaves the version, so the next start goes on.
	ctx.lib:updateHits(settings)
	ctx:process()
	t:eq(calls, 1)
	t:eq(settings:getNumber(Settings.keys.scores.hits_version), 0)

	completed = true
	ctx.lib:updateHits(settings)
	ctx:process()
	t:eq(calls, 2)
	t:eq(settings:getNumber(Settings.keys.scores.hits_version), ChartplayHitsRepo.hits_version)

	-- Done for this version: nothing to do at the next start.
	ctx.lib:updateHits(settings)
	ctx:process()
	t:eq(calls, 2)
	ctx:cleanup()
end

---@param t testing.T
function test.scores_recompute_once_per_version_and_resume(t)
	local ctx = LibraryTestContext()
	local settings = Settings.createConfig(FakeFilesystem())
	local keys = Settings.keys.scores
	---@type (integer?)[]
	local sinces = {}
	local completed = false
	ctx.lib.worker.recomputeChartplays = function(_, since)
		table.insert(sinces, since)
		return completed
	end

	-- A stopped run goes on at the next start from when the first one began.
	ctx.lib:updateScores(settings)
	ctx:process()
	local since = settings:getNumber(keys.recompute_since)
	t:assert(since > 0)
	t:tdeq(sinces, {since})
	t:eq(settings:getNumber(keys.compute_version), 0)

	completed = true
	ctx.lib:updateScores(settings)
	ctx:process()
	t:tdeq(sinces, {since, since})
	t:eq(settings:getNumber(keys.compute_version), ScoreTask.version)
	t:eq(settings:getNumber(keys.recompute_since), 0)

	-- Done for this version: nothing to do at the next start.
	ctx.lib:updateScores(settings)
	ctx:process()
	t:eq(#sinces, 2)
	ctx:cleanup()
end

return test
