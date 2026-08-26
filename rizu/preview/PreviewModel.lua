local class = require("class")
local delay = require("delay")
local thread = require("thread")
local AudioPreviewPlayer = require("rizu.preview.AudioPreviewPlayer")
local BgaPreviewPlayer = require("rizu.preview.BgaPreviewPlayer")
local NotesPreviewPlayer = require("rizu.preview.NotesPreviewPlayer")
local ChartfileReader = require("rizu.library.ChartfileReader")
local IidxResourcePaths = require("rizu.library.iidx.ResourcePaths")
local Settings = require("rizu.config.Settings")

---@alias rizu.preview.PreviewMode "absolute"|"relative"

---@class rizu.preview.PreviewChartview
---@field hash string
---@field duration number?
---@field location_path string
---@field location_prefix string
---@field location_dir string
---@field chartfile_name string
---@field format sea.ChartFormat
---@field index integer

---@class rizu.preview.PreviewGenerationData
---@field hash string
---@field location_path string
---@field location_prefix string
---@field location_dir string
---@field preview_resource_dir string?
---@field chartfile_name string
---@field format sea.ChartFormat
---@field index integer

---@class rizu.preview.PreviewModel
---@operator call: rizu.preview.PreviewModel
local PreviewModel = class()

PreviewModel.preview_time = 0
PreviewModel.position = 0
PreviewModel.mode = "absolute"
PreviewModel.manual_time = 0

---@param chartview rizu.preview.PreviewChartview
---@return string?
local function get_preview_resource_dir(chartview)
	local archive_path = chartview.location_path and ChartfileReader.splitArchivePath(chartview.location_path)
	return archive_path or chartview.location_dir
end

