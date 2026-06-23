local IChartDecoder = require("chart.format.notechart.IChartDecoder")
local Chart = require("chart.model.Chart")
local Bms = require("chart.format.bms.BMS")
local Note = require("chart.format.notechart.Note")
local Signature = require("chart.model.to.Signature")
local Tempo = require("chart.model.to.Tempo")
local Stop = require("chart.model.to.Stop")
local MeasureLayer = require("chart.model.layers.MeasureLayer")
local VisualColumns = require("chart.model.visual.VisualColumns")
local Fraction = require("chart.core.Fraction")
local EncodingConverter = require("chart.format.notechart.EncodingConverter")
local enums = require("chart.format.bms.enums")
local dpairs = require("dpairs")
local Visual = require("chart.model.visual.Visual")
local Chartmeta = require("sea.chart.Chartmeta")
local Timings = require("sea.chart.Timings")
local Healths = require("sea.chart.Healths")

local bracketMatch = "%s(.+)%s$"
local brackets = {
	{"%[", "%]"},
	{"%(", "%)"},
	{"%-", "%-"},
	{"\"", "\""},
	{"〔", "〕"},
	{"‾", "‾"},
	{"~", "~"}
}

---@param name string
---@return string
---@return number
local function trimName(name)
	for i = 1, #brackets do
		local lb, rb = brackets[i][1], brackets[i][2]
		local start, _, _name = name:find(bracketMatch:format(lb, rb))
		if start then
			return _name, start
		end
	end
	return name, #name + 1
end

---@param title string
---@return string
---@return string
local function splitTitle(title)
	local name, bracketStart = trimName(title)
	return title:sub(1, bracketStart - 1), name
end

---@class chart.bms.ChartDecoder: chart.IChartDecoder
---@operator call: chart.bms.ChartDecoder
---@field bms chart.bms.BMS
---@field chart chart.Chart
---@field layer chart.MeasureLayer
---@field visual chart.Visual
---@field visualColumns chart.VisualColumns
---@field visualBga chart.Visual
---@field visualBgaColumns chart.VisualColumns
---@field ChannelEnum {[string]: chart.bms.ChannelInfo}
---@field minPoint chart.Point?
---@field maxPoint chart.Point?
---@field totalLength number
---@field minTime number
---@field maxTime number
local ChartDecoder = IChartDecoder + {}

local encodings = {
	"SHIFT-JIS",
	"ISO-8859-1",
	"CP932",
	"EUC-KR",
	"US-ASCII",
	"CP1252",
}

function ChartDecoder:new()
	self.conv = EncodingConverter(encodings)
end

---@param s string
---@param hash string?
---@return {chart: chart.Chart, chartmeta: sea.Chartmeta}[]
function ChartDecoder:decode(s, hash)
	self.hash = hash
	local bms = Bms()
	local content = s:gsub("\r[\r\n]?", "\n")
	content = self.conv:convert(content)
	bms:import(content)
	local chart, chartmeta = self:decodeBms(bms)
	return {{
		chart = chart,
		chartmeta = chartmeta,
	}}
end

---@param bms chart.bms.BMS
---@return chart.Chart
---@return sea.Chartmeta
function ChartDecoder:decodeBms(bms)
	self.bms = bms

	local chart = Chart()
	self.chart = chart

	local layer = MeasureLayer()
	chart.layers.main = layer
	self.layer = layer

	local visual = Visual()
	layer.visuals.main = visual
	self.visual = visual
	self.visualColumns = VisualColumns(visual)

	local visualBga = Visual()
	visualBga.bga = true
	layer.visuals.bga = visualBga
	self.visualBga = visualBga
	self.visualBgaColumns = VisualColumns(visualBga, false)

	self:setInputMode()
	self:addFirstTempo()
	self:processData()
	self:processMeasureLines()

	chart:compute()

	self:updateLength()
	local chartmeta = self:getChartmeta()

	return chart, chartmeta
end

