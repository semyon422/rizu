local _audio = require("audio")
local AudioContainer = require("audio.Container")
local class = require("class")

---@class sphere.RhythmAudioEngine
---@operator call: sphere.RhythmAudioEngine
local AudioEngine = class()

AudioEngine.timeRate = 1

---@param timeEngine sphere.TimeEngine
---@param resourceModel sphere.ResourceModel
function AudioEngine:new(timeEngine, resourceModel)
	self.backgroundContainer = AudioContainer()
	self.foregroundContainer = AudioContainer()
	self.timeEngine = timeEngine
	self.resourceModel = resourceModel
end

function AudioEngine:updateVolume()
	self.backgroundContainer:setVolume(self.volume.master * self.volume.music)
	local keysounds_volume = self.volume.keysounds * (self.volume.keysounds_format[self.format] or 1)
	self.foregroundContainer:setVolume(self.volume.master * keysounds_volume)
end

function AudioEngine:load()
	self.loaded = true
end

function AudioEngine:update()
	self:updateTimeRate()
	self.backgroundContainer:update()
	self.foregroundContainer:update()
end

---@param event any
function AudioEngine:receive(event)
	if event.name == "LogicalNoteSound" then
		self:playNote(event[1], event[2])
	end
end

function AudioEngine:unload()
	self.backgroundContainer:release()
	self.foregroundContainer:release()
	self.loaded = false
end

---@param note chart.Note
---@param isBackground boolean?
function AudioEngine:playNote(note, isBackground)
	if not self.loaded or not note or not note.data.sounds then
		return
	end

	local is_stream = note.column == "audio"
	self:playAudio(note.data.sounds, isBackground, is_stream, note:getTime())
end

---@param sounds table
---@param isBackground boolean?
---@param stream boolean?
---@param offset number?
function AudioEngine:playAudio(sounds, isBackground, stream, offset)
	local currentTime = self.timeEngine.currentTime
	for i = 1, #sounds do
		local mode = stream and self.mode.primary or self.mode.secondary

		local soundData = self.resourceModel:getResource(sounds[i][1])

		if soundData then
			local audio = _audio.newSource(soundData, mode)
			audio.offset = offset or currentTime
			audio:setBaseVolume(sounds[i][2])
			local shouldPlay = true
			if self.forcePosition then
				local p = currentTime - audio.offset
				if p >= audio:getDuration() then
					shouldPlay = false
				else
					audio:setPosition(p)
				end
			end
			if shouldPlay then
				if isBackground then
					self.backgroundContainer:add(audio)
				else
					self.foregroundContainer:add(audio)
				end
			else
				audio:release()
			end
		end
	end
end

function AudioEngine:play()
	self.backgroundContainer:play()
	self.foregroundContainer:play()
end

function AudioEngine:pause()
	self.backgroundContainer:pause()
	self.foregroundContainer:pause()
end

function AudioEngine:updateTimeRate()
	local timeRate = self.timeEngine.timeRate
	if self.timeRate == timeRate then
		return
	end
	self.backgroundContainer:setRate(timeRate)
	self.foregroundContainer:setRate(timeRate)
	self.timeRate = timeRate
end

---@return number?
---@return number?
---@return number?
function AudioEngine:getPosition()
	return self.backgroundContainer:getPosition()
end

---@param position number
function AudioEngine:setPosition(position)
	self.backgroundContainer:setPosition(position)
	self.foregroundContainer:setPosition(position)
end

return AudioEngine
