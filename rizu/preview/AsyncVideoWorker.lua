require("pkg_config")
require("love.filesystem")
require("love.image")
require("love.timer")

local AsyncVideoConfig = require("rizu.preview.AsyncVideoConfig")
require("rizu.preview.AsyncVideoProtocol")
local AsyncVideoReadPolicy = require("rizu.preview.AsyncVideoReadPolicy")
local BgaPreviewDebug = require("rizu.preview.BgaPreviewDebug")
local video_module = require("video")

local input_channel_name, output_channel_name = ...
local input_channel = love.thread.getChannel(input_channel_name)
local output_channel = love.thread.getChannel(output_channel_name)

local videos = {}
local video_paths = {}

---@class rizu.preview.AsyncVideoWorkerItem
---@field video table
---@field width integer
---@field height integer
---@field frame_rate number?
---@field duration number?
---@field last_frame_time number?

local function closeVideos()
	for _, item in pairs(videos) do
		item.video:close()
	end
	videos = {}
end

---@param event rizu.preview.AsyncVideoLoadEvent
local function loadVideos(event)
	closeVideos()
	video_paths = event.video_paths or {}
	output_channel:push({
		type = "loaded",
		generation = event.generation,
	})
end

---@param name string
---@return rizu.preview.AsyncVideoWorkerItem?
local function openVideo(name)
	local item = videos[name]
	if item then
		return item
	end

	local path = video_paths[name]
	if not path then
		BgaPreviewDebug:warnWorkerOpenMissing(name, path)
		return
	end

	local ot = love.timer.getTime()
	local video, err = video_module.openPath(path)
	if not video then
		BgaPreviewDebug:warnWorkerOpenFailed(name, love.timer.getTime() - ot, err)
		return
	end

	local width, height = video:getDimensions()
	local frame_rate = video.getFrameRate and video:getFrameRate() or nil
	local duration = video.getDuration and video:getDuration() or nil
	item = {
		video = video,
		width = width,
		height = height,
		frame_rate = frame_rate,
		duration = duration,
	}
	videos[name] = item
	return item
end

---@param event rizu.preview.AsyncVideoFrameRequestEvent
local function sendMiss(event)
	output_channel:push({
		type = "frame",
		generation = event.generation,
		video_name = event.video_name,
		request_id = event.request_id,
		requested_time = event.time,
	})
end

---@param item rizu.preview.AsyncVideoWorkerItem
---@return number
local function getFrameDuration(item)
	local frame_rate = item.frame_rate
	if frame_rate and frame_rate > 0 then
		return 1 / frame_rate
	end
	return 1 / 30
end

---@param item rizu.preview.AsyncVideoWorkerItem
---@param requested_time number
---@return boolean
local function isPastEnd(item, requested_time)
	local duration = item.duration
	return duration ~= nil and duration > 0 and requested_time > duration + getFrameDuration(item)
end

---@param event rizu.preview.AsyncVideoFrameRequestEvent
---@param item rizu.preview.AsyncVideoWorkerItem
---@return boolean sent
local function sendFinalFrame(event, item)
	local t0 = love.timer.getTime()
	local image_data = love.image.newImageData(item.width, item.height, "rgba8")
	local duration = item.duration or 0
	local frame_time = item.video:readAt(image_data:getPointer(), math.max(duration - getFrameDuration(item), 0))
	local elapsed = love.timer.getTime() - t0
	if not frame_time then
		BgaPreviewDebug:warnWorkerReadMiss(event.video_name, "jump", event.time, elapsed)
		return false
	end
	BgaPreviewDebug:warnWorkerEndHold(event.video_name, event.time, frame_time, duration, elapsed)
	item.last_frame_time = event.time
	output_channel:push({
		type = "frame",
		generation = event.generation,
		video_name = event.video_name,
		request_id = event.request_id,
		requested_time = event.time,
		frame_time = event.time,
		width = item.width,
		height = item.height,
		frame_rate = item.frame_rate,
		image_data = image_data,
		ended = true,
	})
	return true
end

---@param event rizu.preview.AsyncVideoFrameRequestEvent
---@return rizu.preview.AsyncVideoInputEvent? next_event
local function readFrame(event)
	local item = openVideo(event.video_name)
	if not item then
		sendMiss(event)
		return
	end

	local count = event.count or AsyncVideoConfig.buffer_target
	local start_time = event.time
	local sent = 0
	if isPastEnd(item, start_time) then
		if sendFinalFrame(event, item) then
			sent = 1
		end
		output_channel:push({
			type = "batch_done",
			generation = event.generation,
			video_name = event.video_name,
			request_id = event.request_id,
			requested_time = event.time,
			sent = sent,
		})
		return
	end

	local next_event
	for i = 1, count do
		local requested_time = i == 1 and start_time or nil
		local t0 = love.timer.getTime()
		local image_data = love.image.newImageData(item.width, item.height, "rgba8")
		local frame_time
		-- Use readAt only for the first frame of a batch after an actual seek/jump.
		-- Sequential frames must use read() so FFmpeg keeps decoder state warm.
		local use_seek, seek_reason = AsyncVideoReadPolicy.shouldSeek(item.last_frame_time, requested_time, item.frame_rate)
		if use_seek then
			frame_time = item.video:readAt(image_data:getPointer(), requested_time)
		else
			frame_time = item.video:read(image_data:getPointer())
		end
		local elapsed = love.timer.getTime() - t0
		if not frame_time then
			BgaPreviewDebug:warnWorkerReadMiss(event.video_name, seek_reason, requested_time, elapsed)
			break
		end
		item.last_frame_time = frame_time
		if use_seek and seek_reason ~= "initial" then
			BgaPreviewDebug:warnWorkerReadAt(event.video_name, seek_reason, requested_time, frame_time)
		end
		if elapsed >= 0.15 then
			BgaPreviewDebug:warnWorkerVerySlowRead(event.video_name, seek_reason, requested_time, frame_time, elapsed)
		end
		sent = sent + 1
		output_channel:push({
			type = "frame",
			generation = event.generation,
			video_name = event.video_name,
			request_id = event.request_id,
			requested_time = requested_time or frame_time,
			frame_time = frame_time,
			width = item.width,
			height = item.height,
			frame_rate = item.frame_rate,
			image_data = image_data,
		})
		next_event = input_channel:pop()
		if next_event then
			break
		end
	end
	output_channel:push({
		type = "batch_done",
		generation = event.generation,
		video_name = event.video_name,
		request_id = event.request_id,
		requested_time = event.time,
		sent = sent,
	})
	return next_event
end

local next_event
while true do
	---@type rizu.preview.AsyncVideoInputEvent
	local event = next_event or input_channel:demand()
	next_event = nil
	if event.type == "stop" then
		closeVideos()
		return
	elseif event.type == "load" then
		loadVideos(event)
	elseif event.type == "frame" then
		next_event = readFrame(event)
	elseif event.type == "unload" then
		closeVideos()
	end
end
