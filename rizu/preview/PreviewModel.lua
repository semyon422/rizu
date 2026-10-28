local class = require("class")
local AudioPreviewPlayer = require("rizu.preview.AudioPreviewPlayer")
local BgaPreviewPlayer = require("rizu.preview.BgaPreviewPlayer")
local NotesPreviewPlayer = require("rizu.preview.NotesPreviewPlayer")
local PreviewLoader = require("rizu.preview.PreviewLoader")
local PreviewSkinCache = require("rizu.preview.PreviewSkinCache")
local RemoteAudioPreviewPlayer = require("rizu.preview.RemoteAudioPreviewPlayer")
local Settings = require("rizu.config.Settings")

---@alias rizu.preview.PreviewMode "absolute"|"relative"

---Where the audio of a newly selected chart starts.
---@alias rizu.preview.StartMode
---| "chart" # The chart's preview time, or a random position with the random preview position setting.
---| "start" # The start of the audio.

---What happens when the audio reaches its end.
---@alias rizu.preview.EndAction
---| "loop" # It starts again from the start.
---| "random_chart" # A random set gets selected. Its chart is skipped too when it has no audio.

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
---@field remote boolean The audio is the preview of a chart of a remote location, not a generated one.
---@field remote_audio rizu.preview.RemoteAudioPreviewPlayer?
---@field start_mode rizu.preview.StartMode
---@field end_action rizu.preview.EndAction
---@field waiting_next boolean The audio ended and the media of a random chart is awaited.
---@field skipped_generation integer? The media generation already skipped for having no audio.
---@operator call: rizu.preview.PreviewModel
local PreviewModel = class()

PreviewModel.preview_time = 0
PreviewModel.position = 0
PreviewModel.mode = "absolute"
PreviewModel.manual_time = 0
PreviewModel.start_mode = "chart"
PreviewModel.end_action = "loop"
PreviewModel.waiting_next = false

---@param settings rizu.config.Config
---@param configurator rizu.gameplay.ReplayBaseConfigurator
---@param game table
function PreviewModel:new(settings, configurator, game)
	self.settings = settings
	self.configurator = configurator
	self.game = game
	self.audioPreviewPlayer = AudioPreviewPlayer(settings)
	self.bgaPreviewPlayer = BgaPreviewPlayer()
	self.chartPreview = NotesPreviewPlayer(settings, self, configurator)
	self.skinCache = PreviewSkinCache(game, settings)
	self.loader = PreviewLoader(self)

	self.loaded_audio_path = nil
	self.loaded_hash = nil
	self.loaded_audio_hash = nil
	self.initial_seek_done = false
	self.remote = false
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

---Takes effect from the next chart, the playing audio keeps its position.
---@param start_mode rizu.preview.StartMode
---@param end_action rizu.preview.EndAction
function PreviewModel:setModes(start_mode, end_action)
	self.start_mode = start_mode
	self.end_action = end_action
	self.waiting_next = self.waiting_next and end_action == "random_chart"
end

---The player of the audio that is selected now.
---@return rizu.preview.AudioPreviewPlayer|rizu.preview.RemoteAudioPreviewPlayer
function PreviewModel:getAudioPlayer()
	return self.remote and self.remote_audio or self.audioPreviewPlayer
end

---Plays the audio preview of a chart of a remote location in place of a generated one: from its start, in a loop.
---@param data string The audio file.
---@param path string Its url, the audio path this was loaded for.
---@param chartview rizu.preview.PreviewChartview?
---@return true?
---@return string?
function PreviewModel:applyRemoteAudio(data, path, chartview)
	if self.remote and self.loaded_audio_path == path then
		-- The same audio keeps playing, like a local one.
		return true
	end
	self.audioPreviewPlayer:stop()
	self.bgaPreviewPlayer:stop()
	if not self.active or path ~= self.audio_path or chartview ~= self.chartview then return true end
	self.loaded_audio_path = path
	self.loaded_hash = nil
	self.loaded_audio_hash = nil
	self.remote_audio = self.remote_audio or RemoteAudioPreviewPlayer(
		self.settings,
		require("rizu.engine.audio.bass.Provider")()
	)
	local ok, err = self.remote_audio:load(data)
	self.remote = ok == true
	if not ok then
		return nil, err
	end
	self.position, self.manual_time = 0, 0
	self.initial_seek_done = true
	self.waiting_next = false
	-- The new player takes the volume on the next update.
	self.volume = -1
	self.remote_audio:setRate(self.rate)
	return true
end

