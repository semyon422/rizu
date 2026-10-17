local class = require("class")
local string_util = require("string_util")
local Fraction = require("chart.core.Fraction")
local enums = require("chart.format.bms.enums")

local exactMeterBeatsDenominatorLimit = 10000
local fallbackMeterDenominatorLimit = 192

---@alias chart.bms.ResourceMap {[string]: string}
---@alias chart.bms.NumberResourceMap {[string]: number?}
---@alias chart.bms.ChannelValues string[]
---@alias chart.bms.BeatSignature chart.Fraction

---@class chart.bms.TimeData
---@field measureTime chart.Fraction
---@field [string] chart.bms.ChannelValues?

---@class chart.bms.BMS
---@operator call: chart.bms.BMS
---@field header {[string]: string}
---@field wav {[string]: string}
---@field bpm {[string]: number?}
---@field bmp {[string]: string}
---@field stop {[string]: number?}
---@field signature {[integer]: chart.bms.BeatSignature?}
---@field inputExisting table
---@field channelExisting {[string]: boolean}
---@field timePointLimit integer
---@field timePointCount integer
---@field primaryTempo number
---@field measureCount integer
---@field hasTempo boolean
---@field tempoAtStart boolean?
---@field baseTempo number?
---@field lnobj string?
---@field pms boolean?
---@field mode integer?
---@field timePoints {[string]: chart.bms.TimeData}
---@field timeList chart.bms.TimeData[]
local BMS = class()

function BMS:new()
	---@type chart.bms.ResourceMap
	self.header = {}
	---@type chart.bms.ResourceMap
	self.wav = {}
	---@type chart.bms.NumberResourceMap
	self.bpm = {}
	---@type chart.bms.ResourceMap
	self.bmp = {}
	---@type chart.bms.NumberResourceMap
	self.stop = {}
	---@type {[integer]: chart.bms.BeatSignature?}
	self.signature = {}

	self.inputExisting = {}
	---@type {[string]: boolean}
	self.channelExisting = {}

	self.timePointLimit = 25000
	self.timePointCount = 0

	self.primaryTempo = 130
	self.measureCount = 0
	self.hasTempo = false

	---@type {[string]: chart.bms.TimeData}
	self.timePoints = {}
	---@type chart.bms.TimeData[]
	self.timeList = {}
end

---@param value string
---@return chart.Fraction?
local function parseDecimalFraction(value)
	local sign, integer, decimal = value:gsub(",", "."):match("^([+-]?)(%d*)%.?(%d*)$")
	if not sign or integer == "" and decimal == "" then
		return nil
	end

	local denominator = 10 ^ #decimal
	local numerator = tonumber(integer == "" and "0" or integer) * denominator + tonumber(decimal == "" and "0" or decimal)
	if sign == "-" then
		numerator = -numerator
	end

	return Fraction(numerator, denominator)
end

---@param meter chart.Fraction
---@return chart.bms.BeatSignature
local function meterToBeatSignature(meter)
	return meter * 4
end

---@param value string
---@return chart.bms.BeatSignature?
local function parseMeterSignature(value)
	local exactMeter = parseDecimalFraction(value)
	if not exactMeter then
		return nil
	end
	if exactMeter <= Fraction(0) then
		return nil
	end

	local exactBeatSignature = meterToBeatSignature(exactMeter)
	if exactBeatSignature[2] <= exactMeterBeatsDenominatorLimit then
		return exactBeatSignature
	end

	local number = tonumber((value:gsub(",", ".")))
	if number <= 0 then
		return nil
	end

	local fallbackMeter = Fraction(number, fallbackMeterDenominatorLimit, "round")
	if fallbackMeter == Fraction(0) and number ~= 0 then
		fallbackMeter = Fraction(1, fallbackMeterDenominatorLimit)
	end
	return meterToBeatSignature(fallbackMeter)
end

---@param noteChartString string
function BMS:import(noteChartString)
	for _, line in string_util.isplit(noteChartString, "\n") do
		self:processLine(string_util.trim(line))
	end

	self:finalizeImport()
end

