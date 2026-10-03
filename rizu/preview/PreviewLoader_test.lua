local PreviewLoader = require("rizu.preview.PreviewLoader")
local thread = require("thread")
local test = {}

---@param hash string
local function chart(hash)
	return {hash = hash, index = 1, location_path = hash .. ".sph", location_dir = "",
		location_prefix = "", chartfile_name = hash .. ".sph", format = "sph"}
end

local function create()
	local model = {active = true, game = {}, audio_path = "song.ogg",
		chartPreview = {setChartview = function() return true end},
		applyPreparedMedia = function() end}
	local loader = PreviewLoader(model)
	loader.probe_media = function() return {audio_exists = true, bga_exists = true, bga_paths = {}} end
	return loader, model
end

local function finish(co)
	assert(coroutine.resume(co))
	thread.coroutines[co] = nil
	thread.current = thread.current - 1
end

---@param t testing.T
function test.generation_backpressure_keeps_latest_and_stop_blocks_activation(t)
	local loader, model = create()
	local pending = {} ---@type thread[]
	local starts = {} ---@type string[]
	local activations = 0
	loader.generate_async = function(data)
		starts[#starts + 1] = data.hash
		pending[#pending + 1] = coroutine.running()
		coroutine.yield()
		return true
	end
	loader.loadPreviewSafe = function() activations = activations + 1 end
	model.chartview = chart("a")
	loader:generatePreview(model.chartview)
	loader:generatePreview(chart("b"))
	loader:generatePreview(chart("c"))
	t:tdeq(starts, {"a"})
	t:eq(loader.generating_hashes.b, nil)
	finish(pending[1])
	t:tdeq(starts, {"a", "c"})
	model.active = false
	loader:stop()
	finish(pending[2])
	t:eq(loader.active_generation_hash, nil)
	t:eq(activations, 1)
	loader:release()
end

---@param t testing.T
function test.ready_selection_is_independent_of_unrelated_generation(t)
	local loader, model = create()
	local worker ---@type thread?
	loader.generate_async = function()
		worker = coroutine.running()
		coroutine.yield()
		return true
	end
	model.chartview = chart("a")
	loader:generatePreview(model.chartview)
	model.chartview = chart("b")
	loader:loadPreviewSafe()
	t:eq(loader.media_state, "ready")
	t:eq(loader.media_error, nil)
	finish(worker)
	t:eq(loader.media_state, "ready")
	loader:release()
end

---@param t testing.T
function test.existing_media_is_ready_even_when_same_hash_is_generating(t)
	local loader, model = create()
	model.chartview = chart("a")
	local worker ---@type thread?
	loader.generate_async = function()
		worker = coroutine.running()
		coroutine.yield()
		return true
	end
	loader:generatePreview(model.chartview)
	loader:loadPreviewSafe()
	t:eq(loader.media_state, "ready")
	finish(worker)
	loader:release()
end

---@param t testing.T
function test.return_to_generating_chart_reports_failure_and_does_not_retry(t)
	local loader, model = create()
	local worker, starts = nil, 0
	loader.probe_media = function() return {audio_exists = false, bga_exists = true, bga_paths = {}} end
	loader.generate_async = function()
		starts = starts + 1
		worker = coroutine.running()
		coroutine.yield()
		return false, "broken Chart"
	end
	model.chartview = chart("a")
	loader:loadPreviewSafe()
	t:eq(loader.media_state, "loading")
	model.chartview = chart("b")
	loader:loadPreviewDebounce()
	model.chartview = chart("a")
	loader:loadPreviewDebounce()
	loader:loadPreviewSafe()
	finish(worker)
	t:eq(loader.media_state, "failed")
	t:eq(loader.media_error, "broken Chart")
	loader:loadPreviewSafe()
	t:eq(loader.media_state, "failed")
	t:eq(starts, 1)
	model.active = false
	loader:release()
end

---@param t testing.T
function test.pending_current_generation_remains_loading_until_dispatch(t)
	local loader, model = create()
	local workers = {} ---@type thread[]
	local generated = {} ---@type {[string]: boolean}
	loader.probe_media = function(cv)
		return {audio_exists = generated[cv.hash] or false, bga_exists = true, bga_paths = {}}
	end
	loader.generate_async = function(data)
		workers[#workers + 1] = coroutine.running()
		coroutine.yield()
		generated[data.hash] = true
		return true
	end
	model.chartview = chart("a")
	loader:loadPreviewSafe()
	model.chartview = chart("b")
	loader:loadPreviewSafe()
	t:eq(loader.media_state, "loading")
	finish(workers[1])
	t:eq(loader.media_state, "loading")
	finish(workers[2])
	t:eq(loader.media_state, "ready")
	loader:release()
end

---@param t testing.T
function test.media_probe_failure_is_reported(t)
	local loader, model = create()
	model.chartview = chart("a")
	loader.probe_media = function() error("media missing") end
	loader:loadPreviewSafe()
	t:eq(loader.media_state, "failed")
	t:assert(loader.media_error:find("media missing", 1, true))
	loader:release()
end

---@param t testing.T
function test.resource_directory_is_prepared_for_playback(t)
	local loader, model = create()
	model.chartview = chart("a")
	model.chartview.location_dir = "songs/a"
	local dir
	model.applyPreparedMedia = function(_, media) dir = media.audio_resource_dir end
	loader:loadPreviewSafe()
	t:eq(dir, "songs/a")
	loader:release()
end

return test
