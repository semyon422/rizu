local Gamemode = require("rizu.gameplay.Gamemode")
local Settings = require("rizu.config.Settings")

---@class rizu.gameplay.mania.Gamemode : rizu.gameplay.Gamemode
local ManiaGamemode = Gamemode + {}

ManiaGamemode.name = "mania"

---@param ctx sea.ComputeContext
---@param replay_base sea.ReplayBase
---@param config rizu.GameplayChartConfig
function ManiaGamemode.prepare(ctx, replay_base, config)
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

---@return rizu.gameplay.mania.Engine
function ManiaGamemode.createEngine()
	return require("rizu.gameplay.mania.Engine")()
end

---@param engine rizu.gameplay.mania.Engine
---@param replay_base sea.ReplayBase
---@param settings rizu.config.Config
function ManiaGamemode.configureEngine(engine, replay_base, settings)
	engine:setTimings(replay_base.timings, replay_base.subtimings)
	engine:setTimingValues(replay_base.timing_values)
	engine:setNearest(replay_base.nearest)
	engine:setConst(replay_base.const)
	engine:setLongNoteShortening(settings:getNumber(Settings.keys.gameplay.long_note_shortening))
end

return ManiaGamemode
