local class = require("class")
local AsyncVideoConfig = require("rizu.preview.AsyncVideoConfig")
local AsyncVideoQueue = require("rizu.preview.AsyncVideoQueue")
local AsyncVideoThreadTransport = require("rizu.preview.AsyncVideoThreadTransport")
local BgaPreviewDebug = require("rizu.preview.BgaPreviewDebug")
require("rizu.preview.AsyncVideoProtocol")

---@class rizu.preview.AsyncVideo
---@operator call: rizu.preview.AsyncVideo
---@field name string
---@field engine rizu.preview.AsyncVideoEngine
---@field image love.Image?
---@field width integer?
---@field height integer?
local AsyncVideo = class()

---@param engine rizu.preview.AsyncVideoEngine
---@param name string
function AsyncVideo:new(engine, name)
	self.engine = engine
	self.name = name
end

---@param time number
function AsyncVideo:play(time)
	self.engine:play(self.name, time)
end

function AsyncVideo:release()
	if self.image then
		self.image:release()
		self.image = nil
	end
	self.width = nil
	self.height = nil
end

---@class rizu.preview.AsyncVideoState
---@field video rizu.preview.AsyncVideo
---@field pending boolean
---@field desired_time number?
---@field request_id integer
---@field displayed_frame_time number?
---@field frame_duration number
---@field queue rizu.preview.AsyncVideoFrame[]
---@field ended boolean?

---@class rizu.preview.AsyncVideoEngine
---@operator call: rizu.preview.AsyncVideoEngine
---@field transport rizu.preview.IAsyncVideoTransport
---@field logger rizu.preview.IAsyncVideoLogger
local AsyncVideoEngine = class()

---@param transport rizu.preview.IAsyncVideoTransport?
---@param logger rizu.preview.IAsyncVideoLogger?
function AsyncVideoEngine:new(transport, logger)
	self.generation = 0
	self.request_id = 0
	self.transport = transport or AsyncVideoThreadTransport()
	self.logger = logger or BgaPreviewDebug
	---@type {[string]: rizu.preview.AsyncVideoState}
	self.videos = {}
end

function AsyncVideoEngine:startThread()
	local id = tostring(self):gsub("[^%w_]", "_")
	self.transport:start(id)
end

---@param video_names string[]
---@param video_paths {[string]: string}
function AsyncVideoEngine:load(video_names, video_paths)
	self:unload()
	self:startThread()

	self.generation = self.generation + 1
	for _, name in ipairs(video_names) do
		if video_paths[name] then
			self.videos[name] = {
				video = AsyncVideo(self, name),
				pending = false,
				request_id = 0,
				frame_duration = 1 / 30,
				queue = {},
			}
		end
	end

	self.transport:send({
		type = "load",
		generation = self.generation,
		video_names = video_names,
		video_paths = video_paths,
	})
end

---@param frame rizu.preview.AsyncVideoFrame
local function releaseFrame(frame)
	if frame.image_data.release then
		frame.image_data:release()
	end
end

---@param state rizu.preview.AsyncVideoState
local function clearQueue(state)
	for _, frame in ipairs(state.queue or {}) do
		releaseFrame(frame)
	end
	state.queue = {}
end

---@param state rizu.preview.AsyncVideoState
local function ensureStateDefaults(state)
	state.frame_duration = state.frame_duration or 1 / 30
	state.queue = state.queue or {}
end

