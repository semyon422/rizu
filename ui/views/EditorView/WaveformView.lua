local math_util = require("math_util")
local gfx_util = require("gfx_util")

---@param self table
---@param points number
---@param pointOffset number
---@param samplesPerPoint number
---@param channel number
---@return table
local function getPointList(self, points, pointOffset, samplesPerPoint, channel)
	local editorModel = self.game.editorModel
	local wave = editorModel.wave

	local sampleCount = wave.samples_count
	local channelCount = wave.channels_count

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

local waveformLines = {}
local waveformPoints = {}
local waveformKey
local prevSamplesPerPoint = 0
local renderedPointOffset
local pointDrawDelta

---@param self table
---@param pointStart number
---@param newPointStart number
---@param points number
---@param samplesPerPoint number
---@param channelCount number
local function adjustPoints(self, pointStart, newPointStart, points, samplesPerPoint, channelCount)
	for j = 0, channelCount - 1 do
		local count = math.abs(pointStart - newPointStart)
		local _newPoints = {}
		if newPointStart > pointStart then
			for i = count, points - 1 do
				_newPoints[i - count] = waveformPoints[j][i]
			end

			local newPoints = getPointList(self, count, pointStart + points + 1, samplesPerPoint, j)
			for i = 0, count - 1 do
				_newPoints[points - count + i] = newPoints[i]
			end
		else
			for i = 0, points - 1 - count do
				_newPoints[i + count] = waveformPoints[j][i]
			end

			local newPoints = getPointList(self, count, newPointStart, samplesPerPoint, j)
			for i = 0, count - 1 do
				_newPoints[i] = newPoints[i]
			end
		end
		waveformPoints[j] = _newPoints
	end
end

---@param self table
---@param w number
---@param h number
local function loadWaveform(self, w, h)
	local editorModel = self.game.editorModel
	local wave = editorModel.wave
	local noteSkin = self.game.noteSkinModel.noteSkin
	local editor = self.game.configModel.configs.settings.editor

	local sampleRate = wave.sample_rate
	local channelCount = wave.channels_count

	local points = math.floor(h)

	local samplesPerPoint = sampleRate / math.abs(noteSkin.unit * editor.speed)

	local offset = editorModel.audio_engine:getStartTime() + editor.waveformOffset
	local sampleOffset = math.floor((editorModel.session.point.absoluteTime - offset) * sampleRate)
	local pointOffset = math.floor(sampleOffset / samplesPerPoint)
	pointDrawDelta = sampleOffset / samplesPerPoint - pointOffset

	local _waveformKey = pointOffset .. "/" .. samplesPerPoint
	if waveformKey == _waveformKey then
		return
	end
	waveformKey = _waveformKey

	if samplesPerPoint ~= prevSamplesPerPoint then
		renderedPointOffset = nil
		prevSamplesPerPoint = samplesPerPoint
	end

	if renderedPointOffset then
		local pointStart, pointEnd = renderedPointOffset - points, renderedPointOffset + points - 1
		local newPointStart, newPointEnd = pointOffset - points, pointOffset + points - 1
		if math_util.intersect1(pointStart, pointEnd, newPointStart, newPointEnd) then
			adjustPoints(self, pointStart, newPointStart, points * 2, samplesPerPoint, channelCount)
		else
			renderedPointOffset = false
		end
	end

	if not renderedPointOffset then
		for j = 0, channelCount - 1 do
			waveformPoints[j] = getPointList(self, points * 2, pointOffset - points, samplesPerPoint, j)
		end
	end

	renderedPointOffset = pointOffset

	waveformLines = {}

	for j = 0, channelCount - 1 do
		waveformLines[j] = waveformLines[j] or {}
		local waveformLine = waveformLines[j]

		local c = 0
		for i = 0, points * 2 - 1 do
			local p = waveformPoints[j][i]
			if p then
				for l = 1, #p do
					waveformLine[c + 1] = p[l] * w / 2
					waveformLine[c + 2] = -i + points
					c = c + 2
				end
			end
		end
		for k = c + 1, 8 * points do
			waveformLine[k] = nil
		end
	end
end

return function(self)
	local editorModel = self.game.editorModel
	local wave = editorModel.wave
	if not wave then
		return
	end

	local waveform = self.game.configModel.configs.settings.editor.waveform
	if waveform.opacity == 0 or waveform.scale == 0 then
		return
	end

	local channelCount = wave.channels_count

	local noteSkin = self.game.noteSkinModel.noteSkin
	loadWaveform(self, noteSkin.fullWidth, noteSkin.unit)

	love.graphics.push("all")
	love.graphics.setLineJoin("none")
	love.graphics.setLineStyle("smooth")
	love.graphics.setLineWidth(1)
	love.graphics.setColor(1, 1, 1, waveform.opacity)

	love.graphics.replaceTransform(gfx_util.transform(self.transform))
	love.graphics.translate(noteSkin.baseOffset, noteSkin.hitposition)
	love.graphics.translate(0, pointDrawDelta)

	for j = 0, channelCount - 1 do
		local waveformLine = waveformLines[j]
		if #waveformLine >= 4 then
			love.graphics.push()
			love.graphics.scale(waveform.scale, 1)
			love.graphics.line(waveformLine)
			love.graphics.pop()
		end
		love.graphics.translate(noteSkin.fullWidth, 0)
	end

	love.graphics.pop()
end
