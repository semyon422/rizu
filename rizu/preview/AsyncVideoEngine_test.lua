local AsyncVideoEngine = require("rizu.preview.AsyncVideoEngine")
local AsyncVideoConfig = require("rizu.preview.AsyncVideoConfig")
local FakeAsyncVideoTransport = require("rizu.preview.FakeAsyncVideoTransport")
local FakeBgaPreviewDebug = require("rizu.preview.FakeBgaPreviewDebug")

local test = {}

local function frame(time)
	return {
		frame_time = time,
		image_data = {
			released = false,
			release = function(self)
				self.released = true
			end,
		},
		width = 1,
		height = 1,
	}
end

local function makeEngine(state)
	local transport = FakeAsyncVideoTransport()
	local logger = FakeBgaPreviewDebug()
	local engine = AsyncVideoEngine(transport, logger)
	engine.videos.video = state
	return engine, transport, logger
end

---@param t testing.T
function test.worker_file_compiles(t)
	t:assert(loadfile(AsyncVideoConfig.worker_path))
end

---@param t testing.T
function test.update_uses_headless_clock(t)
	local transport = FakeAsyncVideoTransport()
	local clock_calls = 0
	local engine = AsyncVideoEngine(transport, FakeBgaPreviewDebug(), function()
		clock_calls = clock_calls + 1
		return 0
	end)

	engine:startThread()
	engine:update()

	t:eq(clock_calls, 2)
end

---@param t testing.T
function test.load_starts_transport_and_sends_load_event(t)
	local transport = FakeAsyncVideoTransport()
	local engine = AsyncVideoEngine(transport, FakeBgaPreviewDebug())

	engine:load({"video"}, {video = "mounted/video.mp4"})

	t:eq(transport.started, true)
	t:eq(transport.start_count, 1)
	t:eq(transport.sent[1].type, "load")
	t:eq(transport.sent[1].generation, engine.generation)
	t:eq(transport.sent[1].video_paths.video, "mounted/video.mp4")
	t:ne(engine:get("video"), nil)
end

---@param t testing.T
function test.load_reuses_running_transport(t)
	local transport = FakeAsyncVideoTransport()
	local engine = AsyncVideoEngine(transport, FakeBgaPreviewDebug())

	engine:load({"video"}, {video = "mounted/video.mp4"})
	engine:load({"next"}, {next = "mounted/next.mp4"})

	t:eq(transport.start_count, 1)
	t:eq(transport.stopped, false)
	t:eq(engine:get("video"), nil)
	t:ne(engine:get("next"), nil)
	t:eq(transport.sent[2].type, "unload")
	t:eq(transport.sent[3].type, "load")
end

