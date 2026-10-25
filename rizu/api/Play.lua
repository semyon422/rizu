local thread = require("thread")
local Events = require("rizu.api.Events")
local Settings = require("rizu.config.Settings")
local TimingSystems = require("rizu.engine.scoring.TimingSystems")
local ModifierModel = require("sphere.models.ModifierModel")
local ModifierRegistry = require("sphere.models.ModifierModel.ModifierRegistry")
local ColumnsOrder = require("sea.chart.ColumnsOrder")

--[[
How the next play will go: the music speed, the mods, the mutators, how hits are judged, and starting it.

	local play = ui.api.play
	play:changeRate(1)
	label:setText(RateFormatter.format(play:getRateValue(), play:getRateType()))
	play:setToggle("constant_scroll", true)
	play:addMutator("Mirror")
	play:on("rate_changed", function() ... end)
	play:start({autoplay = false}, function(ok, err)
		if ok then showGameplay() else showError(err) end
	end)
]]

---@alias rizu.api.Play.Event
---| "rate_changed" # The music speed or the way it is counted changed. No arguments.
---| "mods_changed" # A toggle, a mutator or the judging changed. No arguments.

---@alias rizu.api.Play.Toggle
---| "constant_scroll" # Notes fall at one speed, ignoring the chart's speed changes. Counts as a mod.
---| "taps_only" # Long notes become taps. Counts as a mod.
---| "auto_timings" # Each mania chart is judged the way its own format does, and the leaderboard shows normalscore.

---How mania hits are judged when "auto_timings" is off, also the system the leaderboard rescores to.
---Three of them take a value, see setTimingValue().
---@alias rizu.api.Play.TimingSystem
---| "sphere" # Rizu's own.
---| "osuod" # osu!mania. Value: overall difficulty, 0..10 in steps of 0.1.
---| "etternaj" # Etterna. Value: judge, 1..9.
---| "quaver" # Quaver.
---| "bmsrank" # Lunatic Rave 2. Value: rank, 0 insane, 1 hard, 2 normal, 3 easy.
---| "iidx" # beatmania IIDX.

---@alias rizu.api.Play.ColumnSide "left"|"right" Half of the keys; the middle one of an odd count stays.

---@alias rizu.api.Play.ColumnOrderState
---| "original"
---| "mirror"
---| "mirror_left"
---| "mirror_right"
---| "bracketswap"
---| "shift"
---| "custom"

---A mutator that changes the chart, one entry of getMutators(). The game's own table: read it, do not change it.
---@class rizu.api.Mutator
---@field id integer Which mutator it is, for the game. getMutatorName() says.
---@field value any The setting of a mutator that has one, see hasMutatorValue(). It can be a number, a string or a boolean.

---Where a play starts and what it plays. `replay` is only for gamemodes without scoring, see hasLocalReplays().
---@class rizu.api.Play.StartOptions
---@field autoplay boolean? The game plays the chart by itself.
---@field replay boolean? Watch the kept replay of the selected chart instead of playing it.

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

---@param steps integer 1 is one step faster, -1 one step slower.
function Play:changeRate(steps)
	self.game.timeRateModel:increase(steps)
end

---@return sea.RateType[]
function Play:getRateTypes() return self.game.timeRateModel.types end

---Keeps the speed and changes how it is counted.
---@param rate_type sea.RateType
function Play:setRateType(rate_type)
	self.game.timeRateModel:setType(rate_type)
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
end

-- Mods

---@param self rizu.api.Play
local function modsChanged(self)
	self.game.modifierSelectModel:change() ---@diagnostic disable-line: invisible
	self:emit("mods_changed")
end

local toggle_fields = {constant_scroll = "const", taps_only = "tap_only"}

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
	if toggle == "auto_timings" then
		self.game.settings:setBoolean(Settings.keys.replay_base.auto_timings, on)
		return modsChanged(self)
	end
	self.game.replayBase[toggle_fields[toggle]] = on
	modsChanged(self)
end

---How many of the play options that count as mods are on (constant scroll, taps only).
---@return integer
function Play:getModCount()
	local replay_base = self.game.replayBase
	return (replay_base.const and 1 or 0) + (replay_base.tap_only and 1 or 0)
end

-- Column order. Moves the chart's columns to other keys. Only for the selected chart's key count.

