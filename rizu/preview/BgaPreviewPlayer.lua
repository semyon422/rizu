local class = require("class")
local BgaPreview = require("rizu.preview.BgaPreview")
local AsyncVideoEngine = require("rizu.preview.AsyncVideoEngine")
local SpriteEngine = require("rizu.engine.sprite.SpriteEngine")
local ResourceFinder = require("rizu.files.ResourceFinder")
local path_util = require("path_util")
local thread = require("thread")

---@class rizu.preview.BgaPreviewPlayer
---@operator call: rizu.preview.BgaPreviewPlayer
local BgaPreviewPlayer = class()

---@class rizu.preview.LoadedBgaPreviewResources
---@field samples string[]
---@field events rizu.preview.BgaPreviewEvent[]
---@field image_names string[]
---@field video_names string[]
---@field resources {[string]: string}
---@field video_paths {[string]: string}

function BgaPreviewPlayer:new()
	self.sprite_engine = SpriteEngine()
	self.video_engine = AsyncVideoEngine()
	self.load_generation = 0
	---@type rizu.sprite.BgaEvent[]
	self.active_notes = {}
	---@type {[integer]: rizu.preview.BgaPreviewEvent[]}
	self.events_by_column = {}
end

---@param notes rizu.preview.BgaPreviewEvent[]
---@param time number
---@return integer?
local function _findBgaIndex(notes, time)
	local low, high = 1, #notes
	local ans = nil
	while low <= high do
		local mid = math.floor((low + high) / 2)
		if notes[mid].time <= time then
			ans = mid
			low = mid + 1
		else
			high = mid - 1
		end
	end
	return ans
end

---@param preview_path string
---@param chart_dirs string[]?
---@return rizu.preview.LoadedBgaPreviewResources?
local loadPreviewResourcesAsync = thread.async(function(preview_path, chart_dirs)
	require("love.filesystem")

	local BgaPreview = require("rizu.preview.BgaPreview")
	local LoveFilesystem = require("fs.LoveFilesystem")
	local ResourceFinder = require("rizu.files.ResourceFinder")
	local path_util = require("path_util")

	local fs = LoveFilesystem()
	local data = fs:read(preview_path)
	if not data then
		return
	end

	local preview = BgaPreview()
	preview:decode(data)

	local finder = ResourceFinder(fs)
	if type(chart_dirs) == "string" then
		chart_dirs = {chart_dirs}
	end
	chart_dirs = chart_dirs or {}
	for _, chart_dir in ipairs(chart_dirs) do
		if fs:getInfo(chart_dir) then
			finder:addPath(chart_dir)
		end
	end

	---@type rizu.preview.LoadedBgaPreviewResources
	local result = {
		samples = preview.samples,
		events = preview.events,
		image_names = {},
		video_names = {},
		resources = {},
		video_paths = {},
	}

	for _, name in ipairs(preview.samples) do
		local full_path = finder:findFile(name, "image") or finder:findFile(name, "video")
		if full_path then
			local _, ext = path_util.name_ext(name)
			if ResourceFinder:getFormat(ext) == "video" then
				if fs:getInfo(full_path) then
					table.insert(result.video_names, name)
					result.video_paths[name] = full_path
				end
			else
				local content = fs:read(full_path)
				if content then
					result.resources[name] = content
					table.insert(result.image_names, name)
				end
			end
		end
	end

	return result
end)

---@param result rizu.preview.LoadedBgaPreviewResources
function BgaPreviewPlayer:applyLoadedPreview(result)
	local preview = BgaPreview()
	preview.samples = result.samples
	preview.events = result.events
	self.preview = preview

	self.events_by_column = {}
	for _, event in ipairs(preview.events) do
		self.events_by_column[event.column] = self.events_by_column[event.column] or {}
		table.insert(self.events_by_column[event.column], event)
	end

	self.sprite_engine:load(result.image_names, result.resources)
	self.video_engine:load(result.video_names, result.video_paths)

	if self.pending_seek then
		local pending_seek = self.pending_seek
		self.pending_seek = nil
		self:seek(pending_seek)
	end
end

---@param preview_path string
---@param chart_dirs string|string[]
---@param fs fs.IFilesystem
function BgaPreviewPlayer:load(preview_path, chart_dirs, _fs)
	self:stop()
	self.load_generation = self.load_generation + 1
	local generation = self.load_generation

	if type(chart_dirs) == "string" then
		chart_dirs = {chart_dirs}
	end
	chart_dirs = chart_dirs or {}

	thread.coro(function()
		local ok, result = pcall(loadPreviewResourcesAsync, preview_path, chart_dirs)
		if generation ~= self.load_generation then
			return
		end
		if not ok or not result then
			return
		end
		---@cast result rizu.preview.LoadedBgaPreviewResources
		self:applyLoadedPreview(result)
	end)()
end

function BgaPreviewPlayer:update(time)
	self.video_engine:update()
	if not self.preview then return end

	local active_notes = {}
	---@type {[string]: integer}
	local active_video_indexes = {}
	local columns = {}
	for column in pairs(self.events_by_column) do
		table.insert(columns, column)
	end
	table.sort(columns)

	for _, column in ipairs(columns) do
		local notes = self.events_by_column[column]
		local index = _findBgaIndex(notes, time)
		if index then
			local event = notes[index]
			local name = self.preview.samples[event.sample_index]
			local _, ext = path_util.name_ext(name)
			local _type = ResourceFinder:getFormat(ext) == "video" and "VideoNote" or "ImageNote"

			local bga_event = {
				time = event.time,
				column = event.column,
				name = name,
				type = _type,
			}

			if _type == "VideoNote" then
				-- A video resource has one playback cursor. Some BGA files put the same
				-- video on several columns, so drive each video name only once per frame.
				local active_index = active_video_indexes[name]
				local active_event = active_index and active_notes[active_index]
				if not active_event or bga_event.time >= active_event.time then
					if active_index then
						active_notes[active_index] = bga_event
					else
						active_video_indexes[name] = #active_notes + 1
						table.insert(active_notes, bga_event)
					end
				end
			else
				table.insert(active_notes, bga_event)
			end
		end
	end

	table.sort(active_notes, function(a, b)
		return a.column < b.column
	end)

	self.active_notes = active_notes
end

---@param time number
function BgaPreviewPlayer:seek(time)
	if not self.preview then
		self.pending_seek = time
		return
	end

	self:update(time)
	for _, bga_event in ipairs(self.active_notes) do
		if bga_event.type == "VideoNote" then
			local start_dt = time - bga_event.time
			self.video_engine:seek(bga_event.name, start_dt)
		end
	end
end

function BgaPreviewPlayer:stop()
	self.load_generation = (self.load_generation or 0) + 1
	self.sprite_engine:unload()
	self.video_engine:unload()
	self.active_notes = {}
	self.events_by_column = {}
	self.preview = nil
	self.pending_seek = nil
end

function BgaPreviewPlayer:release()
	self:stop()
end

return BgaPreviewPlayer
