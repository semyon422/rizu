local Gamemode = require("rizu.gameplay.Gamemode")
local Preparation = require("rizu.gameplay.catch.Preparation")
local ReplayBase = require("rizu.gameplay.catch.ReplayBase")

---@class rizu.gameplay.catch.Gamemode : rizu.gameplay.Gamemode
local CatchGamemode = Gamemode + {}

CatchGamemode.name = "catch"
CatchGamemode.ReplayBase = ReplayBase
CatchGamemode.resource_paths = {"userdata/hitsounds", "resources/aim/hitsounds"}

---@param ctx sea.ComputeContext
---@param replay_base rizu.gameplay.catch.ReplayBase
function CatchGamemode:prepare(ctx, replay_base)
	Preparation.compute(ctx, replay_base)
end

---@return rizu.catch.Input
function CatchGamemode:createInput()
	return require("rizu.gameplay.catch.Input")()
end

---@return rizu.gameplay.catch.Engine
function CatchGamemode:createEngine()
	return require("rizu.gameplay.catch.Engine")()
end

return CatchGamemode
