local Events = require("rizu.api.Events")
local Settings = require("rizu.config.Settings")
local Subtimings = require("sea.chart.Subtimings")
local Timings = require("sea.chart.Timings")
local TimingValuesFactory = require("sea.chart.TimingValuesFactory")

--[[
How the next play will go: the music speed, the mods, how hits are judged, and starting it.

	local play = ui.api.play
	play:changeRate(1)
	label:setText(play:getRateText())
	play:setToggle("constant_scroll", true)
	play:on("rate_changed", function() ... end)
]]

---@alias rizu.api.Play.Event
---| "rate_changed" # The music speed or the way it is counted changed. No arguments.
---| "mods_changed" # A toggle or the judging changed. No arguments.

---@alias rizu.api.Play.Toggle
---| "constant_scroll" # Notes fall at one speed, ignoring the chart's speed changes. Counts as a mod.
---| "taps_only" # Long notes become taps. Counts as a mod.
---| "nearest_input" # A press hits the nearest note instead of the earliest one.
---| "auto_timings" # Each chart is judged the way its own format does. Off: one timing system for every chart.

---How hits are judged when "auto_timings" is off. Three of them take a value, see setTimingValue().
---@alias rizu.api.Play.TimingSystem
---| "sphere" # Rizu's own.
---| "osuod" # osu!mania. Value: overall difficulty, 0..10 in steps of 0.1.
---| "etternaj" # Etterna. Value: judge, 1..9.
---| "quaver" # Quaver.
---| "bmsrank" # Lunatic Rave 2. Value: rank, 0 insane, 1 hard, 2 normal, 3 easy.
---| "iidx" # beatmania IIDX.

---@class rizu.api.Play : rizu.api.Events
---@operator call: rizu.api.Play
---@field on fun(self: rizu.api.Play, event: rizu.api.Play.Event, f: function): fun()
---@field private game sphere.GameController
local Play = Events + {}

---@param game sphere.GameController
function Play:new(game)
	Events.new(self)
	self.game = game
	game.timeRateModel:onChanged(function()
		self:emit("rate_changed")
	end)
end

-- Music speed

---How many times faster than normal the music plays: 1 is normal, 1.5 is one and a half times as fast.
---@return number
function Play:getRate() return self.game.replayBase.rate end

---"linear" counts the speed in multipliers (1.05x), "exp" in steps of a tenth of an octave (+1).
---@return sea.RateType
function Play:getRateType() return self.game.replayBase.rate_type end

---The speed the way the player set it: "1.05x" or "+1".
---@return string
function Play:getRateText()
	local value = self.game.timeRateModel:get()
	if self.game.replayBase.rate_type == "exp" then
		return value > 0 and ("+%.0f"):format(value) or ("%.0f"):format(value)
	end
	return ("%.2fx"):format(value)
end

---@param steps integer 1 is one step faster, -1 one step slower.
function Play:changeRate(steps)
	self.game.timeRateModel:increase(steps)
	self.game.modifierSelectModel:change()
end

---@return sea.RateType[]
function Play:getRateTypes() return self.game.timeRateModel.types end

---Keeps the speed and changes how it is counted.
---@param rate_type sea.RateType
function Play:setRateType(rate_type)
	self.game.timeRateModel:setType(rate_type)
	self.game.modifierSelectModel:change()
end

---The speed in the units of getRateType(): 1.05 for "linear", 1 for "exp". For a slider.
---@return number value
---@return number min
---@return number max
---@return number step
function Play:getRateValue()
	local model = self.game.timeRateModel
	local range = model.range[self.game.replayBase.rate_type]
	return model:get(), range[1], range[2], range[3]
end

---@param value number In the units of getRateType(). Clamped to the range.
function Play:setRateValue(value)
	self.game.timeRateModel:set(value)
	self.game.modifierSelectModel:change()
end

-- Mods

---@param self rizu.api.Play
local function modsChanged(self)
	self.game.modifierSelectModel:change() ---@diagnostic disable-line: invisible
	self:emit("mods_changed")
