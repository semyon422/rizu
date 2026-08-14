local class = require("class")
local Observable = require("Observable")
local ThreadRemote = require("threadremote.ThreadRemote")
local BufferedDecoder = require("rizu.engine.audio.BufferedDecoder")
local Source = require("rizu.engine.audio.bass.Source")
local thread = require("thread")
local Settings = require("rizu.config.Settings")

---@class rizu.preview.AudioPreviewPlayer
---@operator call: rizu.preview.AudioPreviewPlayer
---@field pending_seek number?
---@field private thread threadremote.ThreadRemote?
local AudioPreviewPlayer = class()

AudioPreviewPlayer.volume = 1
AudioPreviewPlayer.rate = 1
AudioPreviewPlayer.is_playing = false
AudioPreviewPlayer.load_generation = 0

---@param settings rizu.config.Config
function AudioPreviewPlayer:new(settings)
	self.settings = settings
	self.onChanged = Observable()
end

---@param preview_path string
---@param chart_dir string
function AudioPreviewPlayer:load(preview_path, chart_dir)
	self:stop()
	self.pending_seek = nil

	self.load_generation = self.load_generation + 1
	local generation = self.load_generation

	if not self.thread then
		-- Persistent ID for the thread remote
		local thread_id = "preview_player_" .. tostring(self)
		self.thread = ThreadRemote(thread_id, {})
	else
		self.thread:reset()
	end

	local preview_and_decoder = self.thread:start(function(remote, dir, preview_path)
		local PreviewDecoder = require("rizu.engine.audio.PreviewDecoder")
		local AudioPreview = require("rizu.preview.AudioPreview")
		local Decoder = require("rizu.engine.audio.bass.Decoder")
		local LoveFilesystem = require("fs.LoveFilesystem")
		local fs = LoveFilesystem()

		local preview_data = fs:read(preview_path)
		if not preview_data then
			error("AudioPreviewPlayer: could not read preview file " .. tostring(preview_path))
		end

		local preview = AudioPreview()
		preview:decode(preview_data)

		local decoder = PreviewDecoder(fs, dir, preview, function(data)
			return Decoder(data)
		end)

		return {
			preview = preview,
			decoder = decoder,
		}
	end, chart_dir, preview_path)

	thread.coro(function()
		local ok, min_time, max_time = pcall(function()
			return preview_and_decoder.preview:getRange()
		end)
		if not ok then
			return
		end
		if generation ~= self.load_generation then
			return
		end
		self.min_time = min_time
		self.max_time = max_time

		-- BufferedDecoder(self.thread.remote) calls metadata methods
		-- which will yield and wait for thread remote update.
		---@type boolean, rizu.audio.BufferedDecoder|string
		local ok, buffered = pcall(BufferedDecoder --[[@as function]], preview_and_decoder.decoder)
		if generation ~= self.load_generation then
			if ok and buffered then
				---@cast buffered -string
				buffered:release()
			end
			return
		end
		---@cast buffered -string

		if not ok then
			-- Probably ThreadRemote stopped/reset
			return
		end

		self.buffered_decoder = buffered

		local use_tempo = self.settings:getChoice(Settings.keys.audio.mode_primary) == "bass_fx_tempo"
		self.audio_source = Source(buffered, use_tempo)
		self.audio_source:setVolume(self.volume)
		self.audio_source:setRate(self.rate)
		if self.fft_size then
			self.audio_source:setFFTSize(self.fft_size)
		end

		if self.pending_seek then
			self.audio_source:setPosition(self.pending_seek)
			self.pending_seek = nil
		end

		if self.is_playing then
			self.audio_source:play()
		end

		---@class rizu.AudioPreviewPlayer.RangeEvent
		local e = {
			type = "range",
			min_time = min_time,
			max_time = max_time,
		}
		self.onChanged:send(e)
	end)()
end

function AudioPreviewPlayer:update()
	if self.thread then
		self.thread:update()
	end

	if not self.audio_source then
		return
	end

	if self.is_playing then
		self.audio_source:update()
	end
end

---@param time number
function AudioPreviewPlayer:seek(time)
	if not self.audio_source then
		self.pending_seek = time
		return
	end
	self.audio_source:setPosition(time)
end

function AudioPreviewPlayer:pause()
	self.is_playing = false
	if self.audio_source then
		self.audio_source:pause()
	end
end

function AudioPreviewPlayer:resume()
	self.is_playing = true
	if self.audio_source then
		self.audio_source:play()
	end
end

function AudioPreviewPlayer:stop()
	self.is_playing = false
	self.min_time = nil
	self.max_time = nil

	if self.audio_source then
		self.audio_source:release()
		self.audio_source = nil
	end
	if self.buffered_decoder then
		self.buffered_decoder:release()
		self.buffered_decoder = nil
	end

	---@class rizu.AudioPreviewPlayer.StopEvent
	local e = {type = "stop"}
	self.onChanged:send(e)
end

function AudioPreviewPlayer:release()
	self:stop()
	if self.thread then
		self.thread:stop()
		self.thread = nil
	end
end

---@param rate number
function AudioPreviewPlayer:setRate(rate)
	self.rate = rate
	if self.audio_source then
		self.audio_source:setRate(rate)
	end
end

---@param volume number
function AudioPreviewPlayer:setVolume(volume)
	self.volume = volume
	if self.audio_source then
		self.audio_source:setVolume(volume)
	end
end

---@return number, number
function AudioPreviewPlayer:getRange()
	return self.min_time or 0, self.max_time or 0
end

---@return number
function AudioPreviewPlayer:getPosition()
	if self.audio_source then
		return self.audio_source:getPosition()
	end
	return self.pending_seek or 0
end

---@param size integer
function AudioPreviewPlayer:setFFTSize(size)
	self.fft_size = size
	if self.audio_source then
		self.audio_source:setFFTSize(size)
	end
end

---@return ffi.cdata*?
function AudioPreviewPlayer:getFFT()
	if self.audio_source then
		return self.audio_source:getFFT()
	end
	return nil
end

return AudioPreviewPlayer