---@param chartview rizu.preview.PreviewChartview
---@param fs fs.IFilesystem
---@return string[]
local function get_bga_preview_resource_paths(chartview, fs)
	---@type string[]
	local paths = {}
	local resource_dir = get_preview_resource_dir(chartview)
	if resource_dir then
		paths[#paths + 1] = resource_dir
	end
	local movie_path = IidxResourcePaths.getMoviePath(chartview, fs)
	if movie_path then
		paths[#paths + 1] = movie_path
	end
	return paths
end

---@param hash string
---@return string
local function get_audio_preview_path(hash)
	return "userdata/audio_previews/" .. hash .. ".audio_preview"
end

---@param settings rizu.config.Config
---@param replayBase sea.ReplayBase
---@param game table
function PreviewModel:new(settings, replayBase, game)
	self.settings = settings
	self.replayBase = replayBase
	self.game = game
	self.audioPreviewPlayer = AudioPreviewPlayer(settings)
	self.bgaPreviewPlayer = BgaPreviewPlayer()
	self.chartPreview = NotesPreviewPlayer(settings, self, replayBase, game)
	---@type {[string]: boolean?}
	self.generating_hashes = {}
	---@type {[string]: boolean?}
	self.attempted_hashes = {}

	self.loaded_audio_path = nil
	self.loaded_preview_time = nil
	self.loaded_mode = nil
	self.loaded_hash = nil
	self.loaded_audio_hash = nil
	self.initial_seek_done = false
end

function PreviewModel:load()
	self.active = true
	self.released = false
	self.paused = false
	self.audio_path = ""
	self.volume = 0
	self.rate = 1
	self.target_rate = 1
end

---@param audio_path string?
---@param preview_time number?
---@param mode rizu.preview.PreviewMode?
---@param chartview rizu.preview.PreviewChartview?
function PreviewModel:setAudioPathPreview(audio_path, preview_time, mode, chartview)
	if not self.active then
		return
	end
	if self.audio_path ~= audio_path or self.chartview ~= chartview or self.preview_time ~= preview_time or self.mode ~= mode then
		self.audio_path = audio_path
		self.preview_time = preview_time
		self.mode = mode
		self.chartview = chartview

		self:loadPreviewDebounce()
	end
end

function PreviewModel:update()
	if not self.active then
		self.audioPreviewPlayer:pause()
		return
	end

	local keys = Settings.keys
	local mute_on_unfocus = self.settings:getBoolean(keys.misc.mute_on_unfocus)
	local hasFocus = love.window.hasFocus()

	if hasFocus or not mute_on_unfocus then
		local min_time, max_time = self.audioPreviewPlayer:getRange()
		local duration = max_time - min_time

		if duration > 0 then
			self.manual_time = self.audioPreviewPlayer:getPosition()

			-- Default start position to min_time if preview_time is missing
			if not self.initial_seek_done then
				if self.preview_time then
					self.initial_seek_done = true
				elseif self.manual_time < min_time then
					self.manual_time = min_time
					self.audioPreviewPlayer:seek(self.manual_time)
					self.bgaPreviewPlayer:seek(self.manual_time)
					self.initial_seek_done = true
				end
			end

			-- Looping: Restart from audio start time (min_time)
			if self.manual_time >= max_time then
				self.manual_time = min_time
				self.audioPreviewPlayer:seek(self.manual_time)
				self.bgaPreviewPlayer:seek(self.manual_time)
			end
			if self.paused then
				self.audioPreviewPlayer:pause()
			else
				self.audioPreviewPlayer:resume()
			end
		else
			self.audioPreviewPlayer:pause()
		end
	else
		self.audioPreviewPlayer:pause()
	end

	self.audioPreviewPlayer:update()
	self.bgaPreviewPlayer:update(self:getTime())
	self.chartPreview:update()

	local volume = self.settings:getNumber(keys.audio.volume_master)
		* self.settings:getNumber(keys.audio.volume_music)
	if self.volume ~= volume then
		self.audioPreviewPlayer:setVolume(volume)
		self.volume = volume
	end

	local target_rate = self.target_rate
	if self.rate ~= target_rate then
		self.audioPreviewPlayer:setRate(target_rate)
		self.rate = target_rate
	end
end

---@param rate number
function PreviewModel:setRate(rate)
	self.target_rate = rate
end

function PreviewModel:pause()
	self.paused = true
	self.audioPreviewPlayer:pause()
end

function PreviewModel:resume()
	self.paused = false
	self.audioPreviewPlayer:resume()
end

function PreviewModel:togglePause()
	if self.paused then
		self:resume()
	else
		self:pause()
	end
end

function PreviewModel:getTime()
	return self.manual_time
end

---@param time number
function PreviewModel:setPosition(time)
	time = math.max(time or 0, 0)
	self.position = time
	self.manual_time = time
	self.initial_seek_done = true
	self.audioPreviewPlayer:seek(time)
	self.bgaPreviewPlayer:seek(time)
end

---@param progress number
function PreviewModel:setRelativePosition(progress)
	local min_time, max_time = self:getRange()
	local duration = math.max(max_time - min_time, 0)
	progress = math.max(progress or 0, 0)
	if duration <= 0 then
		self:setPosition(min_time)
		return
	end

	self:setPosition(min_time + math.min(progress, 1) * duration)
end

---@return number, number
function PreviewModel:getRange()
	return self.audioPreviewPlayer:getRange()
end

---@return number
function PreviewModel:getDuration()
	local min_time, max_time = self:getRange()
	return math.max(max_time - min_time, 0)
end

---@return number
function PreviewModel:getRelativePosition()
	local min_time, max_time = self:getRange()
	local duration = math.max(max_time - min_time, 0)
	if duration <= 0 then
		return 0
	end
	return math.min(math.max((self.manual_time - min_time) / duration, 0), 1)
end

---@param size integer
function PreviewModel:setFFTSize(size)
	self.audioPreviewPlayer:setFFTSize(size)
end

---@return ffi.cdata*?
function PreviewModel:getFFT()
	return self.audioPreviewPlayer:getFFT()
end

function PreviewModel:loadPreviewDebounce()
	delay.debounce(self, "loadDebounce", 0.1, self.loadPreview, self)
end

local loadingPreview = false
function PreviewModel:loadPreview()
	if loadingPreview then
		return
	end
	loadingPreview = true

	local path = self.audio_path
	local preview_time = self.preview_time
	local mode = self.mode

	if not path then
		loadingPreview = false
		self:stop()
		return
	end

	self.chartPreview:setChartview(self.chartview)

	local audio_needs_reload = (self.loaded_audio_path ~= path)
		or (self.loaded_preview_time ~= preview_time)
		or (self.loaded_mode ~= mode)
		or (path == "")

	if audio_needs_reload then
		self.audioPreviewPlayer:stop()
		self.bgaPreviewPlayer:stop()
		self.loaded_audio_path = path
		self.loaded_preview_time = preview_time
		self.loaded_mode = mode
		self.loaded_hash = nil
		self.loaded_audio_hash = nil
		self.initial_seek_done = false
	end

	loadingPreview = false
	if path ~= self.audio_path then
		self:loadPreview()
		return
	end

	local keys = Settings.keys
	local volume = self.settings:getNumber(keys.audio.volume_master)
		* self.settings:getNumber(keys.audio.volume_music)

	local position = preview_time or 0
	if mode == "relative" then
		position = (self.chartview and self.chartview.duration or 0) * position
	end
	position = math.max(position, 0)

	if audio_needs_reload then
		self.position = position
		self.manual_time = position
	end

	---@type string?
	local hash = self.chartview and self.chartview.hash
	if hash then
		local audio_preview_path = get_audio_preview_path(hash)
		local bga_preview_path = "userdata/bga_previews/" .. hash .. ".bga_preview"

		local audio_exists = love.filesystem.getInfo(audio_preview_path)
		local bga_exists = love.filesystem.getInfo(bga_preview_path)

		if audio_exists and self.loaded_audio_hash ~= hash then
			self.loaded_audio_hash = hash
			self.audioPreviewPlayer:load(audio_preview_path, get_preview_resource_dir(self.chartview))
			self.audioPreviewPlayer:setVolume(volume)
			self.audioPreviewPlayer:setRate(self.rate)
			self.audioPreviewPlayer:seek(position)
		end

		if bga_exists and self.loaded_hash ~= hash then
			self.loaded_hash = hash
			local LoveFilesystem = require("fs.LoveFilesystem")
			local fs = LoveFilesystem()
			self.bgaPreviewPlayer:load(
				bga_preview_path,
				get_bga_preview_resource_paths(self.chartview, fs),
				fs
			)
			self.bgaPreviewPlayer:seek(self:getTime())
		end

		if not audio_exists or not bga_exists then
			if not self.attempted_hashes[hash] then
				self:generatePreview(self.chartview)
			end
		end
	end

	self.volume = volume

	self:update()
end

local generatePreviewAsync = thread.async(function(chartview_data)
	---@cast chartview_data rizu.preview.PreviewGenerationData
	print("Preview: generating " .. chartview_data.hash)
	local AudioPreviewGenerator = require("rizu.preview.AudioPreviewGenerator")
	local BgaPreviewGenerator = require("rizu.preview.BgaPreviewGenerator")
	local Decoder = require("rizu.engine.audio.bass.Decoder")
	local ChartFactory = require("chart.format.notechart.ChartFactory")
	local ChartfileReader = require("rizu.library.ChartfileReader")
	local IidxDecodeContext = require("chart.format.iidx.DecodeContext")
	local LoveFilesystem = require("fs.LoveFilesystem")

	require("love.filesystem")

	local fs = LoveFilesystem()
	local audio_generator = AudioPreviewGenerator(fs, function(data)
		return Decoder(data)
	end)
	local bga_generator = BgaPreviewGenerator(fs)

	local content = ChartfileReader.read(fs, chartview_data.location_path)
	if not content then
		print("Preview: could not read " .. tostring(chartview_data.location_path))
		return false
	end
	local decode_context
	if chartview_data.format == "iidx" then
		decode_context = IidxDecodeContext.fromLocation(
			fs,
			chartview_data.location_prefix,
			chartview_data.chartfile_name
		)
	end

	local chart_chartmetas = ChartFactory:getCharts(
		chartview_data.chartfile_name,
		content,
		chartview_data.hash,
		decode_context
	)
	if not chart_chartmetas then
		print("Preview: chart parsing failed for " .. tostring(chartview_data.chartfile_name))
		return false
	end

	local t = chart_chartmetas[chartview_data.index]
	if not t then
		print("Preview: chart index " .. tostring(chartview_data.index) .. " not found")
		return false
	end

	t.chart.layers.main:toAbsolute()

	local audio_preview_path = "userdata/audio_previews/" .. chartview_data.hash .. ".audio_preview"
	if not fs:getInfo(audio_preview_path) then
		audio_generator:generate(t.chart, chartview_data.preview_resource_dir, chartview_data.hash)
	end

	local bga_preview_path = "userdata/bga_previews/" .. chartview_data.hash .. ".bga_preview"
	if not fs:getInfo(bga_preview_path) then
		bga_generator:generate(t.chart, chartview_data.hash)
	end

	return true
end)

---@param chartview rizu.preview.PreviewChartview
function PreviewModel:generatePreview(chartview)
	local hash = chartview.hash
	if self.generating_hashes[hash] then
		return
	end
	self.generating_hashes[hash] = true

	---@type rizu.preview.PreviewGenerationData
	local chartview_data = {
		location_path = chartview.location_path,
		location_prefix = chartview.location_prefix,
		location_dir = chartview.location_dir,
		preview_resource_dir = get_preview_resource_dir(chartview),
		chartfile_name = chartview.chartfile_name,
		format = chartview.format,
		index = chartview.index,
		hash = hash,
	}

	thread.coro(function()
		local ok, result = pcall(generatePreviewAsync, chartview_data)
		self.generating_hashes[hash] = nil
		self.attempted_hashes[hash] = true
		if ok and result then
			if self.chartview and self.chartview.hash == hash then
				self:loadPreview()
			end
		else
			print("Preview: generation failed for " .. hash .. " error: " .. tostring(result))
		end
	end)()
end

function PreviewModel:stop()
	self.active = false
	self.audioPreviewPlayer:stop()
	self.bgaPreviewPlayer:stop()
	self.chartPreview:setChartview(nil)
	self.manual_time = 0
	self.loaded_audio_path = nil
	self.loaded_preview_time = nil
	self.loaded_mode = nil
	self.loaded_hash = nil
	self.loaded_audio_hash = nil
	self.initial_seek_done = false
	self.audio_path = nil
	self.chartview = nil
	self.preview_time = nil
	self.mode = nil
end

function PreviewModel:release()
	if self.released then
		return
	end
	self.released = true
	self:stop()
	self.audioPreviewPlayer:release()
	self.bgaPreviewPlayer:release()
end

return PreviewModel
