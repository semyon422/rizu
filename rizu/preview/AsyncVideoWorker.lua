require("pkg_config")
require("love.filesystem")
require("love.image")
require("love.timer")

local AsyncVideoConfig = require("rizu.preview.AsyncVideoConfig")
require("rizu.preview.AsyncVideoProtocol")
local AsyncVideoReadPolicy = require("rizu.preview.AsyncVideoReadPolicy")
local BgaPreviewDebug = require("rizu.preview.BgaPreviewDebug")
local LoveFilesystem = require("fs.LoveFilesystem")
local video_module = require("video")

local input_channel_name, output_channel_name = ...
local input_channel = love.thread.getChannel(input_channel_name)
local output_channel = love.thread.getChannel(output_channel_name)

local videos = {}
local video_paths = {}
local fs = LoveFilesystem()

---@class rizu.preview.AsyncVideoWorkerItem
---@field file_data love.FileData
---@field video table
---@field width integer
---@field height integer
---@field frame_rate number?
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
	local content = path and fs:read(path)
	if not content then
		BgaPreviewDebug:warnWorkerOpenMissing(name, path)
		return
	end

	local ot = love.timer.getTime()
	local file_data = love.filesystem.newFileData(content, tostring(name))
	local video = video_module.open(file_data:getPointer(), file_data:getSize())
	if not video then
		BgaPreviewDebug:warnWorkerOpenFailed(name, love.timer.getTime() - ot)
		return
	end

	local width, height = video:getDimensions()
	local frame_rate = video.getFrameRate and video:getFrameRate() or nil
	item = {
		file_data = file_data,
		video = video,
		width = width,
		height = height,
		frame_rate = frame_rate,
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