function ChartDecoder:updateLength()
	if self.maxPoint and self.minPoint then
		self.totalLength = self.maxPoint.absoluteTime - self.minPoint.absoluteTime
		self.minTime = self.minPoint.absoluteTime
		self.maxTime = self.maxPoint.absoluteTime
	else
		self.totalLength = 0
		self.minTime = 0
		self.maxTime = 0
	end
end

---@return sea.Chartmeta
function ChartDecoder:getChartmeta()
	local bms = self.bms
	local header = bms.header
	local title, name = splitTitle(header["TITLE"])

	local chartmeta = {
		hash = self.hash,
		index = 1,
		format = "bms",
		title = title,
		artist = header["ARTIST"],
		name = name,
		level = tonumber(header["PLAYLEVEL"]),
		background_path = header["STAGEFILE"],
		tempo = bms.baseTempo or 0,
		inputmode = tostring(self.chart.inputMode),
		timings = Timings("bmsrank", tonumber(header["RANK"]) or 2),
	}
	setmetatable(chartmeta, Chartmeta)
	---@cast chartmeta sea.Chartmeta

	assert(chartmeta:validate())

	return chartmeta
end

function ChartDecoder:setInputMode()
	local mode = self.bms.mode
	local inputMode = self.chart.inputMode
	inputMode.key = mode

	self.ChannelEnum = enums.ChannelEnum
	if mode == 5 then
		inputMode.scratch = 1
		self.ChannelEnum = enums.ChannelEnum5Keys
	elseif mode == 7 then
		inputMode.scratch = 1
	elseif mode == 10 then
		inputMode.scratch = 2
		self.ChannelEnum = enums.ChannelEnum5Keys
	elseif mode == 14 then
		inputMode.scratch = 2
	elseif mode == 59 then
		inputMode.key = mode - 50
		self.ChannelEnum = enums.ChannelEnum9Keys
	elseif mode == 55 then
		inputMode.key = mode - 50
		self.ChannelEnum = enums.ChannelEnumPMS5Keys
	elseif mode == 25 or mode == 27 then
		inputMode.key = mode - 20
		inputMode.scratch = 1
		inputMode.pedal = 1
		self.ChannelEnum = enums.ChannelEnumDsc
	end
end

function ChartDecoder:addFirstTempo()
	if not self.bms.tempoAtStart and self.bms.baseTempo then
		local point = self.layer:getPoint(Fraction(0))
		point._tempo = Tempo(self.bms.baseTempo)
		self.visual:getPoint(point)
		self.visualBga:getPoint(point)
	end
end

---@param timeData chart.bms.TimeData
function ChartDecoder:setTempo(timeData)
	if not timeData[enums.BackChannelEnum["Tempo"]] then
		return
	end
	local tempo = tonumber(timeData[enums.BackChannelEnum["Tempo"]][1], 16)
	local point = self.layer:getPoint(timeData.measureTime)
	point._tempo = Tempo(math.abs(tempo))
	self.visual:getPoint(point)
	self.visualBga:getPoint(point)
end

---@param timeData chart.bms.TimeData
---@return boolean?
function ChartDecoder:setExtendedTempo(timeData)
	if not timeData[enums.BackChannelEnum["ExtendedTempo"]] then
		return
	end
	local value = timeData[enums.BackChannelEnum["ExtendedTempo"]][1]
	local tempo = self.bms.bpm[value]
	if not tempo then
		return
	end

	local point = self.layer:getPoint(timeData.measureTime)
	point._tempo = Tempo(math.abs(tempo))
	self.visual:getPoint(point)
	self.visualBga:getPoint(point)

	return true
end

---@param timeData chart.bms.TimeData
function ChartDecoder:setStop(timeData)
	if not timeData[enums.BackChannelEnum["Stop"]] then
		return
	end
	local value = timeData[enums.BackChannelEnum["Stop"]][1]
	local duration = self.bms.stop[value]
	if not duration or duration <= 0 then
		return
	end


	-- beatDuration = STOP * 4 / 192
	local point = self.layer:getPoint(timeData.measureTime)
	point._stop = Stop(Fraction(duration * 4, 16, false) / 192)
	self.visual:getPoint(point)
	self.visualBga:getPoint(point)

	point = self.layer:getPoint(timeData.measureTime, true)
	self.visual:getPoint(point)
	self.visualBga:getPoint(point)