---@private
function PreviewModel:stopRemoteAudio()
	self.remote = false
	if self.remote_audio then self.remote_audio:stop() end
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
	local player = self:getAudioPlayer()
	if not self.active then
		player:pause()
		return
	end

	local keys = Settings.keys
	local mute_on_unfocus = self.settings:getBoolean(keys.misc.mute_on_unfocus)
	local hasFocus = love.window.hasFocus()

	if hasFocus or not mute_on_unfocus then
		local min_time, max_time = player:getRange()
		local duration = max_time - min_time

		if duration > 0 then
			self.manual_time = player:getPosition()

			if not self.initial_seek_done then
				self.initial_seek_done = true
				local time = self.manual_time
				if self.start_mode == "start" or not self.preview_time then
					time = min_time
				elseif self.settings:getBoolean(keys.select.random_preview_position) then
					time = min_time + duration * (0.2 + math.random() * 0.6)
				end
				if time ~= self.manual_time then
					self:seekPlayers(time)
				end
			end

			-- A remote preview ends a moment before its decoder's duration.
			if not self.waiting_next and self.manual_time >= max_time - (self.remote and 0.05 or 0) then
				if self.end_action == "random_chart" and self.game.chartSelector:scrollRandom() then
					self.waiting_next = true
				else
					self:seekPlayers(min_time)
				end
			end
			if self.paused or self.waiting_next then
				player:pause()
			else
				player:resume()
			end
		else
			player:pause()
		end
	else
		player:pause()
	end

	self:skipSilentChart()

	player:update()
	self.bgaPreviewPlayer:update(self:getTime())
	self.chartPreview:update()
	self.skinCache:update(dt or 0, self.chartview)

	local volume = self.settings:getNumber(keys.audio.volume_master)
		* self.settings:getNumber(keys.audio.volume_music)
	if self.volume ~= volume then
		player:setVolume(volume)
		self.volume = volume
	end

	local target_rate = self.target_rate
	if self.rate ~= target_rate then
		player:setRate(target_rate)
		self.rate = target_rate
	end
end

---@private
---@param time number
function PreviewModel:seekPlayers(time)
	self.manual_time = time
	self:getAudioPlayer():seek(time)
	self.bgaPreviewPlayer:seek(time)
end

---Selects another random chart when the selected one turned out to have nothing to play.
---@private
function PreviewModel:skipSilentChart()
	local loader = self.loader
	if self.end_action ~= "random_chart" or loader.media_state ~= "failed"
		or loader.media_generation == self.skipped_generation then
		return
	end
	-- Failed media can still have audio, e.g. when only the video preview is missing.
	if self.waiting_next or not (self.remote or self.loaded_audio_hash) then
		self.skipped_generation = loader.media_generation
		self.waiting_next = self.game.chartSelector:scrollRandom()
	end
end

---Stops the players, but not the preview: it plays the next chart that is selected.
function PreviewModel:clearMedia()
	self:stopRemoteAudio()
	self.audioPreviewPlayer:stop()
	self.bgaPreviewPlayer:stop()
	self.loaded_audio_path = nil
	self.loaded_hash = nil
	self.loaded_audio_hash = nil
	self.initial_seek_done = false
	self.waiting_next = false
end

---@param media rizu.preview.PreviewLoader.Media?
---@param path string
---@param preview_time number?
---@param mode rizu.preview.PreviewMode?
---@param chartview rizu.preview.PreviewChartview?
function PreviewModel:applyPreparedMedia(media, path, preview_time, mode, chartview)
	local audio_needs_reload = self.loaded_audio_path ~= path or path == ""
	if audio_needs_reload then
		self:clearMedia()
		if not self.active or path ~= self.audio_path or chartview ~= self.chartview then return end
		self.loaded_audio_path = path
	end
	-- A random chart with the same audio loops it.
	self.waiting_next = false
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
	self:getAudioPlayer():pause()
end

function PreviewModel:resume()
	self.paused = false
	self:getAudioPlayer():resume()
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
	self.initial_seek_done = true
	self.waiting_next = false
	self:seekPlayers(time)
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
	return self:getAudioPlayer():getRange()
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
	self:getAudioPlayer():setFFTSize(size)
end

---@return ffi.cdata*?
function PreviewModel:getFFT()
	return self:getAudioPlayer():getFFT()
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
	self:clearMedia()
	self.loader:stop()
	self.skinCache:stop()
	self.chartPreview:setChartview(nil)
	self.manual_time = 0
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
	if self.remote_audio then self.remote_audio:release() end
	self.bgaPreviewPlayer:release()
end

return PreviewModel
