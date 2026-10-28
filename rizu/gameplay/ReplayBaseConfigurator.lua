local class = require("class")
local table_util = require("table_util")
local ReplayBase = require("sea.replays.ReplayBase")
local ColumnsOrder = require("sea.chart.ColumnsOrder")
local Timings = require("sea.chart.Timings")
local Subtimings = require("sea.chart.Subtimings")
local Healths = require("sea.chart.Healths")
local Settings = require("rizu.config.Settings")
local Scoring = require("rizu.engine.scoring.Scoring")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")

---What the player set up for their next plays. Each play asks createReplayBase() for a replay base of its own,
---so what a play works out, such as the chart's timings or shuffled columns, never comes back here.
---Of the scoring only the hit windows must stay as played for a replay to hit the same notes. The gauge is
---picked apart from them, and the accuracy source is not stored at all: the hits are scored again with it.
---@class rizu.gameplay.ReplayBaseConfigurator : sea.IReplayBaseConfigurator
---@operator call: rizu.gameplay.ReplayBaseConfigurator
---@field modifiers sea.Modifier[]
---@field rate number
---@field rate_type sea.RateType
---@field const boolean
---@field tap_only boolean
---@field custom boolean
---@field columns_order integer[]? nil - unchanged
local ReplayBaseConfigurator = class()

---The fields of a sea.ReplayBase kept here. Timings, gauge and accuracy are in the settings.
local fields = {"modifiers", "rate", "rate_type", "const", "tap_only", "custom", "columns_order"}

---@param settings rizu.config.Config
function ReplayBaseConfigurator:new(settings)
	self.settings = settings
	self:importReplayBase(ReplayBase())
end

---Takes the setup of another replay base, such as a multiplayer room's or the stored play config.
---@param base sea.ReplayBase|sphere.PlayConfig
function ReplayBaseConfigurator:importReplayBase(base)
	for _, k in ipairs(fields) do
		self[k] = table_util.deepcopy(base[k]) ---@diagnostic disable-line
	end
end

---@param base sea.ReplayBase|sphere.PlayConfig
function ReplayBaseConfigurator:exportReplayBase(base)
	for _, k in ipairs(fields) do
		base[k] = table_util.deepcopy(self[k]) ---@diagnostic disable-line
	end
end

---A replay base for a new play, with the default timings until applyChart().
---@param input_mode chart.InputMode|string? The chart's, to shuffle its columns when random columns is on.
---@return sea.ReplayBase
function ReplayBaseConfigurator:createReplayBase(input_mode)
	local base = ReplayBase()
	self:exportReplayBase(base)
	if input_mode and self.settings:getBoolean(Settings.keys.replay_base.random_columns) then
		base.columns_order = ColumnsOrder(input_mode):random():export()
	end
	return base
end

---Sets how a mania play of this chart is judged: the picked timings or the chart's own, and the picked gauge.
---@param base sea.ReplayBase
---@param chartmeta sea.Chartmeta
function ReplayBaseConfigurator:applyChart(base, chartmeta)
	local picked = ReplayBaseConfigurator.getPickedTimings(self.settings)
	local scoring = picked or Scoring(TimingSystems.getAuto(chartmeta.timings, chartmeta.format))
	-- Timings of the chart itself are not repeated in the replay.
	base.timings = (picked or not chartmeta.timings) and scoring.timings or nil
	base.subtimings = scoring.subtimings
	base.healths = ReplayBaseConfigurator.getPickedHealths(self.settings)
	base.timing_values = assert(scoring:getTimingValues())
	base.nearest = scoring:isNearest()
end

---@param settings rizu.config.Config
---@param k {system: string, osuod: string, etternaj: string, bmsrank: string, osu_score_version: string}
---@return rizu.engine.scoring.Scoring
local function getScoring(settings, k)
	local name = settings:getChoice(k.system) --[[@as sea.TimingsName]]
	local value_key = k[name] ---@type string?
	local value = value_key and settings:getNumber(value_key) or nil
	local subtimings ---@type sea.Subtimings?
	if name == "osuod" then
		-- Slider arithmetic leaves values such as 7.7 just off the exact tenth Timings requires.
		value = math.floor(value * 10 + 0.5) / 10
		subtimings = Subtimings("scorev", settings:getNumber(k.osu_score_version))
	end
	return Scoring(Timings(name, value), subtimings)
end

---The hit windows picked in the play config, nil while auto timings are on.
---@param settings rizu.config.Config
---@return rizu.engine.scoring.Scoring?
function ReplayBaseConfigurator.getPickedTimings(settings)
	if not settings:getBoolean(Settings.keys.replay_base.auto_timings) then
		return getScoring(settings, Settings.keys.timings)
	end
end

---The system picked to count the accuracy, judges and score. Nil while auto accuracy is on, then the
---timings' own systems count them.
---@param settings rizu.config.Config
---@return rizu.engine.scoring.Scoring?
function ReplayBaseConfigurator.getPickedAccuracy(settings)
	if not settings:getBoolean(Settings.keys.replay_base.auto_accuracy) then
		return getScoring(settings, Settings.keys.accuracy)
	end
end

---The gauge picked in the play config, whatever the timings. Nil while auto healths are on, then the
---timings' own gauge is used with the chart's HP.
---@param settings rizu.config.Config
---@return sea.Healths?
function ReplayBaseConfigurator.getPickedHealths(settings)
	local keys = Settings.keys
	if settings:getBoolean(keys.replay_base.auto_healths) then
		return
	end
	local h = keys.healths
	local name = settings:getChoice(h.system) --[[@as sea.HealthsName]]
	if name == "simple" then
		return Healths("simple", math.floor(settings:getNumber(h.osu_hp) * 10 + 0.5))
	elseif name == "etterna" then
		return Healths("etterna", settings:getNumber(h.etterna_life))
	elseif name == "lr2" then
		return Healths("lr2", settings:getNumber(h.lr2_gauge))
	elseif name == "iidx" then
		return Healths("iidx", settings:getNumber(h.iidx_gauge))
	end
end

---What counts the accuracy of a chart's plays: the picked accuracy system, else the system that judges them.
---@param settings rizu.config.Config
---@param chart_timings sea.Timings?
---@param format sea.ChartFormat
---@return rizu.engine.scoring.Scoring
function ReplayBaseConfigurator.getAccuracyScoring(settings, chart_timings, format)
	return ReplayBaseConfigurator.getPickedAccuracy(settings)
		or ReplayBaseConfigurator.getPickedTimings(settings)
		or Scoring(TimingSystems.getAuto(chart_timings, format))
end

return ReplayBaseConfigurator
