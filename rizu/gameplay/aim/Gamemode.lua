local Gamemode = require("rizu.gameplay.Gamemode")
local Preparation = require("rizu.gameplay.aim.Preparation")

---@class rizu.gameplay.aim.Gamemode : rizu.gameplay.Gamemode
local AimGamemode = Gamemode + {}

AimGamemode.name = "osu"
AimGamemode.prepare = Preparation.compute

return AimGamemode
