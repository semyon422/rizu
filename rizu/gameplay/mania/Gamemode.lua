local Gamemode = require("rizu.gameplay.Gamemode")
local Settings = require("rizu.config.Settings")
local ReplayBase = require("sea.replays.ReplayBase")

---@class rizu.gameplay.mania.Gamemode : rizu.gameplay.Gamemode
local ManiaGamemode = Gamemode + {}

ManiaGamemode.name = "mania"
ManiaGamemode.ReplayBase = ReplayBase
ManiaGamemode.saves_scores = true
ManiaGamemode.deferred_input = false
ManiaGamemode.resource_paths = {"userdata/hitsounds", "userdata/hitsounds/midi"}

---@param source sea.ReplayBase
---@return sea.ReplayBase
function ManiaGamemode:createReplayBase(source)
	local base = ReplayBase()
	base:importReplayBase(source)
	return base
end

---@param ctx sea.ComputeContext
---@param replay_base sea.ReplayBase
---@param config rizu.GameplayChartConfig
function ManiaGamemode:prepare(ctx, replay_base, config)
	ctx:applyModifierReorder(replay_base)
	ctx:computeBase(replay_base)
	ctx:applyTempo(config.tempoFactor, config.primaryTempo)
	if config.autoKeySound then
		ctx:applyAutoKeysound()
	end
	if config.swapVelocityType then
		ctx:swapVelocityType()
	end
end

---@param input_config table
---@param input_mode string
---@return rizu.gameplay.mania.Input
function ManiaGamemode:createInput(input_config, input_mode)
	return require("rizu.gameplay.mania.Input")(input_config, input_mode)
end

---@return rizu.gameplay.mania.Engine
function ManiaGamemode:createEngine()
	return require("rizu.gameplay.mania.Engine")()
end

---@param engine rizu.gameplay.mania.Engine
---@param replay_base sea.ReplayBase
---@param settings rizu.config.Config
function ManiaGamemode:configureEngine(engine, replay_base, settings)
	-- The accuracy source is the player's, not the replay's: watched replays are counted with it too.
	local accuracy = require("rizu.gameplay.ReplayBaseConfigurator").getPickedAccuracy(settings)
	engine:setTimings(replay_base.timings, replay_base.subtimings, replay_base.healths, accuracy)
	engine:setTimingValues(replay_base.timing_values)
	engine:setNearest(replay_base.nearest)
	engine:setConst(replay_base.const)
	engine:setLongNoteShortening(settings:getNumber(Settings.keys.gameplay.long_note_shortening))
end

return ManiaGamemode
