local Gamemode = require("rizu.gameplay.Gamemode")
local Preparation = require("rizu.gameplay.sdvx.Preparation")
local ReplayBase = require("rizu.gameplay.sdvx.ReplayBase")

---@class rizu.gameplay.sdvx.Gamemode : rizu.gameplay.Gamemode
local SdvxGamemode = Gamemode + {}

SdvxGamemode.name = "sdvx"
SdvxGamemode.ReplayBase = ReplayBase
SdvxGamemode.resource_paths = {"userdata/hitsounds", "resources/aim/hitsounds"}

---@param ctx sea.ComputeContext
---@param replay_base rizu.gameplay.sdvx.ReplayBase
function SdvxGamemode:prepare(ctx, replay_base)
	Preparation.compute(ctx, replay_base)
end

---@return rizu.sdvx.Input
function SdvxGamemode:createInput()
	return require("rizu.gameplay.sdvx.Input")()
end

---@return rizu.gameplay.sdvx.Engine
function SdvxGamemode:createEngine()
	return require("rizu.gameplay.sdvx.Engine")()
end

return SdvxGamemode