end

function ChartDecoder:processData()
	local visualColumns = self.visualColumns
	---@type {[string]: notechart.Note}
	local longNoteData = {}

	self.minPoint = nil
	self.maxPoint = nil

	local layer = self.layer
	local chart = self.chart

	for measureIndex, value in pairs(self.bms.signature) do
		local point = layer:getPoint(Fraction(measureIndex))
		point._signature = Signature(Fraction(value * 4, 1000, "closest"))
		self.visual:getPoint(point)
		self.visualBga:getPoint(point)
		local next_point = layer:getPoint(Fraction(measureIndex + 1))
		if not next_point._signature then
			next_point._signature = Signature()
		end
		self.visual:getPoint(next_point)
		self.visualBga:getPoint(next_point)
	end

	for _, timeData in ipairs(self.bms.timeList) do
		if not self:setExtendedTempo(timeData) then
			self:setTempo(timeData)
		end
		self:setStop(timeData)

		local point = layer:getPoint(timeData.measureTime)

		for channelIndex, indexDataValues in dpairs(timeData) do
			local channelInfo = self.ChannelEnum[channelIndex] or enums.ChannelEnum[channelIndex]

			if channelInfo and (
				channelInfo.name == "Note" and channelInfo.invisible ~= true or
				channelInfo.name == "BGM" or
				channelInfo.name == "BGA"
			)
			then
				for _, value in ipairs(indexDataValues) do
					local column = channelInfo.inputType .. channelInfo.inputIndex
					local _visualColumns = channelInfo.name == "BGA" and self.visualBgaColumns or visualColumns
					local visualPoint = _visualColumns:getPoint(point, column)
					local note = Note(visualPoint, column)

					note.data.sounds = {}
					note.data.images = {}
					if channelInfo.name == "Note" or channelInfo.name == "BGM" then
						local sound = self.bms.wav[value]
						if sound and not channelInfo.mine then
							note.data.sounds[1] = {sound, 1}
							self.chart.resources:add("sound", sound)
						end
					elseif channelInfo.name == "BGA" then
						local image = self.bms.bmp[value]
						if image then
							note.data.images[1] = {image, 1}
							self.chart.resources:add("image", image)
						end
					end

					if channelInfo.name == "BGA" then
						note.type = "sprite"
					elseif channelInfo.inputType == "auto" then
						note.type = "sample"
					elseif channelInfo.mine then
						note.type = "mine"
					elseif channelInfo.long then
						if not longNoteData[channelIndex] then
							note.type = "hold"
							note.weight = 1
							longNoteData[channelIndex] = note
						else
							note.type = "hold"
							note.weight = -1
							note.data.sounds = {}
							longNoteData[channelIndex] = nil
						end
					else
						if longNoteData[channelIndex] and value == self.bms.lnobj then
							longNoteData[channelIndex].type = "hold"
							longNoteData[channelIndex].weight = 1
							note.type = "hold"
							note.weight = -1
							note.data.sounds = {}
							longNoteData[channelIndex] = nil
						else
							note.type = "tap"
							note.weight = 0
							longNoteData[channelIndex] = note
						end
					end
					chart.notes:insert(note)

					if
						channelInfo.inputType ~= "auto" and
						not channelInfo.mine and
						channelInfo.name ~= "BGA"
					then
						if not self.minPoint or point < self.minPoint then
							self.minPoint = point
						end

						if not self.maxPoint or point > self.maxPoint then
							self.maxPoint = point
						end
					end
				end
			end
		end
	end
	for _, note in pairs(longNoteData) do
		note.type = "tap"
		note.weight = 0
	end
end

function ChartDecoder:processMeasureLines()
	local layer = self.layer
	local chart = self.chart
	for measureIndex = 0, self.bms.measureCount do
		local point = layer:getPoint(Fraction(measureIndex))
		local note = Note(self.visual:getPoint(point), "measure1", "shade")
		chart.notes:insert(note)
	end
end

return ChartDecoder