---Which chart column each key plays: order[2] == 3 means the second key plays the third column.
---@return integer[] order Empty when no chart is selected.
function Play:getColumnOrder()
	local inputMode = self.game.modifierCoordinator.state.inputMode
	local order = self.game.replayBase.columns_order
	local columns = inputMode:getColumns()
	local copy = {} ---@type integer[]
	for i = 1, columns do
		copy[i] = order and order[i] or i
	end
	return copy
end

---@param order integer[]? A permutation of 1..#getColumnOrder(). nil puts every column back.
function Play:setColumnOrder(order)
	self.game.replayBase.columns_order = ColumnsOrder(self.game.modifierCoordinator.state.inputMode, order):export()
	modsChanged(self)
end

---@param side rizu.api.Play.ColumnSide? nil for every column.
function Play:mirrorColumns(side)
	local replay_base = self.game.replayBase
	replay_base.columns_order = ColumnsOrder(self.game.modifierCoordinator.state.inputMode, replay_base.columns_order)
		:mirror(side):export()
	modsChanged(self)
end

---@param side rizu.api.Play.ColumnSide? nil for every column.
function Play:randomizeColumns(side)
	local replay_base = self.game.replayBase
	replay_base.columns_order = ColumnsOrder(self.game.modifierCoordinator.state.inputMode, replay_base.columns_order)
		:random(side):export()
	modsChanged(self)
end

---What the order looks like. A shuffled order and one swapped by hand are both "custom".
---@return rizu.api.Play.ColumnOrderState state
---@return integer? shift How many keys to the right the columns moved, for "shift".
function Play:getColumnOrderState()
	local name = ColumnsOrder(self.game.modifierCoordinator.state.inputMode, self.game.replayBase.columns_order)
		:getName()
	if not name then
		return "original"
	end
	local shift = name:match("^shift (%-?%d+)$")
	if shift then
		return "shift", tonumber(shift)
	end
	return (name:gsub(" ", "_")) --[[@as rizu.api.Play.ColumnOrderState]]
end

-- Mutators. They change the chart before it is played and are applied in the order of the list.
-- New ones go in at the insertion point, a place between two mutators that the game remembers.
-- TODO: weak spot. The insertion point is the cursor of the old mutator screen, kept in
-- ModifierSelectModel. A mutator should be added with an index instead, and the model should
-- lose `modifierIndex`. A mutator is the game's own table with an opaque `id`, so names and
-- setting texts go through the functions below; the game should give it a name and a text itself.

---@return string[] names Every mutator the game has.
function Play:getAvailableMutators() return ModifierRegistry.list end

---False when a mutator that can only be used once is already in the list.
---@param name string One of getAvailableMutators().
---@return boolean
function Play:canAddMutator(name)
	local model = self.game.modifierSelectModel
	model:updateAdded()
	return not (model:isOneUse(name) and model:isAdded(name))
end

---How many mutators will change the chart.
---@return integer
function Play:getMutatorCount() return #self.game.modifierSelectModel.replayBase.modifiers end

---The same table until the list changes. Do not change it.
---@return rizu.api.Mutator[]
function Play:getMutators() return self.game.modifierSelectModel.replayBase.modifiers --[[@as rizu.api.Mutator[] ]] end

---@param mutator rizu.api.Mutator
---@return string
function Play:getMutatorName(mutator) return ModifierRegistry:getName(mutator.id) end

---True for mutators with a setting, which changeMutatorValue() steps through.
---@param mutator rizu.api.Mutator
---@return boolean
function Play:hasMutatorValue(mutator)
	local modifier = ModifierModel:getModifier(mutator.id) --[[@as table?]]
	return modifier ~= nil and modifier.values ~= nil and #modifier.values > 0
end

---The setting of a mutator the way the player reads it, such as the 3 of "full long notes 3".
---@param mutator rizu.api.Mutator
---@return string? text nil when it has no setting worth showing.
function Play:getMutatorValueText(mutator)
	local modifier = ModifierModel:getModifier(mutator.id)
	if not modifier or self:getMutatorName(mutator) == "Custom" then return end
	local _, setting = modifier:getString(mutator)
	if setting and #tostring(setting) > 0 then
		return tostring(setting)
	end
end

---Adds a mutator at the insertion point. Does nothing if canAddMutator() is false.
---@param name string One of getAvailableMutators().
function Play:addMutator(name)
	if not self:canAddMutator(name) then return end
	self.game.modifierSelectModel:add(name)
	modsChanged(self)
end

---@param index integer 1..getMutatorCount()
function Play:removeMutator(index)
	self.game.modifierSelectModel:remove(index)
	modsChanged(self)
