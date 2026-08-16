local class = require("class")
local Settings = require("rizu.config.Settings")

---@class rizu.RhythmEngineLoader
---@operator call: rizu.RhythmEngineLoader
local RhythmEngineLoader = class()

---@param replayBase sea.ReplayBase
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
	rhythm_engine:loadVisuals(self.resources, self.resource_paths)

	rhythm_engine:setTimings(replayBase.timings, replayBase.subtimings)
	rhythm_engine:setTimingValues(replayBase.timing_values)
	rhythm_engine:setRate(replayBase.rate)
	rhythm_engine:setNearest(replayBase.nearest)
	rhythm_engine:setConst(replayBase.const)

	rhythm_engine:setPlayTime(chartdiff.start_time, chartdiff.duration)
	rhythm_engine:setTimeToPrepare(settings:getNumber(keys.gameplay.time_prepare))
	rhythm_engine:setAdjustFactor(settings:getNumber(keys.audio.adjust_rate))

	local format_key = keys.audio.volume_keysounds_format[chartmeta.format]
	local format_volume = format_key and settings:getNumber(format_key) or 1
	rhythm_engine:setVolume({
		master = settings:getNumber(keys.audio.volume_master),
		music = settings:getNumber(keys.audio.volume_music),
		keysounds = settings:getNumber(keys.audio.volume_keysounds) * format_volume,
	})

	rhythm_engine:setLongNoteShortening(settings:getNumber(keys.gameplay.long_note_shortening))
	rhythm_engine:setVisualRate(
		settings:getNumber(keys.gameplay.speed),
		settings:getBoolean(keys.gameplay.scale_speed)
	)
end

return RhythmEngineLoader
