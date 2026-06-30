local class = require("class")

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

---@class rizu.preview.AsyncVideoFrame
---@field frame_time number
---@field image_data love.ImageData
---@field width integer
---@field height integer
---@field frame_rate number?

---@class rizu.preview.AsyncVideoState
---@field video rizu.preview.AsyncVideo
---@field pending boolean
---@field desired_time number?
---@field request_id integer
---@field displayed_frame_time number?
---@field frame_duration number
---@field queue rizu.preview.AsyncVideoFrame[]

---@class rizu.preview.AsyncVideoEngine
---@operator call: rizu.preview.AsyncVideoEngine
local AsyncVideoEngine = class()

local BUFFER_TARGET = 45
local BUFFER_LOW_WATERMARK = 30
local MAX_OUTPUT_FRAMES_PER_UPDATE = BUFFER_TARGET
local SLOW_MAIN_SECONDS = 0.008
local WORKER_PATH = "rizu/preview/AsyncVideoWorker.lua"

function AsyncVideoEngine:new()
	self.generation = 0
	self.request_id = 0
	---@type {[string]: rizu.preview.AsyncVideoState}
	self.videos = {}
end

function AsyncVideoEngine:startThread()
	local id = tostring(self):gsub("[^%w_]", "_")
	local input_channel_name = "async_video_input_" .. id
	local output_channel_name = "async_video_output_" .. id
	self.input_channel = love.thread.getChannel(input_channel_name)
	self.output_channel = love.thread.getChannel(output_channel_name)
	self.input_channel:clear()
	self.output_channel:clear()
	self.thread = love.thread.newThread(WORKER_PATH)
	self.thread:start(input_channel_name, output_channel_name)
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

	self.input_channel:push({
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

---@param state rizu.preview.AsyncVideoState
---@param name string
---@param kind string
---@param time number
---@param extra string?
local function warnQueueState(state, name, kind, time, extra)
	local queue = state.queue
	local first_frame = queue[1]
	local last_frame = queue[#queue]
	local BgaPreviewDebug = require("rizu.preview.BgaPreviewDebug")
	BgaPreviewDebug.warn(
		"video_main",
		kind,
		name,
		"time=" .. tostring(time),
		"queue=" .. tostring(#queue),
		"first=" .. tostring(first_frame and first_frame.frame_time),
		"last=" .. tostring(last_frame and last_frame.frame_time),
		"displayed=" .. tostring(state.displayed_frame_time),
		"pending=" .. tostring(state.pending),
		extra or ""
	)
end

---@param name string
---@param time number
function AsyncVideoEngine:sendFrameRequest(name, time)
	local state = self.videos[name]
	if not state or not self.input_channel then
		return
	end
	ensureStateDefaults(state)

	self.request_id = self.request_id + 1
	state.pending = true
	state.request_id = self.request_id
	self.input_channel:push({
		type = "frame",
		generation = self.generation,
		video_name = name,
		request_id = state.request_id,
		time = time,
		frame_duration = state.frame_duration,
		count = math.max(1, BUFFER_TARGET - #state.queue),
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

	local frame_duration = state.frame_duration
	if state.displayed_frame_time and time < state.displayed_frame_time - frame_duration then
		warnQueueState(state, name, "queue_reset_backward", time)
		clearQueue(state)
		state.displayed_frame_time = nil
		state.pending = false
	end
	local first_frame = state.queue[1]
	local last_frame = state.queue[#state.queue]
	if last_frame and last_frame.frame_time < time - frame_duration then
		warnQueueState(state, name, "queue_reset_stale", time)
		clearQueue(state)
		state.pending = false
	elseif first_frame and first_frame.frame_time > time + frame_duration * BUFFER_TARGET then
		warnQueueState(state, name, "queue_reset_future", time)
		clearQueue(state)
		state.pending = false
	end

	-- A frame can be presented up to half a frame in the future. Do not treat
	-- that tiny lead as a backward seek, but still prefetch if the queue is low.
	if
		#state.queue >= BUFFER_LOW_WATERMARK
		and state.displayed_frame_time
		and time < state.displayed_frame_time + frame_duration * 0.95
	then
		return
	end
	if #state.queue >= BUFFER_LOW_WATERMARK then
		return
	end

	local request_time = time
	local last_frame = state.queue[#state.queue]
	if last_frame then
		request_time = math.max(request_time, last_frame.frame_time + frame_duration)
	elseif state.displayed_frame_time then
		request_time = math.max(request_time, state.displayed_frame_time + frame_duration)
	end
	self:sendFrameRequest(name, request_time)
end

---@param event table
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
		local BgaPreviewDebug = require("rizu.preview.BgaPreviewDebug")
		BgaPreviewDebug.warn("video_main", "miss", event.video_name, "id=" .. tostring(event.request_id), "time=" .. tostring(event.requested_time))
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
		local BgaPreviewDebug = require("rizu.preview.BgaPreviewDebug")
		BgaPreviewDebug.warn(
			"video_main",
			"non_monotonic",
			event.video_name,
			"prev=" .. tostring(last_frame.frame_time),
			"frame=" .. tostring(event.frame_time),
			"queue=" .. tostring(#state.queue)
		)
	end
	table.insert(state.queue, {
		frame_time = event.frame_time,
		image_data = event.image_data,
		width = event.width,
		height = event.height,
		frame_rate = frame_rate,
	})
end

---@param event table
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
	local lateness = time - frame.frame_time
	releaseFrame(frame)
	if dropped_frames > 1 or lateness > state.frame_duration * 1.5 then
		warnQueueState(
			state,
			name,
			"queue_skip",
			time,
			"dropped=" .. tostring(dropped_frames) .. " lateness=" .. ("%.3f"):format(lateness)
		)
	end
	local elapsed = love.timer.getTime() - t0
	if elapsed >= SLOW_MAIN_SECONDS then
		local BgaPreviewDebug = require("rizu.preview.BgaPreviewDebug")
		BgaPreviewDebug.warn(
			"video_main",
			"slow_present",
			name,
			"queue=" .. tostring(#queue),
			"frame=" .. tostring(frame.frame_time),
			("%.3f"):format(elapsed)
		)
	end
end

function AsyncVideoEngine:update()
	local t0 = love.timer.getTime()
	if self.thread then
		local err = self.thread:getError()
		if err then
			error(err)
		end
	end
	if not self.output_channel then
		return
	end

	local event = self.output_channel:pop()
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
		if frame_events >= MAX_OUTPUT_FRAMES_PER_UPDATE then
			break
		end
		event = self.output_channel:pop()
	end
	local elapsed = love.timer.getTime() - t0
	if elapsed >= SLOW_MAIN_SECONDS then
		local BgaPreviewDebug = require("rizu.preview.BgaPreviewDebug")
		BgaPreviewDebug.warn(
			"video_main",
			"slow_update",
			"frames=" .. tostring(frame_events),
			"control=" .. tostring(control_events),
			("%.3f"):format(elapsed)
		)
	end
end

function AsyncVideoEngine:unload()
	for _, state in pairs(self.videos) do
		clearQueue(state)
		state.video:release()
	end
	self.videos = {}
	self.generation = self.generation + 1

	if self.input_channel then
		self.input_channel:push({type = "stop"})
	end
	self.input_channel = nil
	self.output_channel = nil
	self.thread = nil
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
