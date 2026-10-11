local Gamemode = require("rizu.gameplay.Gamemode")

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

return ManiaGamemode