---@param name string
---@param time number
function AsyncVideoEngine:sendFrameRequest(name, time)
	local state = self.videos[name]
	if not state then
		return
	end
	ensureStateDefaults(state)

	self.request_id = self.request_id + 1
	state.pending = true
	state.request_id = self.request_id
	self.transport:send({
		type = "frame",
		generation = self.generation,
		video_name = name,
		request_id = state.request_id,
		time = time,
		frame_duration = state.frame_duration,
		count = math.max(1, AsyncVideoConfig.buffer_target - #state.queue),
	})
end

---@param name string
---@param time number
function AsyncVideoEngine:requestFrame(name, time)
	local state = self.videos[name]
	if not state then
		return
	end
	ensureStateDefaults(state)

	state.desired_time = time
	if state.pending then
		return
	end

	if state.ended then
		if state.displayed_frame_time and time < state.displayed_frame_time - state.frame_duration then
			state.ended = nil
			state.displayed_frame_time = nil
		else
			return
		end
	end

	local reset_reason = AsyncVideoQueue.getResetReason(state, time, AsyncVideoConfig)
	if reset_reason then
		self.logger:warnQueueState(state, name, reset_reason, time)
		clearQueue(state)
		state.ended = nil
		if reset_reason == "queue_reset_backward" then
			state.displayed_frame_time = nil
		end
		state.pending = false
	end

	if AsyncVideoQueue.hasEnoughFrames(state, AsyncVideoConfig) then
		return
	end

	local request_time = AsyncVideoQueue.getRequestTime(state, time)
	self:sendFrameRequest(name, request_time)
end

---@param event rizu.preview.AsyncVideoFrameEvent
function AsyncVideoEngine:applyFrame(event)
	if event.generation ~= self.generation then
		return
	end

	local state = self.videos[event.video_name]
	if not state or event.request_id ~= state.request_id then
		if event.image_data and event.image_data.release then
			event.image_data:release()
		end
		return
	end
	ensureStateDefaults(state)

	if not event.frame_time then
		self.logger:warnMiss(event)
		return
	end

	local frame_rate = tonumber(event.frame_rate)
	if frame_rate and frame_rate > 0 then
		state.frame_duration = 1 / frame_rate
	end
	if not event.image_data then
		return
	end

	local last_frame = state.queue[#state.queue]
	if last_frame and event.frame_time <= last_frame.frame_time then
		self.logger:warnNonMonotonic(event.video_name, last_frame.frame_time, event.frame_time, #state.queue)
	end
	table.insert(state.queue, {
		frame_time = event.frame_time,
		image_data = event.image_data,
		width = event.width,
		height = event.height,
		frame_rate = frame_rate,
		ended = event.ended,
	})
end

---@param event rizu.preview.AsyncVideoBatchDoneEvent
function AsyncVideoEngine:applyBatchDone(event)
	if event.generation ~= self.generation then
		return
	end

	local state = self.videos[event.video_name]
	if not state or event.request_id ~= state.request_id then
		return
	end
	ensureStateDefaults(state)

	state.pending = false
	local desired_time = state.desired_time
	if desired_time and desired_time ~= event.requested_time then
		self:requestFrame(event.video_name, desired_time)
	end
end

---@param name string
---@param time number
function AsyncVideoEngine:presentFrame(name, time)
	local t0 = love.timer.getTime()
	local state = self.videos[name]
	if not state then
		return
	end
	ensureStateDefaults(state)

	local queue = state.queue
	local selected_index
	for i, frame in ipairs(queue) do
		-- Pick the latest frame within half a frame of the playback clock.
		-- This smooths fractional timer jitter without forcing a seek.
		if frame.frame_time <= time + state.frame_duration * 0.5 then
			selected_index = i
		else
			break
		end
	end
	if not selected_index then
		return
	end

	local dropped_frames = selected_index - 1
	for _ = 1, selected_index - 1 do
		local frame = table.remove(queue, 1)
		releaseFrame(frame)
	end

	local frame = table.remove(queue, 1)
	local video = state.video
	if not video.image or video.width ~= frame.width or video.height ~= frame.height then
		if video.image then
			video.image:release()
		end
		video.image = love.graphics.newImage(frame.image_data)
		video.width = frame.width
		video.height = frame.height
	else
		video.image:replacePixels(frame.image_data)
	end
	state.displayed_frame_time = frame.frame_time
	state.ended = frame.ended or nil
	local lateness = time - frame.frame_time
	releaseFrame(frame)
	if dropped_frames > 1 or lateness > state.frame_duration * 1.5 then
		self.logger:warnQueueState(
			state,
			name,
			"queue_skip",
			time,
			"dropped=" .. tostring(dropped_frames) .. " lateness=" .. ("%.3f"):format(lateness)
		)
	end
	local elapsed = love.timer.getTime() - t0
	if elapsed >= AsyncVideoConfig.slow_main_seconds then
		self.logger:warnSlowPresent(name, #queue, frame.frame_time, elapsed)
	end
end

function AsyncVideoEngine:update()
	local t0 = love.timer.getTime()
	self.transport:checkError()

	local event = self.transport:pop()
	local frame_events = 0
	local control_events = 0
	while event do
		if event.type == "frame" then
			self:applyFrame(event)
			frame_events = frame_events + 1
		elseif event.type == "batch_done" then
			self:applyBatchDone(event)
			control_events = control_events + 1
		end
		if frame_events >= AsyncVideoConfig.max_output_frames_per_update then
			break
		end
		event = self.transport:pop()
	end
	local elapsed = love.timer.getTime() - t0
	if elapsed >= AsyncVideoConfig.slow_main_seconds then
		self.logger:warnSlowUpdate(frame_events, control_events, elapsed)
	end
end

function AsyncVideoEngine:unload()
	for _, state in pairs(self.videos) do
		clearQueue(state)
		state.video:release()
	end
	self.videos = {}
	self.generation = self.generation + 1

	self.transport:stop()
end

function AsyncVideoEngine:rewind() end

---@param name string
---@param time number
function AsyncVideoEngine:play(name, time)
	self:presentFrame(name, time)
	self:requestFrame(name, time)
end

---@param name string
---@param time number
function AsyncVideoEngine:seek(name, time)
	self:requestFrame(name, time)
end

---@param name string|integer
---@return rizu.preview.AsyncVideo?
function AsyncVideoEngine:get(name)
	local state = self.videos[name]
	return state and state.video
end

return AsyncVideoEngine
