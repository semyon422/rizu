local ThumbnailCache = require("ui.screens.dlc.ThumbnailCache")

local test = {}

local function image()
	return {
		released = false,
		release = function(self) self.released = true end,
	}
end

function test.deduplicates_pending_requests_and_records_download_time(t)
	local tasks = {}
	local calls = 0
	local loaded = image()
	local cache = ThumbnailCache(function()
		calls = calls + 1
		return loaded
	end, 100, {
		start = function(task) table.insert(tasks, task) end,
		now = function() return 12.5 end,
	})

	local _, _, absent_state = cache:get("absent", false)
	local _, _, first_state = cache:get("a")
	local _, _, second_state = cache:get("a")
	t:eq(absent_state, "missing")
	t:eq(first_state, "missing")
	t:eq(second_state, "pending")
	t:eq(#tasks, 1)
	tasks[1]()
	local cached, downloaded_at, state = cache:get("a")
	t:eq(calls, 1)
	t:eq(cached, loaded)
	t:eq(downloaded_at, 12.5)
	t:eq(state, "ready")
end

function test.evicts_least_recently_used_ready_image(t)
	local tasks = {}
	local images = {a = image(), b = image(), c = image()}
	local cache = ThumbnailCache(function(url) return images[url] end, 2, {
		start = function(task) table.insert(tasks, task) end,
		now = function() return 1 end,
	})

	cache:get("a")
	tasks[#tasks]()
	cache:get("b")
	tasks[#tasks]()
	cache:get("a")
	cache:get("c")
	tasks[#tasks]()
	t:eq(cache:getReadyCount(), 2)
	t:eq(images.b.released, true)
	t:eq(images.a.released, false)
	t:eq(images.c.released, false)
end

function test.clear_releases_ready_and_discards_pending_completion(t)
	local tasks = {}
	local ready = image()
	local pending = image()
	local cache = ThumbnailCache(function(url) return url == "ready" and ready or pending end, 2, {
		start = function(task) table.insert(tasks, task) end,
		now = function() return 1 end,
	})

	cache:get("ready")
	tasks[#tasks]()
	cache:get("pending")
	cache:clear()
	t:eq(ready.released, true)
	t:eq(cache:getReadyCount(), 0)
	tasks[#tasks]()
	t:eq(pending.released, true)
end

return test
