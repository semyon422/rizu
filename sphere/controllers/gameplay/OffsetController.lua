local class = require("class")
local math_util = require("math_util")
local ChartmetaUserData = require("sea.chart.ChartmetaUserData")
local Settings = require("rizu.config.Settings")

---@class sphere.OffsetController
---@operator call: sphere.OffsetController
local OffsetController = class()

---@param library rizu.library.Library
---@param computeContext sea.ComputeContext
---@param settings rizu.config.Config
function OffsetController:new(library, computeContext, settings)
	self.library = library
	self.computeContext = computeContext
	self.settings = settings
	self.rhythm_engine = nil
	self.unsubscribe_settings = settings:subscribeAll(function(_, _, key)
		local keys = Settings.keys
		if key == keys.audio.mode_primary then
			self:updateAudioOffset()
			return
		end
		for _, offset_key in pairs(keys.gameplay.offset_audio_mode) do
			if key == offset_key then
				self:updateAudioOffset()
				return
			end
		end
		for _, offset_key in pairs(keys.gameplay.offset_format) do
			if key == offset_key then
				self:updateAudioOffset()
				return
			end
		end
	end)
end

function OffsetController:unload()
	self.unsubscribe_settings()
	self.rhythm_engine = nil
end

---@param rhythm_engine rizu.RhythmEngine
function OffsetController:setRhythmEngine(rhythm_engine)
	self.rhythm_engine = rhythm_engine
	self:updateAudioOffset()
end

---@return number
function OffsetController:getLocalOffset()
	local chartmeta = assert(self.computeContext.chartmeta)
	local data = self.library.chartsRepo:getUserChartmetaUserData(chartmeta.hash, chartmeta.index, 1)
	return data and data.local_offset or 0
end

---@return number
function OffsetController:getAudioOffset()
	local chartmeta = assert(self.computeContext.chartmeta)
	local settings = self.settings
	local keys = Settings.keys
	local mode = settings:getChoice(keys.audio.mode_primary)
	local mode_key = keys.gameplay.offset_audio_mode[mode]
	local format_key = keys.gameplay.offset_format[chartmeta.format]
	local universal_offset = settings:getNumber(mode_key)
	local format_offset = format_key and settings:getNumber(format_key) or 0
	return universal_offset + format_offset + self:getLocalOffset()
end

function OffsetController:updateAudioOffset()
	local chartmeta = self.computeContext.chartmeta
	local engine = self.rhythm_engine
	if not chartmeta or not engine or not engine.audio_engine then
		return
	end
	engine.audio_engine:setOffset(self:getAudioOffset())
end

---@param delta number
function OffsetController:increaseLocalOffset(delta)
	local chartmeta = assert(self.computeContext.chartmeta)
	local charts_repo = self.library.chartsRepo
	local data = charts_repo:getUserChartmetaUserData(chartmeta.hash, chartmeta.index, 1)
	if not data then
		data = ChartmetaUserData()
		data.user_id = 1
		data.hash = chartmeta.hash
		data.index = chartmeta.index
		data = charts_repo:createChartmetaUserData(data)
	end
	data.local_offset = math_util.round((data.local_offset or 0) + delta, delta)
	charts_repo:updateChartmetaUserData(data)
	self:updateAudioOffset()
end

function OffsetController:resetLocalOffset()
	local chartmeta = assert(self.computeContext.chartmeta)
	local charts_repo = self.library.chartsRepo
	local data = charts_repo:getUserChartmetaUserData(chartmeta.hash, chartmeta.index, 1)
	if data then
		data.local_offset = nil
		charts_repo:updateChartmetaUserDataFull(data)
	end
	self:updateAudioOffset()
end

return OffsetController
