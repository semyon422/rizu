local class = require("class")
local audio = require("audio")
local ffi = require("ffi")
local LoveFilesystem = require("fs.LoveFilesystem")

---@class rizu.editor.Metronome
---@operator call: rizu.editor.Metronome
---@field fs fs.IFilesystem
---@field context rizu.editor.MetronomeContext
local Metronome = class()

---@class rizu.editor.MetronomeContext
---@field getPoint fun(): chartedit.Point
---@field getCurrentTime fun(): number
---@field getNextSnapIntervalTime fun(point: chartedit.Point, delta: number): chartedit.Vertex, chart.Fraction
---@field interpolateFraction fun(vertex: chartedit.Vertex, time: chart.Fraction): chartedit.Point

local samplePath = "resources/metronome.ogg"

---@param fs fs.IFilesystem?
function Metronome:new(fs)
	self.fs = fs or LoveFilesystem()
end

---@param context rizu.editor.MetronomeContext
function Metronome:setContext(context)
	self.context = context
end

function Metronome:load()
	local sampleData = assert(self.fs:read(samplePath))
	self.sampleBuffer = ffi.new("uint8_t[?]", #sampleData)
	ffi.copy(self.sampleBuffer, sampleData, #sampleData)
	self.soundData = assert(audio.SoundData(self.sampleBuffer, #sampleData))
	self.source = audio.newSource(self.soundData)

	self.nextTime = math.huge
	self.isNextBeat = false
end

function Metronome:unload()
	self.source:release()
	self.soundData:release()
end

function Metronome:updateNextTime()
	local context = self.context
	local point = context.getPoint()
	local currentTime = context.getCurrentTime()

	if point:tonumber() > currentTime then
		self.nextTime = point:tonumber()
		self.isNextBeat = (point.time % 1):tonumber() == 0
		return
	end

	local vertex, t = context.getNextSnapIntervalTime(point, 1)

	local nextPoint = context.interpolateFraction(vertex, t)

	self.nextTime = nextPoint:tonumber()
	self.isNextBeat = (nextPoint.time % 1):tonumber() == 0
end

function Metronome:update()
	local currentTime = self.context.getCurrentTime()
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
