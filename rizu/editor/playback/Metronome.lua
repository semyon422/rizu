local class = require("class")
local Sample = require("rizu.engine.audio.bass.Sample")
local LoveFilesystem = require("fs.LoveFilesystem")

---@class rizu.editor.Metronome
---@operator call: rizu.editor.Metronome
---@field fs fs.IFilesystem
---@field context rizu.editor.MetronomeContext
local Metronome = class()

---@class rizu.editor.MetronomeContext
---@field getPoint fun(self: rizu.editor.MetronomeContext): chartedit.Point
---@field getCurrentTime fun(self: rizu.editor.MetronomeContext): number
---@field getNextSnapIntervalTime fun(self: rizu.editor.MetronomeContext, point: chartedit.Point, delta: number): chartedit.Vertex, chart.Fraction
---@field interpolateFraction fun(self: rizu.editor.MetronomeContext, vertex: chartedit.Vertex, time: chart.Fraction): chartedit.Point

local samplePath = "resources/metronome.ogg"

---@param value number
---@return number
local function clampVolume(value)
	return math.min(math.max(value, 0), 1)
end

---@param fs fs.IFilesystem?
---@param sample_factory (fun(data: string): rizu.audio.bass.Sample)?
function Metronome:new(fs, sample_factory)
	self.fs = fs or LoveFilesystem()
	self.sample_factory = sample_factory or Sample
end

---@param context rizu.editor.MetronomeContext
function Metronome:setContext(context)
	self.context = context
end

function Metronome:load()
	local sample_data = assert(self.fs:read(samplePath))
	self.source = self.sample_factory(sample_data)

	self.nextTime = math.huge
	self.isNextBeat = false
end

function Metronome:unload()
	self.source:release()
end

function Metronome:updateNextTime()
	local context = self.context
	local point = context:getPoint()
	local currentTime = context:getCurrentTime()

	if point:tonumber() > currentTime then
		self.nextTime = point:tonumber()
		self.isNextBeat = (point.time % 1):tonumber() == 0
		return
	end

	local vertex, t = context:getNextSnapIntervalTime(point, 1)

	local nextPoint = context:interpolateFraction(vertex, t)

	self.nextTime = nextPoint:tonumber()
	self.isNextBeat = (nextPoint.time % 1):tonumber() == 0
end

function Metronome:update()
	local currentTime = self.context:getCurrentTime()
	if currentTime >= self.nextTime then
		local source = self.source
		source:stop()
		source:setVolume(clampVolume(self.volume.master) * clampVolume(self.volume.metronome))
		source:setRate(2099 / 2645)
		if self.isNextBeat then
			source:setRate(1)
		end
		source:play()
	end

	self:updateNextTime()
end

return Metronome
