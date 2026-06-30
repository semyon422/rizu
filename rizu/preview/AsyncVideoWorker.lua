require("pkg_config")
require("love.filesystem")
require("love.image")
require("love.timer")

local BgaPreviewDebug = require("rizu.preview.BgaPreviewDebug")
local LoveFilesystem = require("fs.LoveFilesystem")
local video_module = require("video")

local input_channel_name, output_channel_name = ...
local input_channel = love.thread.getChannel(input_channel_name)
local output_channel = love.thread.getChannel(output_channel_name)

local BUFFER_TARGET = 45

local videos = {}
local video_paths = {}
local fs = LoveFilesystem()

local function closeVideos()
	for _, item in pairs(videos) do
		item.video:close()
	end
	videos = {}
end

---@param event table
local function loadVideos(event)
	closeVideos()
	video_paths = event.video_paths or {}
	output_channel:push({
		type = "loaded",
		generation = event.generation,
	})
end

---@param name string
---@return table?
local function openVideo(name)
	local item = videos[name]
	if item then
		return item
	end

	local path = video_paths[name]
	local content = path and fs:read(path)
	if not content then
		BgaPreviewDebug.warn("video_worker", "open_missing", name, path)
		return
	end

	local ot = love.timer.getTime()
	local file_data = love.filesystem.newFileData(content, tostring(name))
	local video = video_module.open(file_data:getPointer(), file_data:getSize())
	if not video then
		BgaPreviewDebug.warn("video_worker", "open_failed", name, ("%.3f"):format(love.timer.getTime() - ot))
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

---@param event table
local function sendMiss(event)
	output_channel:push({
		type = "frame",
		generation = event.generation,
		video_name = event.video_name,
		request_id = event.request_id,
		requested_time = event.time,
	})
end

---@param item table
---@param requested_time number?
---@return boolean
---@return string
local function shouldSeek(item, requested_time)
	if not requested_time then
		return false, "read"
	end
	if not item.last_frame_time then
		return true, "initial"
	end
	if requested_time < item.last_frame_time - 0.001 then
		return true, "backward"
	end
	local frame_duration = (item.frame_rate and item.frame_rate > 0 and 1 / item.frame_rate) or 1 / 30
	if requested_time - item.last_frame_time > frame_duration * 3 then
		return true, "jump"
	end
	return false, "read"
end

---@param event table
---@return table? next_event
local function readFrame(event)
	local item = openVideo(event.video_name)
	if not item then
		sendMiss(event)
		return
	end

	local count = event.count or BUFFER_TARGET
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
		local use_seek, seek_reason = shouldSeek(item, requested_time)
		if use_seek then
			frame_time = item.video:readAt(image_data:getPointer(), requested_time)
		else
			frame_time = item.video:read(image_data:getPointer())
		end
		local elapsed = love.timer.getTime() - t0
		if not frame_time then
			BgaPreviewDebug.warn("video_worker", "read_miss", event.video_name, "reason=" .. tostring(seek_reason), "req=" .. tostring(requested_time), ("%.3f"):format(elapsed))
			break
		end
		item.last_frame_time = frame_time
		if use_seek and seek_reason ~= "initial" then
			BgaPreviewDebug.warn("video_worker", "readAt", event.video_name, "reason=" .. tostring(seek_reason), "req=" .. tostring(requested_time), "frame=" .. tostring(frame_time))
		end
		if elapsed >= 0.15 then
			BgaPreviewDebug.warn("video_worker", "very_slow_read", event.video_name, "reason=" .. tostring(seek_reason), "req=" .. tostring(requested_time), "frame=" .. tostring(frame_time), ("%.3f"):format(elapsed))
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
