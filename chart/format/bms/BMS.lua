local class = require("class")
local string_util = require("string_util")
local Fraction = require("chart.core.Fraction")
local enums = require("chart.format.bms.enums")

---@class chart.bms.BMS
---@operator call: chart.bms.BMS
local BMS = class()

function BMS:new()
	self.header = {}
	self.wav = {}
	self.bpm = {}
	self.bmp = {}
	self.stop = {}
	self.signature = {}

	self.inputExisting = {}
	self.channelExisting = {}

	self.timePointLimit = 25000
	self.timePointCount = 0

	self.primaryTempo = 130
	self.measureCount = 0
	self.hasTempo = false

	self.timePoints = {}
	self.timeList = {}
end

---@param noteChartString string
function BMS:import(noteChartString)
	for _, line in string_util.isplit(noteChartString, "\n") do
		self:processLine(string_util.trim(line))
	end

	if not self.hasTempo then
		self.baseTempo = self.primaryTempo
	end

	for _, timeData in pairs(self.timePoints) do
		table.insert(self.timeList, timeData)
	end

	table.sort(self.timeList, function(a, b)
		return a.measureTime < b.measureTime
	end)

	self:detectKeymode()
end

---@param line string
function BMS:processLine(line)
	if line:upper():find("^#WAV%S%S%s+.+$") then
		local index, fileName = line:match("^#...(..)%s+(.+)$")
		self.wav[index:upper()] = fileName
	elseif line:upper():find("^#BPM%S%S%s+.+$") then
		local index, tempo = line:match("^#...(..)%s+(.+)$")
		self.bpm[index:upper()] = tonumber(tempo)
	elseif line:upper():find("^#BMP%S%S%s+.+$") then
		local index, path = line:match("^#...(..)%s+(.+)$")
		self.bmp[index:upper()] = path
	elseif line:upper():find("^#STOP%S%S%s+.+$") then
		local index, duration = line:match("^#....(..)%s+(.+)$")
		self.stop[index:upper()] = tonumber(duration)
	elseif line:find("^#%d%d%d%S%S:.+$") then
		self:processLineData(line)
	elseif line:find("^#%S+%s+.+$") then
		self:processHeaderLine(line)
	end
end

---@param line string
function BMS:processHeaderLine(line)
	local key, value = line:match("^#(%S+)%s+(.+)$")
	key = key:upper()
	self.header[key] = value

	if key == "BPM" then
		self.baseTempo = tonumber(value)
		self.hasTempo = true
	elseif key == "LNOBJ" then
		self.lnobj = value
	end
end

function BMS:detectKeymode()
	local ce = self.channelExisting

	if not self.pms then
		if ce["28"] or ce["29"] then
			self.mode = 14
			return
		elseif ce["21"] or ce["22"] or ce["23"] or ce["24"] or ce["25"] then
			if ce["18"] or ce["19"] then
				self.mode = 14
				return
			end
			self.mode = 10
			return
		elseif ce["18"] or ce["19"] then
			if ce["26"] then
				self.mode = 27
				return
			end
			self.mode = 7
			return
		elseif ce["11"] or ce["12"] or ce["13"] or ce["14"] or ce["15"] then
			if ce["26"] then
				self.mode = 25
				return
			end
			self.mode = 5
			return
		elseif ce["16"] then
			if ce["26"] then
				self.mode = 14
				return
			end
			self.mode = 7
			return
		end
	elseif ce["24"] or ce["25"] then
		self.mode = 59
		return
	elseif ce["23"] or ce["13"] or ce["14"] or ce["15"] or ce["22"] then
		if ce["11"] or ce["12"] then
			self.mode = 59
			return
		end
		self.mode = 55
		return
	elseif ce["11"] or ce["12"] then
		self.mode = 59
		return
	end
end

---@param channel string
function BMS:updateMode(channel)
	local channelExisting = self.channelExisting

    local channelInfo = enums.ChannelEnum[channel]
    if channelInfo and channelInfo.name == "Note" then
        channelExisting[channelInfo.channelBase] = true
	end
end

---@param line string
function BMS:processLineData(line)
	if self.timePointCount >= self.timePointLimit then
		return
	end

	local measure, channel, message = line:match("^#(...)(..):(.+)$")
	measure = tonumber(measure)

	if measure > self.measureCount then
		self.measureCount = measure
	end

	if not enums.ChannelEnum[channel] then
		return
	end

	self:updateMode(channel)

	if enums.ChannelEnum[channel].name == "Signature" then
		self.signature[measure] = tonumber((message:gsub(",", ".")))
		return
	end

	if
		(enums.ChannelEnum[channel].name == "Tempo" or
		enums.ChannelEnum[channel].name == "ExtendedTempo") and
		measure == 0 and
		message:sub(1, 2) ~= "00"
	then
		self.tempoAtStart = true
		self.hasTempo = true
	end

	local compound = enums.ChannelEnum[channel].name ~= "BGM"
	local messageLength = math.floor(#message / 2)
	for i = 1, messageLength do
		local value = message:sub(2 * i - 1, 2 * i)
		if value ~= "00" then
			local measureTime = Fraction(i - 1, messageLength) + measure
			local measureTimeString = tostring(measureTime)

			local timeData
			if self.timePoints[measureTimeString] then
				timeData = self.timePoints[measureTimeString]
			else
				timeData = {}
				timeData.measureTime = measureTime
				self.timePoints[measureTimeString] = timeData

				self.timePointCount = self.timePointCount + 1
			end

			local settedNoteChannel
			for currentChannel, values in pairs(timeData) do
				if
					enums.ChannelEnum[currentChannel] and
					enums.ChannelEnum[currentChannel].name == "Note" and
					enums.ChannelEnum[channel].inputType == enums.ChannelEnum[currentChannel].inputType and
					enums.ChannelEnum[channel].inputIndex == enums.ChannelEnum[currentChannel].inputIndex
				then
					settedNoteChannel = currentChannel -- may differs from channel due to different channels for long notes
					break
				end
			end

			timeData[channel] = timeData[channel] or {}
			if compound then
				if enums.ChannelEnum[channel].name == "Note" then
					if enums.ChannelEnum[channel].long then
						if settedNoteChannel then
							timeData[settedNoteChannel][1] = nil
							timeData[settedNoteChannel] = nil
						end
						timeData[channel] = timeData[channel] or {}
						timeData[channel][1] = value
					end
					if not enums.ChannelEnum[channel].long and not settedNoteChannel then
						timeData[channel][1] = value
					end
				else
					timeData[channel][1] = value
					if enums.ChannelEnum[channel].name == "Tempo" or
						enums.ChannelEnum[channel].name == "ExtendedTempo"
					then
						self.hasTempo = true
					end
				end
			else
				table.insert(timeData[channel], value)
			end
		end
	end
end

return BMS