end

---@param index integer 1..getMutatorCount()
---@param steps integer 1 is the next value of the setting, -1 the previous.
---@return boolean changed False at the ends of the list of values.
function Play:changeMutatorValue(index, steps)
	local mutator = self:getMutators()[index]
	if not mutator or not self:hasMutatorValue(mutator) then return false end
	local previous = mutator.value
	ModifierModel:increaseModifierValue(mutator, steps)
	if mutator.value == previous then return false end
	modsChanged(self)
	return true
end

---Where the next mutator goes: 1 is before the first one, getMutatorCount() + 1 after the last.
---@return integer
function Play:getMutatorPosition()
	local model = self.game.modifierSelectModel
	return math.max(1, math.min(model.modifierIndex, #model.replayBase.modifiers + 1))
end

---@param position integer Clamped to 1..getMutatorCount() + 1.
function Play:setMutatorPosition(position)
	local model = self.game.modifierSelectModel
	model.modifierIndex = math.max(1, math.min(position, #model.replayBase.modifiers + 1))
end

-- Judging. Used when "auto_timings" is off.

---@return rizu.api.Play.TimingSystem[]
function Play:getTimingSystems() return TimingSystems.selectable --[[@as rizu.api.Play.TimingSystem[] ]] end

---@return rizu.api.Play.TimingSystem
function Play:getTimingSystem()
	return self.game.settings:getChoice(Settings.keys.timings.system) --[[@as rizu.api.Play.TimingSystem]]
end

---Switches the system. It comes back with the value it was last used with.
---@param system rizu.api.Play.TimingSystem
function Play:setTimingSystem(system)
	self.game.settings:setChoice(Settings.keys.timings.system, system)
	modsChanged(self)
end

---@return number value 0 for systems that take none.
function Play:getTimingValue()
	local key = Settings.keys.timings[self:getTimingSystem()]
	return key and self.game.settings:getNumber(key) or 0
end

---@param value number See rizu.api.Play.TimingSystem for what each system takes.
function Play:setTimingValue(value)
	self.game.settings:setNumber(assert(Settings.keys.timings[self:getTimingSystem()], "the system takes no value"), value)
	modsChanged(self)
end

---osu!mania's ScoreV1 or ScoreV2 hit windows. Only used by "osuod".
---@return 1|2
function Play:getOsuScoreVersion()
	return self.game.settings:getNumber(Settings.keys.timings.osu_score_version) --[[@as 1|2]]
end

---@param version 1|2
function Play:setOsuScoreVersion(version)
	self.game.settings:setNumber(Settings.keys.timings.osu_score_version, version)
	modsChanged(self)
end

-- Starting

---True when the selected chart's gamemode has no scores and keeps its last attempt as a local replay instead.
---Then start() takes `replay = true`.
---@return boolean
function Play:hasLocalReplays()
	local chartview = self.game.chartSelector.chartview
	return chartview ~= nil and self.game.gameplayInteractor.replay_stores[chartview.chartmeta_mode] ~= nil
end

-- TODO: weak spot. Loading runs on the main thread and stalls the frame, so the UI has to show a
-- loading screen before it calls start(). The engine should load in the background.
---Loads the selected chart with the options set above. Switch to the gameplay screen when f gets true.
---Loading takes a while and the game does not draw meanwhile: show a loading screen first.
---On failure f gets false and why, or only false when there was nothing to load.
---@param options rizu.api.Play.StartOptions
---@param f fun(ok: boolean, err: string?)
function Play:start(options, f)
	local game = self.game
	local interactor = game.gameplayInteractor

	---@param err string?
	local function failed(err)
		interactor.replaying = false
		interactor.autoplay = false
		f(false, err)
	end

	interactor.replaying = false
	interactor.autoplay = options.autoplay or false
	if options.replay then
		local chartview = game.chartSelector.chartview
		if not chartview or not self:hasLocalReplays() then
			return failed("The selected chart has no local replay.")
		end
		local ok, err = interactor:loadLocalReplay(chartview.hash, chartview.index, chartview.chartmeta_mode)
		if not ok then return failed(err) end
	end
	thread.coro(function()
		local ok, loaded = pcall(game.gameInteractor.loadGameplaySelectedChartAsync, game.gameInteractor)
		if ok and loaded then
			return f(true)
		end
		failed(not ok and tostring(loaded) or nil)
	end)()
end

return Play