end

local setTimings

local toggle_fields = {constant_scroll = "const", taps_only = "tap_only", nearest_input = "nearest"}

---@param toggle rizu.api.Play.Toggle
---@return boolean
function Play:getToggle(toggle)
	if toggle == "auto_timings" then
		return self.game.settings:getBoolean(Settings.keys.replay_base.auto_timings)
	end
	return self.game.replayBase[toggle_fields[toggle]] and true or false
end

---@param toggle rizu.api.Play.Toggle
---@param on boolean
function Play:setToggle(toggle, on)
	if toggle ~= "auto_timings" then
		self.game.replayBase[toggle_fields[toggle]] = on
		return modsChanged(self)
	end
	self.game.settings:setBoolean(Settings.keys.replay_base.auto_timings, on)
	if on then
		return modsChanged(self)
	end
	setTimings(self, self:getTimingSystem())
end

---How many of the play options that count as mods are on (constant scroll, taps only).
---@return integer
function Play:getModCount()
	local replay_base = self.game.replayBase
	return (replay_base.const and 1 or 0) + (replay_base.tap_only and 1 or 0)
end

---How many mutators will change the chart.
---@return integer
function Play:getMutatorCount() return #self.game.modifierSelectModel.replayBase.modifiers end

-- Judging. Used when "auto_timings" is off.

local timing_systems = {"sphere", "osuod", "etternaj", "quaver", "bmsrank", "iidx"}
local is_timing_system = {} ---@type {[string]: true}
for _, name in ipairs(timing_systems) do
	is_timing_system[name] = true
end

---@param self rizu.api.Play
---@param name rizu.api.Play.TimingSystem
---@param value number?
---@param score_version number?
function setTimings(self, name, value, score_version)
	local game = self.game ---@diagnostic disable-line: invisible
	local settings = game.settings
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

	game.replayBase.timings = timings
	game.replayBase.subtimings = subtimings
	game.replayBase.timing_values = assert(TimingValuesFactory:get(timings, subtimings))
	modsChanged(self)
end

---@return rizu.api.Play.TimingSystem[]
function Play:getTimingSystems() return timing_systems end

---@return rizu.api.Play.TimingSystem
function Play:getTimingSystem()
	local timings = self.game.replayBase.timings
	return timings and is_timing_system[timings.name] and timings.name --[[@as rizu.api.Play.TimingSystem]] or "sphere"
end

---Switches the system and brings back the value it was last used with.
---@param system rizu.api.Play.TimingSystem
function Play:setTimingSystem(system) setTimings(self, system) end

---@return number value 0 for systems that take none.
function Play:getTimingValue()
	local system = self:getTimingSystem()
	local timings = self.game.replayBase.timings
	if timings and timings.name == system then
		return timings.data
	end
	local key = Settings.keys.timings[system]
	return key and self.game.settings:getNumber(key) or 0
end

---@param value number See rizu.api.Play.TimingSystem for what each system takes.
function Play:setTimingValue(value)
	local subtimings = self.game.replayBase.subtimings
	setTimings(self, self:getTimingSystem(), value, subtimings and subtimings.data)
end

---osu!mania's ScoreV1 or ScoreV2 hit windows. Only used by "osuod".
---@return 1|2
function Play:getOsuScoreVersion()
	local subtimings = self.game.replayBase.subtimings
	return subtimings and subtimings.data or self.game.settings:getNumber(Settings.keys.timings.osu_score_version)
end

---@param version 1|2
function Play:setOsuScoreVersion(version)
	setTimings(self, "osuod", self:getTimingValue(), version)
end

-- Starting

---Call before switching to the screen that loads the selected chart.
---@param autoplay boolean The game plays the chart by itself.
function Play:prepare(autoplay)
	local interactor = self.game.gameplayInteractor
	interactor.replaying = false
	interactor.autoplay = autoplay
end

return Play
