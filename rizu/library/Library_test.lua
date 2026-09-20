local LibraryTestContext = require("rizu.library.LibraryTestContext")

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
	ctx.lib.database.models.locations:create({
		id = 1, name = "Test", path = "/test", is_relative = 0, is_internal = 0,
	})
	ctx.lib.database.models.chartfile_sets:create({
		id = 1, location_id = 1, name = "Set", modified_at = 0, is_file = 0,
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

return test
