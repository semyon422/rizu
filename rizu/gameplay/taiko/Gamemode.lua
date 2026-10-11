local Gamemode = require("rizu.gameplay.Gamemode")
local Preparation = require("rizu.gameplay.taiko.Preparation")
local ReplayBase = require("rizu.gameplay.taiko.ReplayBase")

---@class rizu.gameplay.taiko.Gamemode : rizu.gameplay.Gamemode
local TaikoGamemode = Gamemode + {}

TaikoGamemode.name = "taiko"
TaikoGamemode.ReplayBase = ReplayBase
TaikoGamemode.resource_paths = {"userdata/hitsounds", "resources/aim/hitsounds"}

---@param ctx sea.ComputeContext
---@param replay_base rizu.gameplay.taiko.ReplayBase
function TaikoGamemode:prepare(ctx, replay_base)
	Preparation.compute(ctx, replay_base)
end

---@return rizu.taiko.Input
function TaikoGamemode:createInput()
	return require("rizu.gameplay.taiko.Input")()
end

---@return rizu.gameplay.taiko.Engine
function TaikoGamemode:createEngine()
	return require("rizu.gameplay.taiko.Engine")()
end

return TaikoGamemode
