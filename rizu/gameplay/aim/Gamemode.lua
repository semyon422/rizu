local Gamemode = require("rizu.gameplay.Gamemode")
local Preparation = require("rizu.gameplay.aim.Preparation")

---@class rizu.gameplay.aim.Gamemode : rizu.gameplay.Gamemode
local AimGamemode = Gamemode + {}

AimGamemode.name = "osu"
AimGamemode.uses_pointer = true
AimGamemode.prepare = Preparation.compute

---@return rizu.aim.Input
function AimGamemode.createInput()
	return require("rizu.gameplay.aim.Input")()
end

---@return rizu.gameplay.aim.Engine
function AimGamemode.createEngine()
	return require("rizu.gameplay.aim.Engine")()
end

return AimGamemode
