local class = require("class")
local math_util = require("math_util")

---@class rizu.editor.EditorWaveformState
---@field lines table[]
---@field pointDrawDelta number
---@field channelCount integer

---@class rizu.editor.EditorWaveformContext
---@field getWave fun(self: rizu.editor.EditorWaveformContext): table?
---@field getSessionTime fun(self: rizu.editor.EditorWaveformContext): number
---@field getAudioStartTime fun(self: rizu.editor.EditorWaveformContext): number

---@class rizu.editor.EditorWaveformService
---@operator call: rizu.editor.EditorWaveformService
---@field lines table[]
---@field points table[]
---@field key string?
---@field wave table?
---@field waveSignature string?
---@field prevSamplesPerPoint number
---@field renderedPointOffset number|false?
---@field pointDrawDelta number
local EditorWaveformService = class()

function EditorWaveformService:new()
	self.lines = {}
	self.points = {}
	self.prevSamplesPerPoint = 0
	self.pointDrawDelta = 0
end

---@param wave table
---@param points integer
---@param pointOffset number
---@param samplesPerPoint number
---@param channel integer
---@return table
function EditorWaveformService:getPointList(wave, points, pointOffset, samplesPerPoint, channel)
	local sampleCount = wave.samples_count
	local j = channel + 1
	local list = {}

	for k = 0, points - 1 do
		local sampleStart = math.floor((pointOffset + k) * samplesPerPoint)
		local sampleEnd = math.floor((pointOffset + k + 1) * samplesPerPoint)

		local max, min
		for i = sampleStart, sampleEnd do
			if i >= 0 and i < sampleCount then
				local sample = wave:getSampleFloat(i, j)
				if sample >= 0 then
					max = math.max(max or 0, sample)
				else
					min = math.min(min or 0, sample)
				end
			end
		end

		local x1, x2 = min or 0, max or 0
		if min and max then
			list[k] = {x1, x2}
		elseif min then
			list[k] = {x1}
		elseif max then
			list[k] = {x2}
		end
	end

	return list
end

---@param wave table
---@param pointStart number
---@param newPointStart number
---@param points integer
---@param samplesPerPoint number
---@param channelCount integer
function EditorWaveformService:adjustPoints(wave, pointStart, newPointStart, points, samplesPerPoint, channelCount)
	for j = 0, channelCount - 1 do
		local count = math.abs(pointStart - newPointStart)
		local newPoints = {}
		if newPointStart > pointStart then
			for i = count, points - 1 do
				newPoints[i - count] = self.points[j][i]
			end

			local addedPoints = self:getPointList(wave, count, pointStart + points + 1, samplesPerPoint, j)
			for i = 0, count - 1 do
				newPoints[points - count + i] = addedPoints[i]
			end
		else
			for i = 0, points - 1 - count do
				newPoints[i + count] = self.points[j][i]
			end

			local addedPoints = self:getPointList(wave, count, newPointStart, samplesPerPoint, j)
			for i = 0, count - 1 do
				newPoints[i] = addedPoints[i]
			end
		end
		self.points[j] = newPoints
	end
end

---@param wave table
---@param width number
---@param height number
---@param pointOffset number
---@param samplesPerPoint number
---@param channelCount integer
function EditorWaveformService:updateLines(wave, width, height, pointOffset, samplesPerPoint, channelCount)
	local points = math.floor(height)
	local key = pointOffset .. "/" .. samplesPerPoint .. "/" .. channelCount .. "/" .. points
	if self.key == key then
		return
	end
	self.key = key

	for j = 0, channelCount - 1 do
		self.points[j] = self:getPointList(wave, points * 2, pointOffset - points, samplesPerPoint, j)
	end

	self.renderedPointOffset = pointOffset
	self.lines = {}

	for j = 0, channelCount - 1 do
		self.lines[j] = self.lines[j] or {}
		local line = self.lines[j]

		local c = 0
		for i = 0, points * 2 - 1 do
			local point = self.points[j][i]
			if point then
				for l = 1, #point do
					line[c + 1] = point[l] * width / 2
					line[c + 2] = -i + points
					c = c + 2
				end
			end
		end
		for k = c + 1, 8 * points do
			line[k] = nil
		end
	end
end

---@param context rizu.editor.EditorWaveformContext
---@param noteSkin table
---@param editor table
---@param height number?
---@return rizu.editor.EditorWaveformState?
function EditorWaveformService:update(context, noteSkin, editor, height)
	local wave = context:getWave()
	if not wave then
		return nil
	end
	local waveSignature = ("%s/%s/%s"):format(wave.samples_count, wave.sample_rate, wave.channels_count)
	if self.wave ~= wave or self.waveSignature ~= waveSignature then
		self.wave = wave
		self.waveSignature = waveSignature
		self.key = nil
		self.renderedPointOffset = nil
		self.prevSamplesPerPoint = 0
		self.lines = {}
		self.points = {}
	end

	local sampleRate = wave.sample_rate
	local samplesPerPoint = sampleRate / math.abs(noteSkin.unit * editor.speed)
	local sampleOffset = math.floor((context:getSessionTime() - context:getAudioStartTime() - editor.waveformOffset) * sampleRate)
	local pointOffset = math.floor(sampleOffset / samplesPerPoint)
	self.pointDrawDelta = sampleOffset / samplesPerPoint - pointOffset

	self:updateLines(wave, noteSkin.fullWidth, height or noteSkin.unit, pointOffset, samplesPerPoint, wave.channels_count)

	return {
		lines = self.lines,
		pointDrawDelta = self.pointDrawDelta,
		channelCount = wave.channels_count,
	}
end

return EditorWaveformService
