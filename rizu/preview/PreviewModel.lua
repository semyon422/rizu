local class = require("class")
local AudioPreviewPlayer = require("rizu.preview.AudioPreviewPlayer")
local BgaPreviewPlayer = require("rizu.preview.BgaPreviewPlayer")
local NotesPreviewPlayer = require("rizu.preview.NotesPreviewPlayer")
local PreviewLoader = require("rizu.preview.PreviewLoader")
local PreviewSkinCache = require("rizu.preview.PreviewSkinCache")
local Settings = require("rizu.config.Settings")

---@alias rizu.preview.PreviewMode "absolute"|"relative"

---@class rizu.preview.PreviewChartview
---@field chartmeta_mode string?
---@field chartdiff_inputmode string?
---@field hash string
---@field notes_preview string?
---@field chartdiff_id integer?
---@field modifiers sea.Modifier[]?
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
---@field regenerate_notes boolean?
---@field chartdiff_id integer?
---@field previous_notes_preview string?
---@field modifiers sea.Modifier[]?

---@class rizu.preview.PreviewModel
---@field game sphere.GameController
---@field settings rizu.config.Config
---@field skinCache rizu.preview.PreviewSkinCache
---@field loader rizu.preview.PreviewLoader
---@field chartview rizu.preview.PreviewChartview?
---@field loaded_audio_path string?
---@field loaded_hash string?
---@field loaded_audio_hash string?
---@operator call: rizu.preview.PreviewModel
local PreviewModel = class()

PreviewModel.preview_time = 0
PreviewModel.position = 0
PreviewModel.mode = "absolute"
PreviewModel.manual_time = 0

---@param settings rizu.config.Config
---@param replayBase sea.ReplayBase
---@param game table
function PreviewModel:new(settings, replayBase, game)
	self.settings = settings
	self.replayBase = replayBase
	self.game = game
	self.audioPreviewPlayer = AudioPreviewPlayer(settings)
	self.bgaPreviewPlayer = BgaPreviewPlayer()
	self.chartPreview = NotesPreviewPlayer(settings, self, replayBase)
	self.skinCache = PreviewSkinCache(game, settings)
	self.loader = PreviewLoader(self)

	self.loaded_audio_path = nil
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
	self.loader:load()
	self.skinCache:load()
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

		-- Invalidate pending media before a custom skin hook can yield.
		self.chartPreview:setChartview(nil)
		self.loader:loadPreviewDebounce()
		self.skinCache:bind(chartview)
	end
end

---@param dt number?
function PreviewModel:update(dt)
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
	self.skinCache:update(dt or 0, self.chartview)

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

---@param media rizu.preview.PreviewLoader.Media?
---@param path string
---@param preview_time number?
---@param mode rizu.preview.PreviewMode?
---@param chartview rizu.preview.PreviewChartview?
function PreviewModel:applyPreparedMedia(media, path, preview_time, mode, chartview)
	local audio_needs_reload = self.loaded_audio_path ~= path or path == ""
	if audio_needs_reload then
		self.audioPreviewPlayer:stop()
		self.bgaPreviewPlayer:stop()
		if not self.active or path ~= self.audio_path or chartview ~= self.chartview then return end
		self.loaded_audio_path = path
		self.loaded_hash = nil
		self.loaded_audio_hash = nil
		self.initial_seek_done = false
	end
	local volume = self.settings:getNumber(Settings.keys.audio.volume_master)
		* self.settings:getNumber(Settings.keys.audio.volume_music)
	local position = preview_time or 0
	if mode == "relative" then position = (chartview and chartview.duration or 0) * position end
	position = math.max(position, 0)
	if audio_needs_reload then self.position, self.manual_time = position, position end
	if chartview and media then
		local hash = chartview.hash
		if media.audio_exists and self.loaded_audio_hash ~= hash
			and (audio_needs_reload or self.loaded_audio_hash == nil) then
			self.loaded_audio_hash = hash
			self.audioPreviewPlayer:load("userdata/audio_previews/" .. hash .. ".audio_preview", media.audio_resource_dir or "")
			self.audioPreviewPlayer:setVolume(volume)
			self.audioPreviewPlayer:setRate(self.rate)
			self.audioPreviewPlayer:seek(position)
		end
		if media.bga_exists and self.loaded_hash ~= hash then
			self.loaded_hash = hash
			self.bgaPreviewPlayer:load("userdata/bga_previews/" .. hash .. ".bga_preview", media.bga_paths)
			self.bgaPreviewPlayer:seek(self:getTime())
		end
	end
	self.volume = volume
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

---@return rizu.gameplay.views.PlayfieldRenderer?
function PreviewModel:getPlayfield() return self.skinCache:getPlayfield() end

---@return rizu.preview.PreviewSkinCache.State
function PreviewModel:getSkinState() return self.skinCache:getState() end

---@return string?
function PreviewModel:getSkinError() return self.skinCache:getError() end

---@return rizu.preview.PreviewLoader.State
function PreviewModel:getMediaState() return self.loader.media_state end

---@return string?
function PreviewModel:getMediaError() return self.loader.media_error end

function PreviewModel:stop()
	self.active = false
	self.loader:stop()
	self.skinCache:stop()
	self.audioPreviewPlayer:stop()
	self.bgaPreviewPlayer:stop()
	self.chartPreview:setChartview(nil)
	self.manual_time = 0
	self.loaded_audio_path = nil
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
	self.loader:release()
	self.skinCache:release()
	self.audioPreviewPlayer:release()
	self.bgaPreviewPlayer:release()
end

return PreviewModel
