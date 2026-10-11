local Gamemode = require("rizu.gameplay.Gamemode")
local Preparation = require("rizu.gameplay.taiko.Preparation")

---@class rizu.gameplay.taiko.Gamemode : rizu.gameplay.Gamemode
local TaikoGamemode = Gamemode + {}

TaikoGamemode.name = "taiko"
TaikoGamemode.prepare = Preparation.compute

return TaikoGamemode
