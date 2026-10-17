local AsyncVideoConfig = require("rizu.preview.AsyncVideoConfig")
local AsyncVideoQueue = require("rizu.preview.AsyncVideoQueue")

local test = {}

local function frame(time)
	return {
		frame_time = time,
		image_data = {},
		width = 1,
		height = 1,
	}
end

---@param fields rizu.preview.AsyncVideoQueueState
---@return rizu.preview.AsyncVideoQueueState
local function state(fields)
	fields.frame_duration = fields.frame_duration or 1 / 30
	fields.queue = fields.queue or {}
	return fields
end

---@param t testing.T
function test.reset_reason_allows_small_timer_jitter(t)
	local video_state = state({
		displayed_frame_time = 1,
		queue = {frame(1.1)},
	})

	t:eq(AsyncVideoQueue.getResetReason(video_state, 0.98, AsyncVideoConfig), nil)
end

---@param t testing.T
function test.reset_reason_detects_real_backward_seek(t)
	local video_state = state({
		displayed_frame_time = 1,
		queue = {frame(1.1)},
	})

	t:eq(AsyncVideoQueue.getResetReason(video_state, 0.9, AsyncVideoConfig), "queue_reset_backward")
end

---@param t testing.T
function test.reset_reason_detects_stale_queue(t)
	local video_state = state({
		queue = {frame(1)},
	})

	t:eq(AsyncVideoQueue.getResetReason(video_state, 1.1, AsyncVideoConfig), "queue_reset_stale")
end

---@param t testing.T
function test.reset_reason_detects_future_queue(t)
	local video_state = state({
		queue = {frame(10)},
	})

	t:eq(AsyncVideoQueue.getResetReason(video_state, 1, AsyncVideoConfig), "queue_reset_future")
end

---@param t testing.T
function test.request_time_continues_after_queued_frame(t)
	local video_state = state({
		queue = {frame(2)},
	})

	t:aeq(AsyncVideoQueue.getRequestTime(video_state, 1), 2 + 1 / 30, 1e-6)
end

---@param t testing.T
function test.request_time_continues_after_displayed_frame(t)
	local video_state = state({
		displayed_frame_time = 2,
	})

	t:aeq(AsyncVideoQueue.getRequestTime(video_state, 1), 2 + 1 / 30, 1e-6)
end

---@param t testing.T
function test.has_enough_frames_uses_low_watermark(t)
	local video_state = state({
		queue = {},
	})

	for i = 1, AsyncVideoConfig.buffer_low_watermark - 1 do
		video_state.queue[i] = frame(i)
	end

	t:eq(AsyncVideoQueue.hasEnoughFrames(video_state, AsyncVideoConfig), false)
	video_state.queue[AsyncVideoConfig.buffer_low_watermark] = frame(AsyncVideoConfig.buffer_low_watermark)
	t:eq(AsyncVideoQueue.hasEnoughFrames(video_state, AsyncVideoConfig), true)
end

return test
