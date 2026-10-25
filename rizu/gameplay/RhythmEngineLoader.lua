local class = require("class")
local Settings = require("rizu.config.Settings")
local Gamemodes = require("rizu.gameplay.Gamemodes")

---@class rizu.RhythmEngineLoader
---@operator call: rizu.RhythmEngineLoader
local RhythmEngineLoader = class()

---@param replayBase rizu.gameplay.ReplayBase|sea.ReplayBase Of the chart's gamemode.
---@param computeContext sea.ComputeContext
---@param settings rizu.config.Config
---@param resources {[string]: string}
---@param resource_paths {[string|integer]: string}?
function RhythmEngineLoader:new(replayBase, computeContext, settings, resources, resource_paths)
	self.replayBase = replayBase
	self.computeContext = computeContext
	self.settings = settings
	self.resources = resources
	self.resource_paths = resource_paths
end

---@param enabled boolean
function RhythmEngineLoader:setAudioEnabled(enabled)
	self.audioEnabled = enabled
end

---@param rhythm_engine rizu.RhythmEngine
function RhythmEngineLoader:load(rhythm_engine)
	local computeContext = self.computeContext
	local replayBase = self.replayBase
	local settings = self.settings
	local keys = Settings.keys

	local chart = assert(computeContext.chart)
	local chartmeta = assert(computeContext.chartmeta)
	local chartdiff = assert(computeContext.chartdiff)

	rhythm_engine:setChart(chart, chartmeta, chartdiff)
	rhythm_engine:setAutoKeySound(settings:getBoolean(keys.gameplay.auto_key_sound))
	rhythm_engine:setAudioEnabled(self.audioEnabled)
	rhythm_engine:load()
	rhythm_engine:setAudioMode({
		primary = settings:getChoice(keys.audio.mode_primary),
		secondary = settings:getChoice(keys.audio.mode_secondary),
	})
	rhythm_engine:loadAudio(self.resources)
	if settings:getBoolean(keys.gameplay.bga) then
		rhythm_engine:loadVisuals(self.resources, self.resource_paths)
	end

	rhythm_engine:setRate(replayBase.rate)
	Gamemodes[chartmeta.mode]:configureEngine(rhythm_engine, replayBase, settings)

	rhythm_engine:setPlayTime(chartdiff.start_time, chartdiff.duration + rhythm_engine:getPlayPadding())
	rhythm_engine:setTimeToPrepare(settings:getNumber(keys.gameplay.time_prepare))
	rhythm_engine:setAdjustFactor(settings:getNumber(keys.audio.adjust_rate))

	rhythm_engine:setVisualRate(
		settings:getNumber(keys.gameplay.speed),
		settings:getBoolean(keys.gameplay.scale_speed)
	)
end

return RhythmEngineLoader