function BMS:finalizeImport()
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
	local upperLine = line:upper()
	if upperLine:find("^#WAV%S%S%s+.+$") then
		self:processResourceLine(line, self.wav, "^#...(..)%s+(.+)$")
	elseif upperLine:find("^#BPM%S%S%s+.+$") then
		self:processNumberResourceLine(line, self.bpm, "^#...(..)%s+(.+)$")
	elseif upperLine:find("^#BMP%S%S%s+.+$") then
		self:processResourceLine(line, self.bmp, "^#...(..)%s+(.+)$")
	elseif upperLine:find("^#STOP%S%S%s+.+$") then
		self:processNumberResourceLine(line, self.stop, "^#....(..)%s+(.+)$")
	elseif line:find("^#%d%d%d%S%S:.+$") then
		self:processLineData(line)
	elseif line:find("^#%S+%s+.+$") then
		self:processHeaderLine(line)
	end
end

---@param line string
---@param target chart.bms.ResourceMap
---@param pattern string
function BMS:processResourceLine(line, target, pattern)
	local index, value = line:match(pattern)
	target[index:upper()] = value
end

---@param line string
---@param target chart.bms.NumberResourceMap
---@param pattern string
function BMS:processNumberResourceLine(line, target, pattern)
	local index, value = line:match(pattern)
	target[index:upper()] = tonumber(value)
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

---@param measure integer
---@param message string
function BMS:processSignature(measure, message)
	local beatSignature = parseMeterSignature(message)
	if beatSignature then
		self.signature[measure] = beatSignature
	end
end

---@param measure integer
---@param channel string
---@param message string
function BMS:updateTempoFlags(measure, channel, message)
	local channelInfo = enums.ChannelEnum[channel]
	if
		(channelInfo.name == "Tempo" or channelInfo.name == "ExtendedTempo") and
		measure == 0 and
		message:sub(1, 2) ~= "00"
	then
		self.tempoAtStart = true
		self.hasTempo = true
	end
end

---@param measureTime chart.Fraction
---@return chart.bms.TimeData
function BMS:getTimeData(measureTime)
	local measureTimeString = tostring(measureTime)
	local timeData = self.timePoints[measureTimeString]
	if timeData then
		return timeData
	end

	---@type chart.bms.TimeData
	timeData = {
		measureTime = measureTime,
	}
	self.timePoints[measureTimeString] = timeData
	self.timePointCount = self.timePointCount + 1

	return timeData
end

---@param timeData chart.bms.TimeData
---@param channel string
---@return string?
function BMS:getSetNoteChannel(timeData, channel)
	local channelInfo = enums.ChannelEnum[channel]
	for currentChannel in pairs(timeData) do
		local currentChannelInfo = enums.ChannelEnum[currentChannel]
		if
			currentChannelInfo and
			currentChannelInfo.name == "Note" and
			channelInfo.inputType == currentChannelInfo.inputType and
			channelInfo.inputIndex == currentChannelInfo.inputIndex
		then
			return currentChannel -- may differ from channel due to different channels for long notes
		end
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

	local channelInfo = enums.ChannelEnum[channel]
	if not channelInfo then
		return
	end

	self:updateMode(channel)

	if channelInfo.name == "Signature" then
		self:processSignature(measure, message)
		return
	end

	self:updateTempoFlags(measure, channel, message)

	local compound = channelInfo.name ~= "BGM"
	local messageLength = math.floor(#message / 2)
	for i = 1, messageLength do
		local value = message:sub(2 * i - 1, 2 * i)
		if value ~= "00" then
			local measureTime = Fraction(i - 1, messageLength) + measure
			local timeData = self:getTimeData(measureTime)

			local setNoteChannel = self:getSetNoteChannel(timeData, channel)

			timeData[channel] = timeData[channel] or {}
			if compound then
				if channelInfo.name == "Note" then
					if channelInfo.long then
						if setNoteChannel then
							timeData[setNoteChannel][1] = nil
							timeData[setNoteChannel] = nil
						end
						timeData[channel] = timeData[channel] or {}
						timeData[channel][1] = value
					end
					if not channelInfo.long and not setNoteChannel then
						timeData[channel][1] = value
					end
				else
					timeData[channel][1] = value
					if channelInfo.name == "Tempo" or
						channelInfo.name == "ExtendedTempo"
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
