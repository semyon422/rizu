local class = require("class")
local BgaPreview = require("rizu.preview.BgaPreview")
local SpriteEngine = require("rizu.engine.sprite.SpriteEngine")
local VideoEngine = require("rizu.engine.sprite.VideoEngine")
local ResourceFinder = require("rizu.files.ResourceFinder")
local path_util = require("path_util")

---@class rizu.preview.BgaPreviewPlayer
---@operator call: rizu.preview.BgaPreviewPlayer
local BgaPreviewPlayer = class()

function BgaPreviewPlayer:new()
	self.sprite_engine = SpriteEngine()
	self.video_engine = VideoEngine()
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
---@param chart_dirs string|string[]
---@param fs fs.IFilesystem
function BgaPreviewPlayer:load(preview_path, chart_dirs, fs)
	self:stop()

	local data = fs:read(preview_path)
	if not data then return end

	local preview = BgaPreview()
	preview:decode(data)
	self.preview = preview

	self.events_by_column = {}
	for _, event in ipairs(preview.events) do
		self.events_by_column[event.column] = self.events_by_column[event.column] or {}
		table.insert(self.events_by_column[event.column], event)
	end

	local finder = ResourceFinder(fs)
	if type(chart_dirs) == "string" then
		chart_dirs = {chart_dirs}
	end
	for _, chart_dir in ipairs(chart_dirs) do
		if fs:getInfo(chart_dir) then
			finder:addPath(chart_dir)
		end
	end

	---@type string[]
	local image_names = {}
	---@type string[]
	local video_names = {}
	---@type {[string]: string}
	local resources = {}

	for _, name in ipairs(preview.samples) do
		local full_path = finder:findFile(name, "image") or finder:findFile(name, "video")
		if full_path then
			local content = fs:read(full_path)
			if content then
				resources[name] = content
				local _, ext = path_util.name_ext(name)
				if ResourceFinder:getFormat(ext) == "video" then
					table.insert(video_names, name)
				else
					table.insert(image_names, name)
				end
			end
		end
	end

	self.sprite_engine:load(image_names, resources)
	self.video_engine:load(video_names, resources)
end

function BgaPreviewPlayer:update(time)
	if not self.preview then return end

	local active_notes = {}
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

			table.insert(active_notes, {
				time = event.time,
				column = event.column,
				name = name,
				type = _type,
			})
		end
	end

	self.active_notes = active_notes
end

---@param time number
function BgaPreviewPlayer:seek(time)
	self:update(time)
	for _, bga_event in ipairs(self.active_notes) do
		if bga_event.type == "VideoNote" then
			local start_dt = time - bga_event.time
			self.video_engine:seek(bga_event.name, start_dt)
		end
	end
end

function BgaPreviewPlayer:stop()
	self.sprite_engine:unload()
	self.video_engine:unload()
	self.active_notes = {}
	self.events_by_column = {}
	self.preview = nil
end

function BgaPreviewPlayer:release()
	self:stop()
end

return BgaPreviewPlayer
