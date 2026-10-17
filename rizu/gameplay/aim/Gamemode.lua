local Gamemode = require("rizu.gameplay.Gamemode")
local Preparation = require("rizu.gameplay.aim.Preparation")
local ReplayBase = require("rizu.gameplay.aim.ReplayBase")

---@class rizu.gameplay.aim.Gamemode : rizu.gameplay.Gamemode
local AimGamemode = Gamemode + {}

AimGamemode.name = "osu"
AimGamemode.ReplayBase = ReplayBase
AimGamemode.resource_paths = {"userdata/hitsounds", "resources/aim/hitsounds"}
AimGamemode.uses_pointer = true

---@param ctx sea.ComputeContext
---@param replay_base rizu.gameplay.aim.ReplayBase
function AimGamemode:prepare(ctx, replay_base)
	Preparation.compute(ctx, replay_base)
end

---@return rizu.aim.Input
function AimGamemode:createInput()
	return require("rizu.gameplay.aim.Input")()
end

---@param replay_base rizu.gameplay.aim.ReplayBase?
---@return rizu.gameplay.aim.Engine
function AimGamemode:createEngine(replay_base)
	local engine = require("rizu.gameplay.aim.Engine")()
	-- Replays recorded before stacking or tracking existed are played without them.
	engine.stacking = not replay_base or replay_base:hasStacking()
	engine.tracking = not replay_base or replay_base:hasTracking()
	return engine
end

return AimGamemode
