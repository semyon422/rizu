local class = require("class")
local Settings = require("rizu.config.Settings")
local Subtimings = require("sea.chart.Subtimings")
local Timings = require("sea.chart.Timings")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")

---How hits are judged when `auto_timings` is off. Remembers the last value of every timing system in the settings.
---@class sphere.TimingsModel
---@operator call: sphere.TimingsModel
---@field replayBase sea.ReplayBase
---@field settings rizu.config.Config
---@field modifierSelectModel sphere.ModifierSelectModel
local TimingsModel = class()

---@param replayBase sea.ReplayBase
---@param settings rizu.config.Config
---@param modifierSelectModel sphere.ModifierSelectModel
function TimingsModel:new(replayBase, settings, modifierSelectModel)
	self.replayBase = replayBase
	self.settings = settings
	self.modifierSelectModel = modifierSelectModel
end

---@param name string A timing system.
---@param value number? Defaults to the value it was last used with.
---@param score_version number? osu!mania only. Defaults to the last one used.
function TimingsModel:set(name, value, score_version)
	local settings = self.settings
	local timing_key = Settings.keys.timings[name]
	value = value or (timing_key and settings:getNumber(timing_key)) or 0
	if name == "osuod" then
		-- Slider arithmetic can leave values such as 9.7 just below the exact
		-- tenth required by Timings validation.
		value = math.floor(value * 10 + 0.5) / 10
	end
	local timings = Timings(name, value)
	local subtimings ---@type sea.Subtimings?

	if timing_key then
		settings:setNumber(timing_key, value)
	end
	if name == "osuod" then
		score_version = score_version or settings:getNumber(Settings.keys.timings.osu_score_version)
		settings:setNumber(Settings.keys.timings.osu_score_version, score_version)
		subtimings = Subtimings("scorev", score_version)
	end

	self.replayBase.timings = timings
	self.replayBase.subtimings = subtimings
	self.replayBase.timing_values = assert(TimingValuesFactory:get(timings, subtimings))
	self.modifierSelectModel:change()
end

return TimingsModel
