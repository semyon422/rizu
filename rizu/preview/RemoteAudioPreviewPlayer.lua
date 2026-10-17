local class = require("class")
local Settings = require("rizu.config.Settings")

---@class rizu.preview.RemoteAudioPreviewPlayer
---@operator call: rizu.preview.RemoteAudioPreviewPlayer
---@field settings rizu.config.Config
---@field provider rizu.audio.IProvider
---@field decoder rizu.audio.IDecoder?
---@field source rizu.audio.ISource?
local RemoteAudioPreviewPlayer = class()

---@param settings rizu.config.Config
---@param provider rizu.audio.IProvider
function RemoteAudioPreviewPlayer:new(settings, provider)
	self.settings = settings
	self.provider = provider
	self.volume = -1
end

function RemoteAudioPreviewPlayer:updateVolume()
	local keys = Settings.keys.audio
	local volume = self.settings:getNumber(keys.volume_master) * self.settings:getNumber(keys.volume_music)
	if self.source and volume ~= self.volume then
		self.source:setVolume(volume)
	end
	self.volume = volume
end

---@param data string
---@return true?
---@return string?
function RemoteAudioPreviewPlayer:load(data)
	self:stop()
	local ok, decoder = pcall(self.provider.createDecoder, self.provider, data)
	if not ok then
		return nil, tostring(decoder)
	end
	self.decoder = decoder

	local source_ok, source = pcall(self.provider.createChartSource, self.provider, decoder, false)
	if not source_ok then
		self.decoder = nil
		decoder:release()
		return nil, tostring(source)
	end
	self.source = source
	self.volume = -1
	self:updateVolume()
	self.source:update()
	self.source:play()
	return true
end

function RemoteAudioPreviewPlayer:update()
	if not self.source then
		return
	end
	self:updateVolume()
	self.source:update()
end

---The player of the preview model works with this interface.

---@return number start
---@return number finish
function RemoteAudioPreviewPlayer:getRange()
	return 0, self.decoder and self.decoder:getDuration() or 0
end

---@return number
function RemoteAudioPreviewPlayer:getPosition()
	return self.source and self.source:getPosition() or 0
end

---@param time number
function RemoteAudioPreviewPlayer:seek(time)
	if self.source then
		self.source:setPosition(time)
	end
end

function RemoteAudioPreviewPlayer:pause()
	if self.source then
		self.source:pause()
	end
end

function RemoteAudioPreviewPlayer:resume()
	if self.source then
		self.source:play()
	end
end

---@param rate number
function RemoteAudioPreviewPlayer:setRate(rate)
	if self.source then
		self.source:setRate(rate)
	end
end

---@param volume number
function RemoteAudioPreviewPlayer:setVolume(volume)
	if self.source then
		self.source:setVolume(volume)
	end
	self.volume = volume
end

---@param size integer
function RemoteAudioPreviewPlayer:setFFTSize(size)
	if self.source then
		self.source:setFFTSize(size)
	end
end

---@return ffi.cdata*?
function RemoteAudioPreviewPlayer:getFFT()
	return self.source and self.source:getFFT()
end

function RemoteAudioPreviewPlayer:release()
	self:stop()
end

function RemoteAudioPreviewPlayer:stop()
	local source = self.source
	local decoder = self.decoder
	self.source = nil
	self.decoder = nil
	if source then
		source:pause()
		source:release()
	end
	if decoder then
		decoder:release()
	end
end

return RemoteAudioPreviewPlayer