---@param t testing.T
function test.empty_load_does_not_start_transport(t)
	local transport = FakeAsyncVideoTransport()
	local engine = AsyncVideoEngine(transport, FakeBgaPreviewDebug())

	engine:load({}, {})

	t:eq(transport.start_count, 0)
	t:eq(#transport.sent, 0)
end

---@param t testing.T
function test.unload_keeps_transport_for_reuse(t)
	local transport = FakeAsyncVideoTransport()
	local engine = AsyncVideoEngine(transport, FakeBgaPreviewDebug())

	engine:load({"video"}, {video = "mounted/video.mp4"})
	engine:unload()

	t:eq(transport.stopped, false)
	t:eq(transport:lastSent().type, "unload")
	t:eq(engine:get("video"), nil)
end

---@param t testing.T
function test.release_stops_transport(t)
	local transport = FakeAsyncVideoTransport()
	local engine = AsyncVideoEngine(transport, FakeBgaPreviewDebug())

	engine:load({"video"}, {video = "mounted/video.mp4"})
	engine:release()

	t:eq(transport.stopped, true)
	t:eq(engine:get("video"), nil)
end

---@param t testing.T
function test.request_keeps_queue_when_clock_is_within_displayed_frame(t)
	local queued_frame = frame(1.1)
	local engine, transport = makeEngine({
		video = {},
		pending = false,
		request_id = 0,
		displayed_frame_time = 1,
		frame_duration = 1 / 30,
		queue = {queued_frame},
	})

	engine:requestFrame("video", 0.98)

	t:eq(#engine.videos.video.queue, 1)
	t:eq(engine.videos.video.queue[1], queued_frame)
	t:eq(engine.videos.video.displayed_frame_time, 1)
	t:eq(queued_frame.image_data.released, false)
	t:eq(transport:lastSent().video_name, "video")
end

---@param t testing.T
function test.request_clears_queue_on_real_backward_seek(t)
	local queued_frame = frame(1.1)
	local engine, transport, logger = makeEngine({
		video = {},
		pending = false,
		request_id = 0,
		displayed_frame_time = 1,
		frame_duration = 1 / 30,
		queue = {queued_frame},
	})

	engine:requestFrame("video", 0.9)

	t:eq(#engine.videos.video.queue, 0)
	t:eq(engine.videos.video.displayed_frame_time, nil)
	t:eq(queued_frame.image_data.released, true)
	t:eq(transport:lastSent().video_name, "video")
	t:eq(logger.warnings[1][2], "queue_reset_backward")
end

---@param t testing.T
function test.request_clears_stale_queue(t)
	local queued_frame = frame(1)
	local engine, transport, logger = makeEngine({
		video = {},
		pending = false,
		request_id = 0,
		frame_duration = 1 / 30,
		queue = {queued_frame},
	})

	engine:requestFrame("video", 1.1)

	t:eq(#engine.videos.video.queue, 0)
	t:eq(queued_frame.image_data.released, true)
	t:eq(transport:lastSent().video_name, "video")
	t:eq(logger.warnings[1][2], "queue_reset_stale")
end

---@param t testing.T
function test.request_clears_future_queue(t)
	local queued_frame = frame(10)
	local engine, transport, logger = makeEngine({
		video = {},
		pending = false,
		request_id = 0,
		frame_duration = 1 / 30,
		queue = {queued_frame},
	})

	engine:requestFrame("video", 1)

	t:eq(#engine.videos.video.queue, 0)
	t:eq(queued_frame.image_data.released, true)
	t:eq(transport:lastSent().video_name, "video")
	t:eq(logger.warnings[1][2], "queue_reset_future")
end

---@param t testing.T
function test.request_does_not_repeat_after_final_frame(t)
	local engine, transport = makeEngine({
		video = {},
		pending = false,
		request_id = 0,
		displayed_frame_time = 100,
		frame_duration = 1 / 30,
		queue = {},
		ended = true,
	})

	engine:requestFrame("video", 101)

	t:eq(transport:lastSent(), nil)
end

---@param t testing.T
function test.backward_seek_after_final_frame_requests_again(t)
	local engine, transport = makeEngine({
		video = {},
		pending = false,
		request_id = 0,
		displayed_frame_time = 100,
		frame_duration = 1 / 30,
		queue = {},
		ended = true,
	})

	engine:requestFrame("video", 10)

	t:eq(engine.videos.video.ended, nil)
	t:eq(engine.videos.video.displayed_frame_time, nil)
	t:eq(transport:lastSent().video_name, "video")
	t:eq(transport:lastSent().time, 10)
end

---@param t testing.T
function test.empty_batch_stops_automatic_retries(t)
	local engine, transport = makeEngine({
		video = {},
		pending = true,
		request_id = 7,
		desired_time = 2,
		frame_duration = 1 / 30,
		queue = {},
	})

	engine:applyBatchDone({
		type = "batch_done",
		generation = engine.generation,
		video_name = "video",
		request_id = 7,
		requested_time = 1,
		sent = 0,
	})
	engine:requestFrame("video", 3)

	t:eq(engine.videos.video.decode_failed, true)
	t:eq(engine.videos.video.pending, false)
	t:eq(transport:lastSent(), nil)
end

---@param t testing.T
function test.empty_followup_batch_keeps_queued_frames_playable(t)
	local queued_frame = frame(1)
	local engine = makeEngine({
		video = {},
		pending = true,
		request_id = 7,
		frame_duration = 1 / 30,
		queue = {queued_frame},
	})

	engine:applyBatchDone({
		type = "batch_done",
		generation = engine.generation,
		video_name = "video",
		request_id = 7,
		requested_time = 1,
		sent = 0,
	})

	t:eq(engine.videos.video.decode_failed, nil)
	t:eq(engine.videos.video.queue[1], queued_frame)
end

---@param t testing.T
function test.explicit_seek_retries_after_empty_batch(t)
	local engine, transport = makeEngine({
		video = {},
		pending = false,
		request_id = 7,
		frame_duration = 1 / 30,
		queue = {},
		decode_failed = true,
	})

	engine:seek("video", 3)

	t:eq(engine.videos.video.decode_failed, nil)
	t:eq(transport:lastSent().type, "frame")
	t:eq(transport:lastSent().time, 3)
end

---@param t testing.T
function test.stale_generation_frame_releases_image_data(t)
	local engine = makeEngine({
		video = {},
		pending = false,
		request_id = 1,
		frame_duration = 1 / 30,
		queue = {},
	})
	local stale_frame = frame(1)

	engine:applyFrame({
		type = "frame",
		generation = engine.generation - 1,
		video_name = "video",
		request_id = 1,
		requested_time = 1,
		frame_time = stale_frame.frame_time,
		width = stale_frame.width,
		height = stale_frame.height,
		image_data = stale_frame.image_data,
	})

	t:eq(stale_frame.image_data.released, true)
end

return test
