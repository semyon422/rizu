local AsyncVideoQueue = {}

---@alias rizu.preview.AsyncVideoQueueResetReason "queue_reset_backward"|"queue_reset_stale"|"queue_reset_future"

---@class rizu.preview.AsyncVideoQueueConfig
---@field buffer_target integer
---@field buffer_low_watermark integer

---@class rizu.preview.AsyncVideoQueueState
---@field displayed_frame_time number?
---@field frame_duration number
---@field queue rizu.preview.AsyncVideoFrame[]

---@param state rizu.preview.AsyncVideoQueueState
---@param time number
---@param config rizu.preview.AsyncVideoQueueConfig
---@return rizu.preview.AsyncVideoQueueResetReason? reason
function AsyncVideoQueue.getResetReason(state, time, config)
	local frame_duration = state.frame_duration
	if state.displayed_frame_time and time < state.displayed_frame_time - frame_duration then
		return "queue_reset_backward"
	end

	local first_frame = state.queue[1]
	local last_frame = state.queue[#state.queue]
	if last_frame and last_frame.frame_time < time - frame_duration then
		return "queue_reset_stale"
	end
	if first_frame and first_frame.frame_time > time + frame_duration * config.buffer_target then
		return "queue_reset_future"
	end
end

---@param state rizu.preview.AsyncVideoQueueState
---@param config rizu.preview.AsyncVideoQueueConfig
---@return boolean
function AsyncVideoQueue.hasEnoughFrames(state, config)
	return #state.queue >= config.buffer_low_watermark
end

---@param state rizu.preview.AsyncVideoQueueState
---@param time number
---@return number
function AsyncVideoQueue.getRequestTime(state, time)
	local request_time = time
	local last_frame = state.queue[#state.queue]
	if last_frame then
		request_time = math.max(request_time, last_frame.frame_time + state.frame_duration)
	elseif state.displayed_frame_time then
		request_time = math.max(request_time, state.displayed_frame_time + state.frame_duration)
	end
	return request_time
end

return AsyncVideoQueue
