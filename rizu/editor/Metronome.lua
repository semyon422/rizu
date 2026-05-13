local class = require("class")
local audio = require("audio")

---@class rizu.editor.Metronome
---@operator call: rizu.editor.Metronome
local Metronome = class()

local samplePath = "resources/metronome.ogg"

function Metronome:load()
	self.fileData = love.filesystem.newFileData(samplePath)
	self.soundData = audio.SoundData(self.fileData:getFFIPointer(), self.fileData:getSize())
	self.source = audio.newSource(self.soundData)

	self.nextTime = math.huge
	self.isNextBeat = false
end

function Metronome:unload()
	self.source:release()
	self.soundData:release()
end

function Metronome:updateNextTime()
	local editorModel = self.editorModel
	local point = editorModel.point
	local layer = editorModel.layer
	local currentTime = editorModel.timer:getTime()

	if point:tonumber() > currentTime then
		self.nextTime = point:tonumber()
		self.isNextBeat = (point.time % 1):tonumber() == 0
		return
	end

	local interval, t = editorModel.scroller:getNextSnapIntervalTime(point, 1)

	local nextPoint = layer.points:interpolateFraction(interval, t)

	self.nextTime = nextPoint:tonumber()
	self.isNextBeat = (nextPoint.time % 1):tonumber() == 0
end

function Metronome:update()
	local editorModel = self.editorModel

	local currentTime = editorModel.timer:getTime()
	if currentTime >= self.nextTime then
		local source = self.source
		source:stop()
		source:setVolume(self.volume.master * self.volume.metronome)
		source:setRate(2099 / 2645)
		if self.isNextBeat then
			source:setRate(1)
		end
		source:play()
	end

	self:updateNextTime()
end

return Metronome
